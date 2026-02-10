import Foundation
import SwiftData

/// Scope D: Computes token economics across VIBE sessions
@MainActor
final class TokenEconomicsService: ObservableObject {
    static let shared = TokenEconomicsService()
    private init() {}

    struct Economics {
        let totalSessions: Int
        let totalCost: Double
        let totalInputTokens: Int
        let totalOutputTokens: Int
        let totalCacheReadTokens: Int
        let totalCacheCreationTokens: Int
        let totalDurationMs: Int
        let totalDurationApiMs: Int
        let errorCount: Int

        // Time-period spend
        let todayCost: Double
        let todaySessions: Int
        let thisWeekCost: Double
        let thisWeekSessions: Int
        let thisMonthCost: Double
        let thisMonthSessions: Int
        let dailyAverageCost: Double
        let projectedMonthlyCost: Double

        var totalTokens: Int {
            totalInputTokens + totalOutputTokens + totalCacheReadTokens + totalCacheCreationTokens
        }

        var avgCostPerSession: Double {
            guard totalSessions > 0 else { return 0 }
            return totalCost / Double(totalSessions)
        }

        var avgTokensPerSession: Int {
            guard totalSessions > 0 else { return 0 }
            return totalTokens / totalSessions
        }

        var avgOutputTokensPerSecond: Double {
            guard totalDurationApiMs > 0 else { return 0 }
            return Double(totalOutputTokens) / (Double(totalDurationApiMs) / 1000.0)
        }

        var cacheHitRate: Double {
            let cacheTotal = totalCacheReadTokens + totalCacheCreationTokens
            guard totalInputTokens + cacheTotal > 0 else { return 0 }
            return Double(totalCacheReadTokens) / Double(totalInputTokens + cacheTotal)
        }

        var costPerThousandTokens: Double {
            guard totalTokens > 0 else { return 0 }
            return (totalCost / Double(totalTokens)) * 1000.0
        }

        var errorRate: Double {
            guard totalSessions > 0 else { return 0 }
            return Double(errorCount) / Double(totalSessions)
        }

        var formattedTotalCost: String { formatCost(totalCost) }
        var formattedTodayCost: String { formatCost(todayCost) }
        var formattedWeekCost: String { formatCost(thisWeekCost) }
        var formattedMonthCost: String { formatCost(thisMonthCost) }
        var formattedProjectedMonthly: String { formatCost(projectedMonthlyCost) }

        private func formatCost(_ cost: Double) -> String {
            if cost >= 1.0 { return String(format: "$%.2f", cost) }
            if cost > 0 { return String(format: "$%.4f", cost) }
            return "$0"
        }
    }

    @Published var economics: Economics?

    /// Compute economics for a specific project
    func compute(projectPath: String) {
        let context = AppModelContainer.shared.mainContext
        let path = projectPath
        let descriptor = FetchDescriptor<ConversationSession>(
            predicate: #Predicate { $0.projectPath == path }
        )

        guard let sessions = try? context.fetch(descriptor) else {
            economics = nil
            return
        }

        economics = aggregate(sessions)
    }

    /// Compute economics across all projects
    func computeGlobal() {
        let context = AppModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<ConversationSession>()

        guard let sessions = try? context.fetch(descriptor) else {
            economics = nil
            return
        }

        economics = aggregate(sessions)
    }

    /// Compute economics for sessions within a date range
    func compute(since date: Date) {
        let context = AppModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<ConversationSession>(
            predicate: #Predicate { $0.startedAt >= date }
        )

        guard let sessions = try? context.fetch(descriptor) else {
            economics = nil
            return
        }

        economics = aggregate(sessions)
    }

    private func aggregate(_ sessions: [ConversationSession]) -> Economics {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        let todaySessions = sessions.filter { $0.startedAt >= startOfToday }
        let weekSessions = sessions.filter { $0.startedAt >= startOfWeek }
        let monthSessions = sessions.filter { $0.startedAt >= startOfMonth }

        let todayCost = todaySessions.reduce(0.0) { $0 + $1.costUsd }
        let weekCost = weekSessions.reduce(0.0) { $0 + $1.costUsd }
        let monthCost = monthSessions.reduce(0.0) { $0 + $1.costUsd }

        let totalCost = sessions.reduce(0.0) { $0 + $1.costUsd }
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) }).count
        let dailyAvg = uniqueDays > 0 ? totalCost / Double(uniqueDays) : 0
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let projectedMonthly = dailyAvg * Double(daysInMonth)

        return Economics(
            totalSessions: sessions.count,
            totalCost: totalCost,
            totalInputTokens: sessions.reduce(0) { $0 + $1.inputTokens },
            totalOutputTokens: sessions.reduce(0) { $0 + $1.outputTokens },
            totalCacheReadTokens: sessions.reduce(0) { $0 + $1.cacheReadTokens },
            totalCacheCreationTokens: sessions.reduce(0) { $0 + $1.cacheCreationTokens },
            totalDurationMs: sessions.reduce(0) { $0 + $1.durationMs },
            totalDurationApiMs: sessions.reduce(0) { $0 + $1.durationApiMs },
            errorCount: sessions.filter(\.isError).count,
            todayCost: todayCost,
            todaySessions: todaySessions.count,
            thisWeekCost: weekCost,
            thisWeekSessions: weekSessions.count,
            thisMonthCost: monthCost,
            thisMonthSessions: monthSessions.count,
            dailyAverageCost: dailyAvg,
            projectedMonthlyCost: projectedMonthly
        )
    }
}
