import Foundation
import SwiftUI
import SwiftData
import CryptoKit
import os.log

@MainActor
class DashboardViewModel: ObservableObject {
    static let shared = DashboardViewModel()

    @Published var projects: [Project] = [] {
        didSet {
            pruneFavoritesForCurrentProjects()
        }
    }
    @Published var activities: [Date: ActivityStats] = [:]
    @Published var aggregatedStats: AggregatedStats = .empty
    @Published var isLoading = false
    @Published var selectedProject: Project?
    @Published var syncLogLines: [String] = []
    @Published private(set) var favoriteProjectPaths: [String] = [] {
        didSet {
            saveFavorites()
        }
    }

    private let scanner = ProjectScanner.shared
    private let gitService = GitService.shared
    private let githubClient = GitHubClient.shared
    private var didInitialLoad = false
    private var perProjectActivities: [String: [Date: ActivityStats]] = [:]
    private let favoritesKey = "favoriteProjectPaths"
    private let favoriteLimit = 3

    struct ScanResult: Hashable {
        let projectsFound: Int
        let promptsImported: Int
        let workLogsImported: Int
    }

    init() {
        loadFavorites()
    }

    var recentProjects: [Project] {
        // Only show projects that count toward totals in recent projects
        Array(recentProjectsSorted.prefix(6))
    }

    /// Projects to show in the Home grid (favorites can take slots 4-6)
    var homeProjects: [Project] {
        let recents = recentProjectsSorted
        var selected: [Project] = []

        for project in recents {
            if selected.count >= 3 { break }
            selected.append(project)
        }

        let favoriteCandidates = favoriteProjects.filter { favorite in
            !selected.contains(favorite)
        }

        for favorite in favoriteCandidates {
            if selected.count >= 6 { break }
            selected.append(favorite)
        }

        if selected.count < 6 {
            for project in recents {
                if selected.count >= 6 { break }
                if !selected.contains(project) {
                    selected.append(project)
                }
            }
        }

        return selected
    }

    var canAddFavorite: Bool {
        favoriteProjectPaths.count < favoriteLimit
    }

    func isFavorite(_ project: Project) -> Bool {
        favoriteProjectPaths.contains(project.path.path)
    }

    func toggleFavorite(_ project: Project) {
        let path = project.path.path
        if let index = favoriteProjectPaths.firstIndex(of: path) {
            favoriteProjectPaths.remove(at: index)
            return
        }

        guard favoriteProjectPaths.count < favoriteLimit else { return }
        favoriteProjectPaths.append(path)
    }

    private var favoriteProjects: [Project] {
        favoriteProjectPaths.compactMap { path in
            projects.first { $0.path.path == path }
        }
    }

    private var recentProjectsSorted: [Project] {
        let countableProjects = projects.filter { $0.countsTowardTotals }
        return countableProjects.sorted { (p1, p2) -> Bool in
            let date1 = p1.lastCommit?.date ?? .distantPast
            let date2 = p2.lastCommit?.date ?? .distantPast
            if date1 != date2 {
                return date1 > date2
            }
            return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
        }
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
                Log.data.info("[Dashboard] Loaded \(self.projects.count) projects from cache")
            } else {
                // Fall back to scanning if cache is empty
                Log.data.info("[Dashboard] Cache empty, falling back to scanner")
                await loadDataFromScanner()
                return
            }
        } catch {
            Log.data.error("[Dashboard] Error loading from cache: \(error)")
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
            Log.data.info("[Dashboard] Loaded \(cachedActivities.count) activity records from cache")
        } catch {
            Log.data.error("[Dashboard] Error loading activities: \(error)")
        }

        // Calculate aggregated stats
        calculateAggregatedStats()

        // Fetch GitHub stats if authenticated
        await fetchGitHubStats()

        // Kick off a background refresh to update cache with latest data
        Task { [weak self] in
            guard let self else { return }
            Log.sync.info("[Dashboard] Starting background refresh...")
            await self.loadDataFromScanner()
            Log.sync.info("[Dashboard] Background refresh complete")
        }
    }

    /// Fast reload of projects from SwiftData cache (no filesystem scan).
    /// Use after inserting a CachedProject directly to populate the in-memory array.
    func reloadProjectsFromDB() async {
        await reloadFromCache(context: AppModelContainer.shared.mainContext)
    }

    /// Force refresh from scanner (used by manual refresh)
    func refresh() async {
        if isLoading { return }
        await loadDataFromScanner()
    }

    func scanWorkingFolder(at url: URL) async -> ScanResult {
        if isLoading { return ScanResult(projectsFound: 0, promptsImported: 0, workLogsImported: 0) }
        isLoading = true
        defer { isLoading = false }

        projects = await scanner.scan(directory: url, maxDepth: 10, existingProjects: projects)

        let promptCount = countPromptFiles(for: projects)
        let workCount = countWorkLogFiles(for: projects)

        await calculateActivitiesFromGit()
        calculateAggregatedStats()
        await syncToSwiftData()

        return ScanResult(projectsFound: projects.count, promptsImported: promptCount, workLogsImported: workCount)
    }

    // MARK: - Comprehensive Data Sync

    func syncSingleProject(path: String) async {
        guard let project = projects.first(where: { $0.path.path == path }) else { return }

        let context = AppModelContainer.shared.mainContext

        await syncPrompts(for: project, context: context)
        await syncWorkLogs(for: project, context: context)
        await syncRecentCommits(for: project, context: context)
        await syncProjectStats(for: project, context: context)

        do {
            try context.save()
        } catch {
            Log.sync.error("[Dashboard] Error saving single-project sync: \(error)")
        }

        // Update just this project in-memory instead of full DB reload
        if let updatedCached = try? context.fetch(FetchDescriptor<CachedProject>(
            predicate: #Predicate { $0.path == path }
        )).first {
            if let index = projects.firstIndex(where: { $0.path.path == path }) {
                projects[index] = updatedCached.toProject()
            }
        }
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

        // Also scan custom project paths
        for customPath in SettingsViewModel.shared.customProjectPaths {
            let url = URL(fileURLWithPath: customPath)
            if FileManager.default.fileExists(atPath: customPath) {
                let customProjects = await scanner.scan(directory: url, maxDepth: 1, existingProjects: projects)
                for cp in customProjects where !projects.contains(where: { $0.path == cp.path }) {
                    projects.append(cp)
                }
            }
        }

        // Merge in manually-added projects from DB that scanner missed
        // (projects without projectstats.json but with valid folders)
        let mergeContext = AppModelContainer.shared.mainContext
        if let cachedProjects = try? mergeContext.fetch(FetchDescriptor<CachedProject>()) {
            let scannedPaths = Set(projects.map { $0.path.path })
            for cached in cachedProjects {
                if !scannedPaths.contains(cached.path) &&
                   FileManager.default.fileExists(atPath: cached.path) {
                    projects.append(cached.toProject())
                }
            }
        }

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

        // Check line count and project diversity achievements
        checkLineCountAndProjectAchievements()

        // Sync back to SwiftData cache
        await syncToSwiftData()

        // Fetch GitHub stats if authenticated
        await fetchGitHubStats()

        // Reload from SwiftData for UI consistency
        await reloadFromCache(context: AppModelContainer.shared.mainContext)
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

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }

        favoriteProjectPaths = normalizedFavoritePaths(decoded)
    }

    private func saveFavorites() {
        guard let encoded = try? JSONEncoder().encode(favoriteProjectPaths) else { return }
        UserDefaults.standard.set(encoded, forKey: favoritesKey)
    }

    private func normalizedFavoritePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for path in paths {
            if seen.insert(path).inserted {
                normalized.append(path)
            }
            if normalized.count >= favoriteLimit {
                break
            }
        }

        return normalized
    }

    private func pruneFavoritesForCurrentProjects() {
        guard !favoriteProjectPaths.isEmpty else { return }
        let existingPaths = Set(projects.map { $0.path.path })
        let pruned = normalizedFavoritePaths(favoriteProjectPaths.filter { existingPaths.contains($0) })
        if pruned != favoriteProjectPaths {
            favoriteProjectPaths = pruned
        }
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

            // Delete cached projects only if their folder no longer exists on disk
            let currentPaths = Set(projects.map { $0.path.path })
            for cached in existingCached {
                if !currentPaths.contains(cached.path) &&
                   !FileManager.default.fileExists(atPath: cached.path) {
                    context.delete(cached)
                }
            }

            try context.save()
            Log.data.info("[Dashboard] Synced \(self.projects.count) projects to SwiftData")
        } catch {
            Log.data.error("[Dashboard] Error syncing projects to SwiftData: \(error)")
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
            Log.data.info("[Dashboard] Synced \(self.perProjectActivities.count) projects' activities to SwiftData")
        } catch {
            Log.data.error("[Dashboard] Error syncing activities to SwiftData: \(error)")
        }

        // Sync prompts and work logs
        await syncPromptsToSwiftData(context: context)
        await syncWorkLogsToSwiftData(context: context)
    }

    // MARK: - Prompt and Work Log Sync

    private func contentHash(_ string: String) -> String {
        string.sha256Hash
    }

    private func reloadFromCache(context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<CachedProject>(
                sortBy: [SortDescriptor(\.lastCommitDate, order: .reverse)]
            )
            let cachedProjects = try context.fetch(descriptor)
            projects = cachedProjects.map { $0.toProject() }
        } catch {
            Log.data.error("[Dashboard] Error loading projects from cache: \(error)")
        }

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
        } catch {
            Log.data.error("[Dashboard] Error loading activities from cache: \(error)")
        }

        calculateAggregatedStats()
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
            Log.sync.info("[Dashboard] Synced prompts to SwiftData")
        } catch {
            Log.sync.error("[Dashboard] Error syncing prompts: \(error)")
        }
    }

    private func syncPrompts(for project: Project, context: ModelContext) async {
        let fm = FileManager.default
        let promptsDir = project.path.appendingPathComponent("prompts")
        guard fm.fileExists(atPath: promptsDir.path) else { return }

        let projectPath = project.path.path
        do {
            let existingDescriptor = FetchDescriptor<CachedPrompt>(
                predicate: #Predicate { $0.projectPath == projectPath }
            )
            let existingCached = try context.fetch(existingDescriptor)
            let existingByFilename = Dictionary(uniqueKeysWithValues: existingCached.map { ($0.filename, $0) })

            var seen: Set<String> = []

            guard let files = try? fm.contentsOfDirectory(
                at: promptsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            let mdFiles = files.filter { $0.pathExtension == "md" }

            for fileURL in mdFiles {
                let filename = fileURL.lastPathComponent
                seen.insert(filename)

                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let promptNumber = Int(baseName.filter { $0.isNumber }) ?? 0

                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let hash = contentHash(content)

                let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
                let fileModified = (attrs?[.modificationDate] as? Date) ?? Date()

                if let existing = existingByFilename[filename], existing.contentHash == hash {
                    continue
                }

                if let existing = existingByFilename[filename] {
                    existing.content = content
                    existing.contentHash = hash
                    existing.promptNumber = promptNumber
                    existing.fileModified = fileModified
                    existing.cachedAt = Date()
                } else {
                    let cached = CachedPrompt(
                        projectPath: projectPath,
                        promptNumber: promptNumber,
                        filename: filename,
                        content: content,
                        contentHash: hash,
                        fileModified: fileModified
                    )
                    context.insert(cached)
                }
            }

            for cached in existingCached where !seen.contains(cached.filename) {
                context.delete(cached)
            }
        } catch {
            Log.sync.error("[Dashboard] Error syncing prompts for project: \(error)")
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
            Log.sync.info("[Dashboard] Synced work logs to SwiftData")
        } catch {
            Log.sync.error("[Dashboard] Error syncing work logs: \(error)")
        }
    }

    private func syncWorkLogs(for project: Project, context: ModelContext) async {
        let fm = FileManager.default
        let workDir = project.path.appendingPathComponent("work")
        guard fm.fileExists(atPath: workDir.path) else { return }

        let projectPath = project.path.path
        do {
            let existingDescriptor = FetchDescriptor<CachedWorkLog>(
                predicate: #Predicate { $0.projectPath == projectPath }
            )
            let existingCached = try context.fetch(existingDescriptor)
            let existingByKey = Dictionary(
                uniqueKeysWithValues: existingCached.map { ("\($0.filename)::\($0.isStatsFile)", $0) }
            )

            var seenKeys: Set<String> = []

            syncWorkLogFiles(
                in: workDir,
                projectPath: project.path.path,
                isStats: false,
                existingByKey: existingByKey,
                seenKeys: &seenKeys,
                context: context
            )

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

            for cached in existingCached {
                let key = "\(cached.filename)::\(cached.isStatsFile)"
                if !seenKeys.contains(key) {
                    context.delete(cached)
                }
            }
        } catch {
            Log.sync.error("[Dashboard] Error syncing work logs for project: \(error)")
        }
    }

    private func syncRecentCommits(for project: Project, context: ModelContext) async {
        let gitDir = project.path.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else { return }

        let projectPath = project.path.path
        let format = "%H%x1f%h%x1f%s%x1f%an%x1f%ae%x1f%aI"
        let command = "cd '\(projectPath)' && git log --pretty=format:'\(format)' --numstat -50"
        let result = Shell.runResult(command)
        guard result.exitCode == 0, !result.output.isEmpty else { return }

        let commits = parseGitLogOutput(result.output, projectPath: projectPath)
        if commits.isEmpty { return }

        do {
            let existingDescriptor = FetchDescriptor<CachedCommit>(
                predicate: #Predicate { $0.projectPath == projectPath }
            )
            let existing = try context.fetch(existingDescriptor)
            let existingIds = Set(existing.map { $0.commitHash ?? $0.shortHash })

            for commit in commits {
                let commitId = commit.commitHash ?? commit.shortHash
                if existingIds.contains(commitId) { continue }
                context.insert(commit)
            }
        } catch {
            Log.sync.error("[Dashboard] Error syncing recent commits: \(error)")
        }
    }

    private func parseGitLogOutput(_ output: String, projectPath: String) -> [CachedCommit] {
        var commits: [CachedCommit] = []
        var current: (hash: String, shortHash: String, message: String, author: String, email: String, date: Date)?
        var linesAdded = 0
        var linesDeleted = 0
        var filesChanged = 0

        let lines = output.components(separatedBy: .newlines)
        let dateFormatter = ISO8601DateFormatter()

        for line in lines {
            if line.contains("\u{1f}") {
                if let current = current {
                    commits.append(CachedCommit(
                        projectPath: projectPath,
                        commitHash: current.hash,
                        shortHash: current.shortHash,
                        message: current.message,
                        author: current.author,
                        authorEmail: current.email,
                        date: current.date,
                        linesAdded: linesAdded,
                        linesDeleted: linesDeleted,
                        filesChanged: filesChanged
                    ))
                }

                let parts = line.components(separatedBy: "\u{1f}")
                if parts.count >= 6 {
                    current = (
                        hash: parts[0],
                        shortHash: parts[1],
                        message: parts[2],
                        author: parts[3],
                        email: parts[4],
                        date: dateFormatter.date(from: parts[5]) ?? Date()
                    )
                } else {
                    current = nil
                }

                linesAdded = 0
                linesDeleted = 0
                filesChanged = 0
            } else if !line.isEmpty {
                let parts = line.components(separatedBy: "\t")
                if parts.count >= 2 {
                    linesAdded += Int(parts[0]) ?? 0
                    linesDeleted += Int(parts[1]) ?? 0
                    filesChanged += 1
                }
            }
        }

        if let current = current {
            commits.append(CachedCommit(
                projectPath: projectPath,
                commitHash: current.hash,
                shortHash: current.shortHash,
                message: current.message,
                author: current.author,
                authorEmail: current.email,
                date: current.date,
                linesAdded: linesAdded,
                linesDeleted: linesDeleted,
                filesChanged: filesChanged
            ))
        }

        return commits
    }

    private func countPromptFiles(for projects: [Project]) -> Int {
        let fm = FileManager.default
        var count = 0
        for project in projects {
            let promptsDir = project.path.appendingPathComponent("prompts")
            guard fm.fileExists(atPath: promptsDir.path) else { continue }
            guard let files = try? fm.contentsOfDirectory(at: promptsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            count += files.filter { $0.pathExtension == "md" }.count
        }
        return count
    }

    private func countWorkLogFiles(for projects: [Project]) -> Int {
        let fm = FileManager.default
        var count = 0
        for project in projects {
            let workDir = project.path.appendingPathComponent("work")
            guard fm.fileExists(atPath: workDir.path) else { continue }
            if let files = try? fm.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                count += files.filter { $0.pathExtension == "md" }.count
            }
            let statsDir = workDir.appendingPathComponent("stats")
            if fm.fileExists(atPath: statsDir.path),
               let statFiles = try? fm.contentsOfDirectory(at: statsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                count += statFiles.filter { $0.pathExtension == "md" }.count
            }
        }
        return count
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

    private func syncProjectStats(for project: Project, context: ModelContext) async {
        do {
            let projectPath = project.path.path
            let projectDescriptor = FetchDescriptor<CachedProject>(
                predicate: #Predicate { $0.path == projectPath }
            )
            guard let cached = try context.fetch(projectDescriptor).first else { return }

            let promptDescriptor = FetchDescriptor<CachedPrompt>(
                predicate: #Predicate { $0.projectPath == projectPath }
            )
            cached.promptCount = (try? context.fetchCount(promptDescriptor)) ?? 0

            let workLogDescriptor = FetchDescriptor<CachedWorkLog>(
                predicate: #Predicate { $0.projectPath == projectPath && $0.isStatsFile == false }
            )
            cached.workLogCount = (try? context.fetchCount(workLogDescriptor)) ?? 0

            let commitDescriptor = FetchDescriptor<CachedCommit>(
                predicate: #Predicate { $0.projectPath == projectPath },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            if let latestCommit = try? context.fetch(commitDescriptor).first {
                cached.lastCommitHash = latestCommit.shortHash
                cached.lastCommitMessage = latestCommit.message
                cached.lastCommitAuthor = latestCommit.author
                cached.lastCommitDate = latestCommit.date
            }

            let (freshLines, freshFiles) = LineCounter.countLines(in: project.path)
            cached.lineCount = freshLines
            cached.fileCount = freshFiles

            cached.lastScanned = Date()
        } catch {
            Log.sync.error("[Dashboard] Error syncing project stats: \(error)")
        }
    }

    private func checkLineCountAndProjectAchievements() {
        let weeklyAdded = aggregatedStats.thisWeek.linesAdded
        let weeklyRemoved = aggregatedStats.thisWeek.linesRemoved

        // Pick the first active project path for attribution
        let projectPath = projects.first(where: { $0.status == .active })?.path.path

        AchievementService.shared.checkLineCountAchievements(
            projectPath: projectPath ?? "",
            weeklyLinesAdded: weeklyAdded,
            weeklyLinesRemoved: weeklyRemoved
        )
        AchievementService.shared.checkProjectDiversityAchievements()
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
