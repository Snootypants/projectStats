import Foundation
import os.log

@MainActor
final class ActivityCalculationService {
    static let shared = ActivityCalculationService()
    private let gitService = GitService.shared
    private init() {}

    func calculateActivitiesFromGit(projects: [Project]) async -> (merged: [Date: ActivityStats], perProject: [String: [Date: ActivityStats]]) {
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

        return (allActivities, projectActivitiesMap)
    }

    func calculateAggregatedStats(activities: [Date: ActivityStats], totalLineCount: Int, streak: Int) -> AggregatedStats {
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

        return AggregatedStats(
            today: today,
            thisWeek: thisWeek,
            thisMonth: thisMonth,
            total: total,
            currentStreak: streak,
            totalSourceLines: totalLineCount
        )
    }

    func calculateStreak(activities: [Date: ActivityStats]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date().startOfDay

        if activities[currentDate] == nil || (activities[currentDate]?.commits ?? 0) == 0 {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }

        while let activity = activities[currentDate], activity.commits > 0 {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }

        return streak
    }
}
