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

        var formattedTotalCost: String {
            if totalCost >= 1.0 {
                return String(format: "$%.2f", totalCost)
            }
            return String(format: "$%.4f", totalCost)
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
        Economics(
            totalSessions: sessions.count,
            totalCost: sessions.reduce(0) { $0 + $1.costUsd },
            totalInputTokens: sessions.reduce(0) { $0 + $1.inputTokens },
            totalOutputTokens: sessions.reduce(0) { $0 + $1.outputTokens },
            totalCacheReadTokens: sessions.reduce(0) { $0 + $1.cacheReadTokens },
            totalCacheCreationTokens: sessions.reduce(0) { $0 + $1.cacheCreationTokens },
            totalDurationMs: sessions.reduce(0) { $0 + $1.durationMs },
            totalDurationApiMs: sessions.reduce(0) { $0 + $1.durationApiMs },
            errorCount: sessions.filter(\.isError).count
        )
    }
}
