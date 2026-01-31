import Foundation
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var activities: [Date: ActivityStats] = [:]
    @Published var aggregatedStats: AggregatedStats = .empty
    @Published var isLoading = false
    @Published var selectedProject: Project?
    @Published var syncLogLines: [String] = []

    private let scanner = ProjectScanner.shared
    private let gitService = GitService.shared
    private let githubClient = GitHubClient.shared

    var recentProjects: [Project] {
        Array(projects.prefix(5))
    }

    var activeProjectCount: Int {
        projects.filter { $0.status == .active }.count
    }

    var currentStreak: Int {
        calculateStreak()
    }

    func loadData() async {
        isLoading = true
        syncLogLines.removeAll(keepingCapacity: true)
        logSync("sync start")
        defer {
            logSync("sync end")
            isLoading = false
        }

        let codeDirectory = SettingsViewModel.shared.codeDirectory

        // Scan projects
        projects = await scanner.scan(directory: codeDirectory)

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
        await calculateActivities()

        // Calculate aggregated stats
        calculateAggregatedStats()

        // Fetch GitHub stats if authenticated
        await fetchGitHubStats()
    }

    func refresh() async {
        if isLoading { return }
        await loadData()
    }

    private func calculateActivities() async {
        var allActivities: [Date: ActivityStats] = [:]

        for project in projects {
            let projectActivities = gitService.getDailyActivity(at: project.path, days: 365)

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
            currentStreak: calculateStreak()
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
