import Foundation
import SwiftData

struct DailySummary {
    let date: Date
    let totalCommits: Int
    let projectsWorkedOn: [String]
    let timeSpentMinutes: Int
    let claudeTokensUsed: Int
    let claudeCost: Double
    let highlights: [String]
}

@MainActor
final class SessionSummaryService {
    static let shared = SessionSummaryService()

    private init() {}

    func generateDailySummary(for date: Date = Date(), context: ModelContext) async -> DailySummary {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch commits for the day
        let commitDescriptor = FetchDescriptor<CachedCommit>(
            predicate: #Predicate { commit in
                commit.date >= startOfDay && commit.date < endOfDay
            }
        )
        let commits = (try? context.fetch(commitDescriptor)) ?? []

        // Fetch time entries for the day
        let timeDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { entry in
                entry.startTime >= startOfDay && entry.startTime < endOfDay
            }
        )
        let timeEntries = (try? context.fetch(timeDescriptor)) ?? []
        let totalMinutes = Int(timeEntries.reduce(0.0) { $0 + $1.duration } / 60)

        // Get unique projects - extract project name from path
        let projectNames = Set(commits.compactMap { URL(fileURLWithPath: $0.projectPath).lastPathComponent })

        // Fetch Claude usage for the day
        let usageDescriptor = FetchDescriptor<ClaudeUsageSnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.capturedAt >= startOfDay && snapshot.capturedAt < endOfDay
            },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        let usageSnapshots = (try? context.fetch(usageDescriptor)) ?? []
        let latestUsage = usageSnapshots.first
        let tokensUsed = (latestUsage?.totalInputTokens ?? 0) + (latestUsage?.totalOutputTokens ?? 0)
        let cost = latestUsage?.totalCost ?? 0

        // Generate highlights
        var highlights: [String] = []

        if commits.count > 0 {
            highlights.append("Made \(commits.count) commit\(commits.count == 1 ? "" : "s")")
        }

        if projectNames.count > 1 {
            highlights.append("Worked on \(projectNames.count) projects")
        }

        if totalMinutes > 60 {
            highlights.append("Spent \(totalMinutes / 60)h \(totalMinutes % 60)m coding")
        }

        if tokensUsed > 100000 {
            highlights.append("Heavy Claude usage: \(tokensUsed / 1000)k tokens")
        }

        return DailySummary(
            date: date,
            totalCommits: commits.count,
            projectsWorkedOn: Array(projectNames),
            timeSpentMinutes: totalMinutes,
            claudeTokensUsed: tokensUsed,
            claudeCost: cost,
            highlights: highlights
        )
    }

    func formatSummary(_ summary: DailySummary) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full

        var lines: [String] = []
        lines.append("# Daily Summary - \(dateFormatter.string(from: summary.date))")
        lines.append("")

        lines.append("## Overview")
        lines.append("- Commits: \(summary.totalCommits)")
        lines.append("- Time Spent: \(summary.timeSpentMinutes / 60)h \(summary.timeSpentMinutes % 60)m")
        lines.append("- Claude Tokens: \(summary.claudeTokensUsed.formatted())")
        lines.append("- Claude Cost: $\(String(format: "%.2f", summary.claudeCost))")
        lines.append("")

        if !summary.projectsWorkedOn.isEmpty {
            lines.append("## Projects")
            for project in summary.projectsWorkedOn {
                lines.append("- \(project)")
            }
            lines.append("")
        }

        if !summary.highlights.isEmpty {
            lines.append("## Highlights")
            for highlight in summary.highlights {
                lines.append("- \(highlight)")
            }
        }

        return lines.joined(separator: "\n")
    }

    func getWeeklySummary(context: ModelContext) async -> [DailySummary] {
        var summaries: [DailySummary] = []
        let calendar = Calendar.current
        let today = Date()

        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let summary = await generateDailySummary(for: date, context: context)
                summaries.append(summary)
            }
        }

        return summaries
    }
}
