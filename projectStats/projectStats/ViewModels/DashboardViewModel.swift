import Foundation
import SwiftUI
import SwiftData
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
    private let syncService = ProjectSyncService.shared
    private let activityService = ActivityCalculationService.shared
    private let githubSyncService = GitHubSyncService.shared
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

    // MARK: - Computed Properties

    var recentProjects: [Project] {
        Array(recentProjectsSorted.prefix(6))
    }

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

    var activeProjectCount: Int {
        projects.filter { $0.status == .active }.count
    }

    var countableProjectCount: Int {
        projects.filter { $0.countsTowardTotals }.count
    }

    var archivedProjectCount: Int {
        projects.filter { !$0.countsTowardTotals }.count
    }

    var totalLineCount: Int {
        projects.filter { $0.countsTowardTotals }.reduce(0) { $0 + $1.lineCount }
    }

    var totalFileCount: Int {
        projects.filter { $0.countsTowardTotals }.reduce(0) { $0 + $1.fileCount }
    }

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
        activityService.calculateStreak(activities: activities)
    }

    // MARK: - Loading

    func loadDataIfNeeded() async {
        if didInitialLoad || isLoading { return }
        didInitialLoad = true
        isLoading = true
        defer { isLoading = false }

        let context = AppModelContainer.shared.mainContext

        do {
            let descriptor = FetchDescriptor<CachedProject>(
                sortBy: [SortDescriptor(\.lastCommitDate, order: .reverse)]
            )
            let cachedProjects = try context.fetch(descriptor)

            if !cachedProjects.isEmpty {
                projects = cachedProjects.map { $0.toProject() }
                Log.data.info("[Dashboard] Loaded \(self.projects.count) projects from cache")
            } else {
                Log.data.info("[Dashboard] Cache empty, falling back to scanner")
                await loadDataFromScanner()
                return
            }
        } catch {
            Log.data.error("[Dashboard] Error loading from cache: \(error)")
            await loadDataFromScanner()
            return
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
            Log.data.info("[Dashboard] Loaded \(cachedActivities.count) activity records from cache")
        } catch {
            Log.data.error("[Dashboard] Error loading activities: \(error)")
        }

        recalculateAggregatedStats()

        projects = await githubSyncService.fetchGitHubStats(for: projects, logSync: logSync)

        Task { [weak self] in
            guard let self else { return }
            Log.sync.info("[Dashboard] Starting background refresh...")
            await self.loadDataFromScanner()
            Log.sync.info("[Dashboard] Background refresh complete")
        }
    }

    func reloadProjectsFromDB() async {
        let result = await syncService.reloadFromCache()
        projects = result.projects
        activities = result.activities
        recalculateAggregatedStats()
    }

    func refresh() async {
        if isLoading { return }
        await loadDataFromScanner()
    }

    func scanWorkingFolder(at url: URL) async -> ScanResult {
        if isLoading { return ScanResult(projectsFound: 0, promptsImported: 0, workLogsImported: 0) }
        isLoading = true
        defer { isLoading = false }

        projects = await scanner.scan(directory: url, maxDepth: 10, existingProjects: projects)

        let promptCount = syncService.countPromptFiles(for: projects)
        let workCount = syncService.countWorkLogFiles(for: projects)

        let activityResult = await activityService.calculateActivitiesFromGit(projects: projects)
        activities = activityResult.merged
        perProjectActivities = activityResult.perProject
        recalculateAggregatedStats()
        await syncService.syncToSwiftData(projects: projects, perProjectActivities: perProjectActivities)

        return ScanResult(projectsFound: projects.count, promptsImported: promptCount, workLogsImported: workCount)
    }

    // MARK: - Single Project Sync

    func syncSingleProject(path: String) async {
        if let updated = await syncService.syncSingleProject(path: path, projects: projects) {
            if let index = projects.firstIndex(where: { $0.path.path == path }) {
                projects[index] = updated
            }
        }
    }

    // MARK: - Favorites

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

    // MARK: - Private

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

    private func recalculateAggregatedStats() {
        aggregatedStats = activityService.calculateAggregatedStats(
            activities: activities,
            totalLineCount: totalLineCount,
            streak: activityService.calculateStreak(activities: activities)
        )
    }

    private func loadDataFromScanner() async {
        isLoading = true
        syncLogLines.removeAll(keepingCapacity: true)
        logSync("sync start")
        defer {
            logSync("sync end")
            isLoading = false
        }

        let codeDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code")

        projects = await scanner.scan(directory: codeDirectory, maxDepth: 10, existingProjects: [])

        for customPath in SettingsViewModel.shared.customProjectPaths {
            let url = URL(fileURLWithPath: customPath)
            if FileManager.default.fileExists(atPath: customPath) {
                let customProjects = await scanner.scan(directory: url, maxDepth: 1, existingProjects: projects)
                for cp in customProjects where !projects.contains(where: { $0.path == cp.path }) {
                    projects.append(cp)
                }
            }
        }

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

        let activityResult = await activityService.calculateActivitiesFromGit(projects: projects)
        activities = activityResult.merged
        perProjectActivities = activityResult.perProject

        recalculateAggregatedStats()
        checkLineCountAndProjectAchievements()
        await syncService.syncToSwiftData(projects: projects, perProjectActivities: perProjectActivities)

        projects = await githubSyncService.fetchGitHubStats(for: projects, logSync: logSync)

        let reloaded = await syncService.reloadFromCache()
        projects = reloaded.projects
        activities = reloaded.activities
        recalculateAggregatedStats()
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

    private func checkLineCountAndProjectAchievements() {
        let weeklyAdded = aggregatedStats.thisWeek.linesAdded
        let weeklyRemoved = aggregatedStats.thisWeek.linesRemoved
        let projectPath = projects.first(where: { $0.status == .active })?.path.path

        AchievementService.shared.checkLineCountAchievements(
            projectPath: projectPath ?? "",
            weeklyLinesAdded: weeklyAdded,
            weeklyLinesRemoved: weeklyRemoved
        )
        AchievementService.shared.checkProjectDiversityAchievements()
    }
}
