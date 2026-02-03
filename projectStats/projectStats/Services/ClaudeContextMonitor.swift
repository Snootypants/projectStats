import Foundation

struct ClaudeContextSummary: Hashable {
    let totalTokens: Int
    let maxTokens: Int
    let percent: Double

    var percentString: String {
        String(format: "%.0f%% (%dk/%dk)", percent * 100, totalTokens / 1000, maxTokens / 1000)
    }
}

@MainActor
final class ClaudeContextMonitor: ObservableObject {
    static let shared = ClaudeContextMonitor()

    @Published var latestContextSummary: ClaudeContextSummary?
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var error: String?

    private let maxTokens = 200_000
    private var refreshTimer: Timer?
    private var hasNotifiedHighContext = false

    private init() {
        startTimer()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let summary = try await loadLatestSummary() {
                latestContextSummary = summary
                lastUpdated = Date()
                error = nil
                handleThresholds(summary)
            } else {
                error = "No recent Claude transcripts found"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    private func loadLatestSummary() async throws -> ClaudeContextSummary? {
        let baseURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        guard FileManager.default.fileExists(atPath: baseURL.path) else {
            return nil
        }

        guard let enumerator = FileManager.default.enumerator(at: baseURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return nil
        }

        var latestFile: URL?
        var latestDate: Date = .distantPast

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = attrs?.contentModificationDate ?? .distantPast
            if modified > latestDate {
                latestDate = modified
                latestFile = url
            }
        }

        guard let latestFile else { return nil }
        let content = try String(contentsOf: latestFile, encoding: .utf8)
        let lines = content.split(separator: "\n").suffix(200)

        for line in lines.reversed() {
            guard let data = line.data(using: .utf8) else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let usage = extractUsage(from: json) {
                let total = usage.input + usage.cacheRead + usage.cacheCreate
                let percent = min(1, Double(total) / Double(maxTokens))
                return ClaudeContextSummary(totalTokens: total, maxTokens: maxTokens, percent: percent)
            }
        }

        return nil
    }

    private func extractUsage(from json: Any) -> (input: Int, cacheRead: Int, cacheCreate: Int)? {
        if let dict = json as? [String: Any] {
            if let usage = dict["usage"] as? [String: Any] {
                return parseUsageDict(usage)
            }
            for value in dict.values {
                if let found = extractUsage(from: value) {
                    return found
                }
            }
        } else if let array = json as? [Any] {
            for value in array {
                if let found = extractUsage(from: value) {
                    return found
                }
            }
        }

        return nil
    }

    private func parseUsageDict(_ dict: [String: Any]) -> (input: Int, cacheRead: Int, cacheCreate: Int)? {
        let input = dict["input_tokens"] as? Int ?? 0
        let cacheRead = dict["cache_read_input_tokens"] as? Int ?? 0
        let cacheCreate = dict["cache_creation_input_tokens"] as? Int ?? 0
        if input == 0 && cacheRead == 0 && cacheCreate == 0 {
            return nil
        }
        return (input, cacheRead, cacheCreate)
    }

    private func handleThresholds(_ summary: ClaudeContextSummary) {
        guard SettingsViewModel.shared.notifyContextHigh else { return }
        if summary.percent >= 0.8, !hasNotifiedHighContext {
            NotificationService.shared.sendNotification(
                title: "Context window high",
                message: "Claude context is at \(summary.percentString)."
            )
            hasNotifiedHighContext = true
        }

        if summary.percent < 0.7 {
            hasNotifiedHighContext = false
        }
    }
}
