import Foundation
import SwiftData

/// Scope C: Estimates session duration and cost using historical percentiles
@MainActor
final class SessionEstimator {
    static let shared = SessionEstimator()
    private init() {}

    struct Estimate {
        let medianDurationMs: Int
        let p75DurationMs: Int
        let medianCost: Double
        let p75Cost: Double
        let medianTokens: Int
        let sampleSize: Int
        let isGlobal: Bool

        var formattedMedianDuration: String {
            formatDuration(medianDurationMs)
        }

        var formattedP75Duration: String {
            formatDuration(p75DurationMs)
        }

        var formattedMedianCost: String {
            if medianCost >= 1.0 {
                return String(format: "$%.2f", medianCost)
            }
            return String(format: "$%.4f", medianCost)
        }

        private func formatDuration(_ ms: Int) -> String {
            let seconds = ms / 1000
            if seconds >= 60 {
                return "\(seconds / 60)m \(seconds % 60)s"
            }
            return "\(seconds)s"
        }
    }

    /// Get estimate for a project based on its history, falls back to global
    func estimate(projectPath: String) -> Estimate? {
        let context = AppModelContainer.shared.mainContext
        let path = projectPath
        var descriptor = FetchDescriptor<ConversationSession>(
            predicate: #Predicate { $0.projectPath == path },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        if let sessions = try? context.fetch(descriptor), sessions.count >= 3 {
            return buildEstimate(from: sessions, isGlobal: false)
        }

        // Fallback to global estimate for new/low-history projects
        return globalEstimate()
    }

    /// Get estimate across all projects (global baseline)
    func globalEstimate() -> Estimate? {
        let context = AppModelContainer.shared.mainContext
        var descriptor = FetchDescriptor<ConversationSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100

        guard let sessions = try? context.fetch(descriptor),
              sessions.count >= 3 else { return nil }

        return buildEstimate(from: sessions, isGlobal: true)
    }

    private func buildEstimate(from sessions: [ConversationSession], isGlobal: Bool) -> Estimate {
        let durations = sessions.map(\.durationMs).sorted()
        let costs = sessions.map(\.costUsd).sorted()
        let tokens = sessions.map(\.totalTokens).sorted()

        return Estimate(
            medianDurationMs: percentile(durations, p: 0.5),
            p75DurationMs: percentile(durations, p: 0.75),
            medianCost: percentileDouble(costs, p: 0.5),
            p75Cost: percentileDouble(costs, p: 0.75),
            medianTokens: percentile(tokens, p: 0.5),
            sampleSize: sessions.count,
            isGlobal: isGlobal
        )
    }

    private func percentile(_ sorted: [Int], p: Double) -> Int {
        guard !sorted.isEmpty else { return 0 }
        let idx = Int(Double(sorted.count - 1) * p)
        return sorted[idx]
    }

    private func percentileDouble(_ sorted: [Double], p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let idx = Int(Double(sorted.count - 1) * p)
        return sorted[idx]
    }
}
