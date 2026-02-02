import Foundation
import SwiftUI
import SwiftData
import CryptoKit

@MainActor
class DashboardViewModel: ObservableObject {
    static let shared = DashboardViewModel()

    @Published var projects: [Project] = []
    @Published var activities: [Date: ActivityStats] = [:]
    @Published var aggregatedStats: AggregatedStats = .empty
    @Published var isLoading = false
    @Published var selectedProject: Project?
    @Published var syncLogLines: [String] = []

    private let scanner = ProjectScanner.shared
    private let gitService = GitService.shared
    private let githubClient = GitHubClient.shared
    private var didInitialLoad = false
    private var perProjectActivities: [String: [Date: ActivityStats]] = [:]

    var recentProjects: [Project] {
        // Only show projects that count toward totals in recent projects
        Array(projects.filter { $0.countsTowardTotals }.prefix(6))
    }

    /// Count of projects with recent activity (commits in last 7 days)
    var activeProjectCount: Int {
        projects.filter { $0.status == .active }.count
    }

    /// Count of projects that count toward totals (excludes archived/abandoned)
    var countableProjectCount: Int {
        projects.filter { $0.countsTowardTotals }.count
    }

    /// Count of archived/abandoned projects
    var archivedProjectCount: Int {
        projects.filter { !$0.countsTowardTotals }.count
    }

    /// Total line count across all countable projects
    var totalLineCount: Int {
        projects.filter { $0.countsTowardTotals }.reduce(0) { $0 + $1.lineCount }
    }

    /// Total file count across all countable projects
    var totalFileCount: Int {
        projects.filter { $0.countsTowardTotals }.reduce(0) { $0 + $1.fileCount }
    }

    /// Formatted total line count (e.g., "1.2M")
    var formattedTotalLineCount: String {
        let count = totalLineCount
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    var currentStreak: Int {
        calculateStreak()
    }

    /// Load data from SwiftData cache
    func loadDataIfNeeded() async {
        if didInitialLoad || isLoading { return }
        didInitialLoad = true
        isLoading = true
        defer { isLoading = false }

        let context = AppModelContainer.shared.mainContext

        // Load projects from cache
        do {
            let descriptor = FetchDescriptor<CachedProject>(
                sortBy: [SortDescriptor(\.lastCommitDate, order: .reverse)]
            )
            let cachedProjects = try context.fetch(descriptor)

            if !cachedProjects.isEmpty {
                projects = cachedProjects.map { $0.toProject() }
                print("[Dashboard] Loaded \(projects.count) projects from cache")
            } else {
                // Fall back to scanning if cache is empty
                print("[Dashboard] Cache empty, falling back to scanner")
                await loadDataFromScanner()
                return
            }
        } catch {
            print("[Dashboard] Error loading from cache: \(error)")
            await loadDataFromScanner()
            return
        }

        // Load activities from cache
        do {
            let activityDescriptor = FetchDescriptor<CachedDailyActivity>()
            let cachedActivities = try context.fetch(activityDescriptor)

            var allActivities: [Date: ActivityStats] = [:]
            for cached in cachedActivities {
                let date = cached.date.startOfDay
                if var existing = allActivities[date] {
                    existing.linesAdded += cached.linesAdded
                    existing.linesRemoved += cached.linesRemoved
                    existing.commits += cached.commits
                    allActivities[date] = existing
                } else {
                    allActivities[date] = ActivityStats(
                        date: date,
                        linesAdded: cached.linesAdded,
                        linesRemoved: cached.linesRemoved,
                        commits: cached.commits
                    )
                }
            }
            activities = allActivities
            print("[Dashboard] Loaded \(cachedActivities.count) activity records from cache")
        } catch {
            print("[Dashboard] Error loading activities: \(error)")
        }

        // Calculate aggregated stats
        calculateAggregatedStats()

        // Fetch GitHub stats if authenticated
        await fetchGitHubStats()

        // Kick off a background refresh to update cache with latest data
        Task.detached { @MainActor [weak self] in
            guard let self = self else { return }
            print("[Dashboard] Starting background refresh...")
            await self.loadDataFromScanner()
            print("[Dashboard] Background refresh complete")
        }
    }

    /// Force refresh from scanner (used by manual refresh)
    func refresh() async {
        if isLoading { return }
        await loadDataFromScanner()
    }

    /// Load data by scanning the filesystem (fallback/refresh)
    private func loadDataFromScanner() async {
        isLoading = true
        syncLogLines.removeAll(keepingCapacity: true)
        logSync("sync start")
        defer {
            logSync("sync end")
            isLoading = false
        }

        let codeDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code")

        // Scan projects - pass empty array to get a clean scan (only JSON-sourced projects)
        projects = await scanner.scan(directory: codeDirectory, maxDepth: 10, existingProjects: [])

        for project in projects {
            if let url = project.githubURL {
                logSync("project: \(project.name) remote=\(url)")
            } else {
                logSync("project: \(project.name) remote=none")
            }

            if let m = project.gitMetrics {
                logSync("git: \(project.name) commits7d=\(m.commits7d) commits30d=\(m.commits30d) lines7d=+\(m.linesAdded7d)/-\(m.linesRemoved7d)")
            }
        }

        // Calculate activities from all projects
        await calculateActivitiesFromGit()

        // Calculate aggregated stats
        calculateAggregatedStats()

        // Sync back to SwiftData cache
        await syncToSwiftData()

        // Fetch GitHub stats if authenticated
        await fetchGitHubStats()
    }

    private func calculateActivitiesFromGit() async {
        var allActivities: [Date: ActivityStats] = [:]
        var projectActivitiesMap: [String: [Date: ActivityStats]] = [:]

        for project in projects {
            let projectActivities = gitService.getDailyActivity(at: project.path, days: 365)
            projectActivitiesMap[project.path.path] = projectActivities

            for (date, activity) in projectActivities {
                if var existing = allActivities[date] {
                    existing.merge(with: activity)
                    allActivities[date] = existing
                } else {
                    allActivities[date] = activity
                }
            }
        }

        activities = allActivities
        perProjectActivities = projectActivitiesMap
    }

    private func calculateAggregatedStats() {
        var today = DailyStats()
        var thisWeek = DailyStats()
        var thisMonth = DailyStats()
        var total = DailyStats()

        let now = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfWeek(for: now)
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        for (date, activity) in activities {
            total.linesAdded += activity.linesAdded
            total.linesRemoved += activity.linesRemoved
            total.commits += activity.commits

            if calendar.isDateInToday(date) {
                today.linesAdded += activity.linesAdded
                today.linesRemoved += activity.linesRemoved
                today.commits += activity.commits
            }

            if date >= startOfWeek {
                thisWeek.linesAdded += activity.linesAdded
                thisWeek.linesRemoved += activity.linesRemoved
                thisWeek.commits += activity.commits
            }

            if date >= startOfMonth {
                thisMonth.linesAdded += activity.linesAdded
                thisMonth.linesRemoved += activity.linesRemoved
                thisMonth.commits += activity.commits
            }
        }

        aggregatedStats = AggregatedStats(
            today: today,
            thisWeek: thisWeek,
            thisMonth: thisMonth,
            total: total,
            currentStreak: calculateStreak(),
            totalSourceLines: totalLineCount
        )
    }

    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date().startOfDay

        // Check if there's activity today, if not start from yesterday
        if activities[currentDate] == nil || (activities[currentDate]?.commits ?? 0) == 0 {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }

        while let activity = activities[currentDate], activity.commits > 0 {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }

        return streak
    }

    private func logSync(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        syncLogLines.append("[\(ts)] \(message)")
        if syncLogLines.count > 500 {
            syncLogLines.removeFirst(syncLogLines.count - 500)
        }
    }

    /// Sync current projects and activities back to SwiftData cache
    private func syncToSwiftData() async {
        let context = AppModelContainer.shared.mainContext

        do {
            // Fetch existing cached projects
            let existingDescriptor = FetchDescriptor<CachedProject>()
            let existingCached = try context.fetch(existingDescriptor)
            let existingByPath = Dictionary(uniqueKeysWithValues: existingCached.map { ($0.path, $0) })

            // Update or insert projects
            for project in projects {
                if let cached = existingByPath[project.path.path] {
                    cached.update(from: project)
                } else {
                    let newCached = CachedProject(
                        path: project.path.path,
                        name: project.name,
                        descriptionText: project.description,
                        githubURL: project.githubURL,
                        language: project.language,
                        lineCount: project.lineCount,
                        fileCount: project.fileCount,
                        promptCount: project.promptCount,
                        workLogCount: project.workLogCount,
                        lastCommitHash: project.lastCommit?.id,
                        lastCommitMessage: project.lastCommit?.message,
                        lastCommitAuthor: project.lastCommit?.author,
                        lastCommitDate: project.lastCommit?.date,
                        lastScanned: project.lastScanned,
                        jsonStatus: project.jsonStatus,
                        techStack: project.techStack,
                        languageBreakdown: project.languageBreakdown,
                        structure: project.structure,
                        structureNotes: project.structureNotes,
                        sourceDirectories: project.sourceDirectories,
                        excludedDirectories: project.excludedDirectories,
                        firstCommitDate: project.firstCommitDate,
                        totalCommits: project.totalCommits,
                        branches: project.branches,
                        currentBranch: project.currentBranch,
                        statsGeneratedAt: project.statsGeneratedAt,
                        statsSource: project.statsSource
                    )
                    context.insert(newCached)
                }
            }

            // Delete cached projects that no longer exist
            let currentPaths = Set(projects.map { $0.path.path })
            for cached in existingCached {
                if !currentPaths.contains(cached.path) {
                    context.delete(cached)
                }
            }

            try context.save()
            print("[Dashboard] Synced \(projects.count) projects to SwiftData")
        } catch {
            print("[Dashboard] Error syncing projects to SwiftData: \(error)")
        }

        // Sync activities - reuse the already-computed perProjectActivities
        do {
            // Delete existing activities and recreate
            let activityDescriptor = FetchDescriptor<CachedDailyActivity>()
            let existingActivities = try context.fetch(activityDescriptor)
            for activity in existingActivities {
                context.delete(activity)
            }

            // Insert from perProjectActivities (already computed in calculateActivitiesFromGit)
            for (projectPath, activities) in perProjectActivities {
                for (date, stats) in activities {
                    let cached = CachedDailyActivity(
                        date: date,
                        projectPath: projectPath,
                        linesAdded: stats.linesAdded,
                        linesRemoved: stats.linesRemoved,
                        commits: stats.commits
                    )
                    context.insert(cached)
                }
            }

            try context.save()
            print("[Dashboard] Synced \(perProjectActivities.count) projects' activities to SwiftData")
        } catch {
            print("[Dashboard] Error syncing activities to SwiftData: \(error)")
        }

        // Sync prompts and work logs
        await syncPromptsToSwiftData(context: context)
        await syncWorkLogsToSwiftData(context: context)
    }

    // MARK: - Prompt and Work Log Sync

    private func contentHash(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private func syncPromptsToSwiftData(context: ModelContext) async {
        let fm = FileManager.default

        do {
            let existingDescriptor = FetchDescriptor<CachedPrompt>()
            let existingCached = try context.fetch(existingDescriptor)
            let existingByKey = Dictionary(
                uniqueKeysWithValues: existingCached.map { ("\($0.projectPath)::\($0.filename)", $0) }
            )

            var seenKeys: Set<String> = []

            for project in projects {
                let promptsDir = project.path.appendingPathComponent("prompts")
                guard fm.fileExists(atPath: promptsDir.path) else { continue }

                guard let files = try? fm.contentsOfDirectory(
                    at: promptsDir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                let mdFiles = files.filter { $0.pathExtension == "md" }

                for fileURL in mdFiles {
                    let filename = fileURL.lastPathComponent
                    let key = "\(project.path.path)::\(filename)"
                    seenKeys.insert(key)

                    // Parse prompt number from filename (e.g. "1.md" → 1, "2c.md" → 2)
                    let baseName = fileURL.deletingPathExtension().lastPathComponent
                    let promptNumber = Int(baseName.filter { $0.isNumber }) ?? 0

                    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                    let hash = contentHash(content)

                    let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
                    let fileModified = (attrs?[.modificationDate] as? Date) ?? Date()

                    // Skip if unchanged
                    if let existing = existingByKey[key], existing.contentHash == hash {
                        continue
                    }

                    if let existing = existingByKey[key] {
                        existing.content = content
                        existing.contentHash = hash
                        existing.promptNumber = promptNumber
                        existing.fileModified = fileModified
                        existing.cachedAt = Date()
                    } else {
                        let cached = CachedPrompt(
                            projectPath: project.path.path,
                            promptNumber: promptNumber,
                            filename: filename,
                            content: content,
                            contentHash: hash,
                            fileModified: fileModified
                        )
                        context.insert(cached)
                    }
                }
            }

            // Delete prompts for files that no longer exist
            for cached in existingCached {
                let key = "\(cached.projectPath)::\(cached.filename)"
                if !seenKeys.contains(key) {
                    context.delete(cached)
                }
            }

            try context.save()
            print("[Dashboard] Synced prompts to SwiftData")
        } catch {
            print("[Dashboard] Error syncing prompts: \(error)")
        }
    }

    private func syncWorkLogsToSwiftData(context: ModelContext) async {
        let fm = FileManager.default

        do {
            let existingDescriptor = FetchDescriptor<CachedWorkLog>()
            let existingCached = try context.fetch(existingDescriptor)
            let existingByKey = Dictionary(
                uniqueKeysWithValues: existingCached.map { ("\($0.projectPath)::\($0.filename)::\($0.isStatsFile)", $0) }
            )

            var seenKeys: Set<String> = []

            for project in projects {
                let workDir = project.path.appendingPathComponent("work")
                guard fm.fileExists(atPath: workDir.path) else { continue }

                // Sync top-level work logs (work/*.md)
                syncWorkLogFiles(
                    in: workDir,
                    projectPath: project.path.path,
                    isStats: false,
                    existingByKey: existingByKey,
                    seenKeys: &seenKeys,
                    context: context
                )

                // Sync stats files (work/stats/*.md)
                let statsDir = workDir.appendingPathComponent("stats")
                if fm.fileExists(atPath: statsDir.path) {
                    syncWorkLogFiles(
                        in: statsDir,
                        projectPath: project.path.path,
                        isStats: true,
                        existingByKey: existingByKey,
                        seenKeys: &seenKeys,
                        context: context
                    )
                }
            }

            // Delete work logs for files that no longer exist
            for cached in existingCached {
                let key = "\(cached.projectPath)::\(cached.filename)::\(cached.isStatsFile)"
                if !seenKeys.contains(key) {
                    context.delete(cached)
                }
            }

            try context.save()
            print("[Dashboard] Synced work logs to SwiftData")
        } catch {
            print("[Dashboard] Error syncing work logs: \(error)")
        }
    }

    private func syncWorkLogFiles(
        in directory: URL,
        projectPath: String,
        isStats: Bool,
        existingByKey: [String: CachedWorkLog],
        seenKeys: inout Set<String>,
        context: ModelContext
    ) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let mdFiles = files.filter { $0.pathExtension == "md" }

        for fileURL in mdFiles {
            let filename = fileURL.lastPathComponent
            let key = "\(projectPath)::\(filename)::\(isStats)"
            seenKeys.insert(key)

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let hash = contentHash(content)

            let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
            let fileModified = (attrs?[.modificationDate] as? Date) ?? Date()

            // Skip if unchanged
            if let existing = existingByKey[key], existing.contentHash == hash {
                continue
            }

            // Parse stats fields if this is a stats file
            var started: Date? = nil
            var ended: Date? = nil
            var linesAdded: Int? = nil
            var linesDeleted: Int? = nil
            var commitHash: String? = nil
            var summary: String? = nil

            if isStats {
                let parsed = parseStatsFile(content)
                started = parsed.started
                ended = parsed.ended
                linesAdded = parsed.linesAdded
                linesDeleted = parsed.linesDeleted
                commitHash = parsed.commitHash
                summary = parsed.summary
            }

            if let existing = existingByKey[key] {
                existing.content = content
                existing.contentHash = hash
                existing.fileModified = fileModified
                existing.cachedAt = Date()
                existing.started = started
                existing.ended = ended
                existing.linesAdded = linesAdded
                existing.linesDeleted = linesDeleted
                existing.commitHash = commitHash
                existing.summary = summary
            } else {
                let cached = CachedWorkLog(
                    projectPath: projectPath,
                    filename: filename,
                    content: content,
                    contentHash: hash,
                    fileModified: fileModified,
                    isStatsFile: isStats,
                    started: started,
                    ended: ended,
                    linesAdded: linesAdded,
                    linesDeleted: linesDeleted,
                    commitHash: commitHash,
                    summary: summary
                )
                context.insert(cached)
            }
        }
    }

    private func parseStatsFile(_ content: String) -> (
        started: Date?, ended: Date?, linesAdded: Int?,
        linesDeleted: Int?, commitHash: String?, summary: String?
    ) {
        let lines = content.components(separatedBy: .newlines)
        var started: Date? = nil
        var ended: Date? = nil
        var linesAdded: Int? = nil
        var linesDeleted: Int? = nil
        var commitHash: String? = nil
        var summaryLines: [String] = []
        var pastHeader = false

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !pastHeader {
                if trimmed.isEmpty && (started != nil || commitHash != nil) {
                    pastHeader = true
                    continue
                }

                if trimmed.hasPrefix("started:") {
                    let value = trimmed.replacingOccurrences(of: "started:", with: "").trimmingCharacters(in: .whitespaces)
                    started = dateFormatter.date(from: value) ?? simpleDateFormatter.date(from: value)
                } else if trimmed.hasPrefix("ended:") {
                    let value = trimmed.replacingOccurrences(of: "ended:", with: "").trimmingCharacters(in: .whitespaces)
                    ended = dateFormatter.date(from: value) ?? simpleDateFormatter.date(from: value)
                } else if trimmed.hasPrefix("lines_added:") {
                    let value = trimmed.replacingOccurrences(of: "lines_added:", with: "").trimmingCharacters(in: .whitespaces)
                    linesAdded = Int(value)
                } else if trimmed.hasPrefix("lines_deleted:") {
                    let value = trimmed.replacingOccurrences(of: "lines_deleted:", with: "").trimmingCharacters(in: .whitespaces)
                    linesDeleted = Int(value)
                } else if trimmed.hasPrefix("commit:") {
                    commitHash = trimmed.replacingOccurrences(of: "commit:", with: "").trimmingCharacters(in: .whitespaces)
                }
            } else {
                summaryLines.append(line)
            }
        }

        let summary = summaryLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return (started, ended, linesAdded, linesDeleted, commitHash, summary.isEmpty ? nil : summary)
    }

    private func fetchGitHubStats() async {
        githubClient.refreshAuthStatus()
        if !githubClient.isAuthenticated {
            logSync("github: skipped (not authenticated)")
            return
        }

        for i in projects.indices {
            let projectName = projects[i].name

            guard let urlString = projects[i].githubURL, !urlString.isEmpty else {
                projects[i].githubStats = nil
                projects[i].githubStatsError = "skipped: no github remote"
                logSync("github: SKIP \(projectName) (no remote)")
                continue
            }

            guard let (owner, repo) = GitHubClient.parseGitHubURL(urlString) else {
                projects[i].githubStats = nil
                projects[i].githubStatsError = "skipped: unparsable github url"
                logSync("github: SKIP \(projectName) (bad url: \(urlString))")
                continue
            }

            do {
                let repoInfo = try await githubClient.getRepo(owner: owner, repo: repo)
                projects[i].githubStats = GitHubStats(
                    stars: repoInfo.stargazersCount,
                    forks: repoInfo.forksCount,
                    openIssues: repoInfo.openIssuesCount
                )
                projects[i].githubStatsError = nil
                logSync("github: OK \(projectName) (\(owner)/\(repo))")
            } catch {
                projects[i].githubStats = nil
                projects[i].githubStatsError = String(describing: error)
                logSync("github: FAIL \(projectName) (\(owner)/\(repo)) \(error)")
                continue
            }
        }
    }
}
