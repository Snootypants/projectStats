import Foundation
import SwiftData

/// Service for calculating and comparing AI provider metrics
@MainActor
final class ProviderMetricsService: ObservableObject {
    static let shared = ProviderMetricsService()

    @Published var providerMetrics: [AIProviderType: ProviderMetrics] = [:]
    @Published var lastUpdated: Date?

    private init() {}

    // MARK: - Metrics Calculation

    /// Calculate metrics for all providers
    func calculateAllMetrics(context: ModelContext) {
        var metrics: [AIProviderType: ProviderMetrics] = [:]

        for providerType in AIProviderType.allCases {
            if let providerMetrics = calculateMetrics(for: providerType, context: context) {
                metrics[providerType] = providerMetrics
            }
        }

        self.providerMetrics = metrics
        self.lastUpdated = Date()
    }

    /// Calculate metrics for a specific provider
    func calculateMetrics(for providerType: AIProviderType, context: ModelContext) -> ProviderMetrics? {
        let typeString = providerType.rawValue

        // Fetch sessions for this provider
        let descriptor = FetchDescriptor<AISessionV2>(
            predicate: #Predicate<AISessionV2> { session in
                session.providerType == typeString && session.endTime != nil
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor), !sessions.isEmpty else {
            return nil
        }

        // Calculate metrics
        let totalSessions = sessions.count
        let successfulSessions = sessions.filter { $0.wasSuccessful }.count
        let totalInputTokens = sessions.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = sessions.reduce(0) { $0 + $1.outputTokens }
        let totalThinkingTokens = sessions.reduce(0) { $0 + $1.thinkingTokens }
        let totalCost = sessions.reduce(0.0) { $0 + $1.costUSD }
        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }

        let avgDuration = totalSessions > 0 ? totalDuration / Double(totalSessions) : 0
        let successRate = totalSessions > 0 ? Double(successfulSessions) / Double(totalSessions) : 0

        return ProviderMetrics(
            providerType: providerType,
            totalSessions: totalSessions,
            successfulSessions: successfulSessions,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalThinkingTokens: totalThinkingTokens,
            totalCost: totalCost,
            totalDuration: totalDuration,
            averageDuration: avgDuration,
            successRate: successRate
        )
    }

    /// Get metrics for a time period
    func calculateMetrics(for providerType: AIProviderType, since date: Date, context: ModelContext) -> ProviderMetrics? {
        let typeString = providerType.rawValue

        let descriptor = FetchDescriptor<AISessionV2>(
            predicate: #Predicate<AISessionV2> { session in
                session.providerType == typeString && session.endTime != nil && session.startTime >= date
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor), !sessions.isEmpty else {
            return nil
        }

        let totalSessions = sessions.count
        let successfulSessions = sessions.filter { $0.wasSuccessful }.count
        let totalInputTokens = sessions.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = sessions.reduce(0) { $0 + $1.outputTokens }
        let totalThinkingTokens = sessions.reduce(0) { $0 + $1.thinkingTokens }
        let totalCost = sessions.reduce(0.0) { $0 + $1.costUSD }
        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }

        let avgDuration = totalSessions > 0 ? totalDuration / Double(totalSessions) : 0
        let successRate = totalSessions > 0 ? Double(successfulSessions) / Double(totalSessions) : 0

        return ProviderMetrics(
            providerType: providerType,
            totalSessions: totalSessions,
            successfulSessions: successfulSessions,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalThinkingTokens: totalThinkingTokens,
            totalCost: totalCost,
            totalDuration: totalDuration,
            averageDuration: avgDuration,
            successRate: successRate
        )
    }

    // MARK: - Comparisons

    /// Compare two providers
    func compare(_ provider1: AIProviderType, _ provider2: AIProviderType) -> ProviderComparison? {
        guard let metrics1 = providerMetrics[provider1],
              let metrics2 = providerMetrics[provider2] else {
            return nil
        }

        let fasterProvider = metrics1.averageDuration < metrics2.averageDuration ? provider1 : provider2
        let cheaperProvider = metrics1.costPerToken < metrics2.costPerToken ? provider1 : provider2
        let moreReliable = metrics1.successRate > metrics2.successRate ? provider1 : provider2

        let costDifference = abs(metrics1.totalCost - metrics2.totalCost)
        let durationDifference = abs(metrics1.averageDuration - metrics2.averageDuration)

        return ProviderComparison(
            provider1: provider1,
            provider2: provider2,
            fasterProvider: fasterProvider,
            cheaperProvider: cheaperProvider,
            moreReliableProvider: moreReliable,
            costDifference: costDifference,
            durationDifference: durationDifference
        )
    }

    /// Get the best provider by a specific metric
    func bestProvider(by metric: ComparisonMetric) -> AIProviderType? {
        switch metric {
        case .speed:
            return providerMetrics.min(by: { $0.value.averageDuration < $1.value.averageDuration })?.key
        case .cost:
            return providerMetrics.min(by: { $0.value.costPerToken < $1.value.costPerToken })?.key
        case .reliability:
            return providerMetrics.max(by: { $0.value.successRate < $1.value.successRate })?.key
        case .tokenEfficiency:
            return providerMetrics.min(by: { $0.value.tokensPerSession < $1.value.tokensPerSession })?.key
        }
    }

    // MARK: - Model-Level Metrics

    /// Calculate metrics for a specific model
    func calculateModelMetrics(for model: AIModel, context: ModelContext) -> ModelMetrics? {
        let modelString = model.rawValue

        let descriptor = FetchDescriptor<AISessionV2>(
            predicate: #Predicate<AISessionV2> { session in
                session.modelRaw == modelString && session.endTime != nil
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor), !sessions.isEmpty else {
            return nil
        }

        let totalSessions = sessions.count
        let totalTokens = sessions.reduce(0) { $0 + $1.totalTokens }
        let totalCost = sessions.reduce(0.0) { $0 + $1.costUSD }
        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }

        return ModelMetrics(
            model: model,
            totalSessions: totalSessions,
            totalTokens: totalTokens,
            totalCost: totalCost,
            averageDuration: totalSessions > 0 ? totalDuration / Double(totalSessions) : 0,
            averageCostPerSession: totalSessions > 0 ? totalCost / Double(totalSessions) : 0
        )
    }
}

// MARK: - Data Models

/// Aggregated metrics for a provider
struct ProviderMetrics {
    let providerType: AIProviderType
    let totalSessions: Int
    let successfulSessions: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalThinkingTokens: Int
    let totalCost: Double
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    let successRate: Double

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalThinkingTokens
    }

    var costPerToken: Double {
        guard totalTokens > 0 else { return 0 }
        return totalCost / Double(totalTokens)
    }

    var tokensPerSession: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(totalTokens) / Double(totalSessions)
    }

    var formattedCost: String {
        if totalCost < 0.01 {
            return "<$0.01"
        }
        return "$\(String(format: "%.2f", totalCost))"
    }

    var formattedDuration: String {
        let minutes = Int(averageDuration) / 60
        let seconds = Int(averageDuration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

/// Comparison between two providers
struct ProviderComparison {
    let provider1: AIProviderType
    let provider2: AIProviderType
    let fasterProvider: AIProviderType
    let cheaperProvider: AIProviderType
    let moreReliableProvider: AIProviderType
    let costDifference: Double
    let durationDifference: TimeInterval
}

/// Metrics comparison criteria
enum ComparisonMetric {
    case speed
    case cost
    case reliability
    case tokenEfficiency
}

/// Metrics for a specific model
struct ModelMetrics {
    let model: AIModel
    let totalSessions: Int
    let totalTokens: Int
    let totalCost: Double
    let averageDuration: TimeInterval
    let averageCostPerSession: Double

    var formattedCost: String {
        if totalCost < 0.01 {
            return "<$0.01"
        }
        return "$\(String(format: "%.2f", totalCost))"
    }
}
