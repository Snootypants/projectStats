import Foundation
import SwiftData

@MainActor
class ClaudeUsageService: ObservableObject {
    static let shared = ClaudeUsageService()

    // Global stats
    @Published var globalTodayStats: DailyUsageStats?
    @Published var globalWeekStats: [DailyUsageStats] = []

    // Per-project stats (keyed by project path)
    @Published var projectStats: [String: ProjectUsageStats] = [:]

    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var lastGlobalRefresh: Date?
    private var lastProjectRefresh: [String: Date] = [:]

    private let globalRefreshInterval: TimeInterval = 600   // 10 minutes
    private let projectRefreshInterval: TimeInterval = 600  // 10 minutes

    struct DailyUsageStats: Codable, Identifiable {
        var id: String { date }
        let date: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationTokens: Int?
        let cacheReadTokens: Int?
        let totalTokens: Int
        let totalCost: Double
        let models: [String]?

        enum CodingKeys: String, CodingKey {
            case date
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationTokens = "cache_creation_tokens"
            case cacheReadTokens = "cache_read_tokens"
            case totalTokens = "total_tokens"
            case totalCost = "total_cost"
            case models
        }
    }

    struct ProjectUsageStats {
        var todayStats: DailyUsageStats?
        var weekStats: [DailyUsageStats] = []
        var lastRefresh: Date?
    }

    // MARK: - Global Stats

    func refreshGlobalIfNeeded() async {
        if let last = lastGlobalRefresh, Date().timeIntervalSince(last) < globalRefreshInterval {
            return
        }
        await refreshGlobal()
    }

    func refreshGlobal() async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        do {
            let sinceDate = sevenDaysAgoString()
            let output = try await runCCUsage(args: ["daily", "--json", "--since", sinceDate])

            if let data = output.data(using: .utf8) {
                let stats = try JSONDecoder().decode([DailyUsageStats].self, from: data)
                self.globalWeekStats = stats.sorted { $0.date > $1.date }
                self.globalTodayStats = stats.first { $0.date == todayDateString() }

                await saveSnapshot(projectPath: nil, jsonData: output, stats: stats)
            }

            lastGlobalRefresh = Date()
        } catch {
            // Set friendly error message
            lastError = "Unable to load usage data"
            print("[ClaudeUsage] Global error: \(error)")
        }

        isLoading = false  // ALWAYS set to false, even on error
    }

    // MARK: - Per-Project Stats

    func refreshProjectIfNeeded(_ projectPath: String) async {
        if let last = lastProjectRefresh[projectPath], Date().timeIntervalSince(last) < projectRefreshInterval {
            return
        }
        await refreshProject(projectPath)
    }

    func refreshProject(_ projectPath: String) async {
        let projectName = ccusageProjectName(from: projectPath)

        do {
            let sinceDate = sevenDaysAgoString()
            let output = try await runCCUsage(args: ["daily", "--json", "--since", sinceDate, "--project", projectName])

            if let data = output.data(using: .utf8) {
                let stats = try JSONDecoder().decode([DailyUsageStats].self, from: data)

                var projectUsage = ProjectUsageStats()
                projectUsage.weekStats = stats.sorted { $0.date > $1.date }
                projectUsage.todayStats = stats.first { $0.date == todayDateString() }
                projectUsage.lastRefresh = Date()

                self.projectStats[projectPath] = projectUsage
                self.lastProjectRefresh[projectPath] = Date()

                await saveSnapshot(projectPath: projectPath, jsonData: output, stats: stats)
            }
        } catch {
            print("[ClaudeUsage] Project error for \(projectName): \(error)")
        }
    }

    // MARK: - Tab Switch Handler

    func onTabSwitch(projectPath: String?) async {
        // Always try to refresh global
        await refreshGlobalIfNeeded()

        // If switching to a project, refresh its stats too
        if let path = projectPath {
            await refreshProjectIfNeeded(path)
        }
    }

    // MARK: - Claude Finished Handler

    func onClaudeFinished(projectPath: String?) async {
        // Wait for JSONL to be written
        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Force refresh both
        await refreshGlobal()
        if let path = projectPath {
            await refreshProject(path)
        }
    }

    // MARK: - Helpers

    private func ccusageProjectName(from projectPath: String) -> String {
        // Convert "/Users/caleb/Code/projectStats" to "-Users-caleb-Code-projectStats"
        // This matches how ccusage names project folders
        return projectPath.replacingOccurrences(of: "/", with: "-")
    }

    private func runCCUsage(args: [String]) async throws -> String {
        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.executeProcess(args: args)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000)  // 10 second timeout
                throw NSError(domain: "ClaudeUsage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for ccusage"])
            }

            // Return first result (success or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private nonisolated func executeProcess(args: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["npx", "ccusage@latest"] + args
                process.standardOutput = pipe
                process.standardError = errorPipe

                // Set PATH to include common Node locations
                var env = ProcessInfo.processInfo.environment
                let home = env["HOME"] ?? NSHomeDirectory()
                let nodePaths = [
                    "/usr/local/bin",
                    "/opt/homebrew/bin",
                    "\(home)/.nvm/versions/node",
                    "\(home)/.volta/bin",
                    "\(home)/.fnm/aliases/default/bin",
                    "\(home)/.local/bin"
                ]
                env["PATH"] = (env["PATH"] ?? "") + ":" + nodePaths.joined(separator: ":")
                process.environment = env

                do {
                    try process.run()
                    process.waitUntilExit()  // Safe - we're on background thread

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                        // Filter to just the JSON (ccusage might print other stuff)
                        if let jsonStart = output.firstIndex(of: "["),
                           let jsonEnd = output.lastIndex(of: "]") {
                            let jsonStr = String(output[jsonStart...jsonEnd])
                            continuation.resume(returning: jsonStr)
                        } else {
                            continuation.resume(returning: output)
                        }
                    } else {
                        // Check stderr
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorStr = String(data: errorData, encoding: .utf8) ?? "ccusage not found or returned no data"
                        continuation.resume(throwing: NSError(domain: "ClaudeUsage", code: 1, userInfo: [NSLocalizedDescriptionKey: errorStr]))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func sevenDaysAgoString() -> String {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: sevenDaysAgo)
    }

    private func saveSnapshot(projectPath: String?, jsonData: String, stats: [DailyUsageStats]) async {
        let totalInput = stats.reduce(0) { $0 + $1.inputTokens }
        let totalOutput = stats.reduce(0) { $0 + $1.outputTokens }
        let totalCache = stats.reduce(0) { $0 + ($1.cacheCreationTokens ?? 0) + ($1.cacheReadTokens ?? 0) }
        let totalCost = stats.reduce(0) { $0 + $1.totalCost }

        let snapshot = ClaudeUsageSnapshot(
            projectPath: projectPath,
            reportType: "daily",
            jsonData: jsonData,
            totalInputTokens: totalInput,
            totalOutputTokens: totalOutput,
            totalCacheTokens: totalCache,
            totalCost: totalCost
        )

        let context = AppModelContainer.shared.mainContext
        context.insert(snapshot)
        try? context.save()
    }

    // MARK: - Formatted Output

    func globalTodayFormatted() -> String {
        guard let stats = globalTodayStats else { return "—" }
        return formatStats(stats)
    }

    func globalWeekFormatted() -> String {
        let totalTokens = globalWeekStats.reduce(0) { $0 + $1.totalTokens }
        let totalCost = globalWeekStats.reduce(0) { $0 + $1.totalCost }
        return "\(formatTokens(totalTokens)) ($\(String(format: "%.2f", totalCost)))"
    }

    func projectTodayFormatted(_ projectPath: String) -> String {
        guard let stats = projectStats[projectPath]?.todayStats else { return "—" }
        return formatStats(stats)
    }

    func projectWeekFormatted(_ projectPath: String) -> String {
        guard let weekStats = projectStats[projectPath]?.weekStats else { return "—" }
        let totalTokens = weekStats.reduce(0) { $0 + $1.totalTokens }
        let totalCost = weekStats.reduce(0) { $0 + $1.totalCost }
        return "\(formatTokens(totalTokens)) ($\(String(format: "%.2f", totalCost)))"
    }

    private func formatStats(_ stats: DailyUsageStats) -> String {
        "\(formatTokens(stats.totalTokens)) ($\(String(format: "%.2f", stats.totalCost)))"
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
