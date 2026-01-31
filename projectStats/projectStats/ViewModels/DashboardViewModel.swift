import Foundation
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var activities: [Date: ActivityStats] = [:]
    @Published var aggregatedStats: AggregatedStats = .empty
    @Published var isLoading = false
    @Published var selectedProject: Project?

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
        defer { isLoading = false }

        let codeDirectory = SettingsViewModel.shared.codeDirectory

        // Scan projects
        projects = await scanner.scan(directory: codeDirectory)

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

    private func fetchGitHubStats() async {
        githubClient.refreshAuthStatus()
        guard githubClient.isAuthenticated else { return }

        var failures: [(repo: String, error: Error)] = []

        for i in projects.indices {
            guard let urlString = projects[i].githubURL,
                  let (owner, repo) = GitHubClient.parseGitHubURL(urlString) else {
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
            } catch {
                projects[i].githubStats = nil
                projects[i].githubStatsError = String(describing: error)
                failures.append((repo: "\(owner)/\(repo)", error: error))
                continue
            }
        }

        if !failures.isEmpty {
            let summary = failures
                .map { "\($0.repo): \($0.error)" }
                .joined(separator: "\n")
            print("GitHub stats fetch failures (\(failures.count)):\n\(summary)")
        }
    }
}
