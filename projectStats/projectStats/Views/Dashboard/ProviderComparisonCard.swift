import SwiftUI

/// Dashboard card showing AI provider comparison metrics
struct ProviderComparisonCard: View {
    @StateObject private var metricsService = ProviderMetricsService.shared
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("AI Providers", systemImage: "cpu")
                    .font(.headline)

                Spacer()

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Summary stats
            if !metricsService.providerMetrics.isEmpty {
                HStack(spacing: 16) {
                    StatPill(
                        label: "Sessions",
                        value: "\(totalSessions)",
                        icon: "terminal"
                    )

                    StatPill(
                        label: "Tokens",
                        value: formatTokens(totalTokens),
                        icon: "text.word.spacing"
                    )

                    StatPill(
                        label: "Cost",
                        value: formatCost(totalCost),
                        icon: "dollarsign.circle"
                    )
                }

                // Provider breakdown
                if isExpanded {
                    Divider()

                    ForEach(sortedProviders, id: \.providerType) { metrics in
                        ProviderMetricsRow(metrics: metrics)
                    }
                }
            } else {
                Text("No AI session data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
        .task {
            metricsService.calculateAllMetrics(context: AppModelContainer.shared.mainContext)
        }
    }

    private var totalSessions: Int {
        metricsService.providerMetrics.values.reduce(0) { $0 + $1.totalSessions }
    }

    private var totalTokens: Int {
        metricsService.providerMetrics.values.reduce(0) { $0 + $1.totalTokens }
    }

    private var totalCost: Double {
        metricsService.providerMetrics.values.reduce(0) { $0 + $1.totalCost }
    }

    private var sortedProviders: [ProviderMetrics] {
        metricsService.providerMetrics.values
            .sorted { $0.totalSessions > $1.totalSessions }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return "\(String(format: "%.1f", Double(count) / 1_000_000))M"
        } else if count >= 1_000 {
            return "\(String(format: "%.1f", Double(count) / 1_000))K"
        }
        return "\(count)"
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return "<$0.01"
        }
        return "$\(String(format: "%.2f", cost))"
    }
}

/// Row showing metrics for a single provider
struct ProviderMetricsRow: View {
    let metrics: ProviderMetrics

    var body: some View {
        HStack {
            // Provider icon and name
            HStack(spacing: 8) {
                Image(systemName: metrics.providerType.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(metrics.providerType.displayName)
                    .font(.subheadline)
            }

            Spacer()

            // Stats
            HStack(spacing: 12) {
                Text("\(metrics.totalSessions) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatTokens(metrics.totalTokens))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(metrics.formattedCost)
                    .font(.caption.bold())
                    .foregroundStyle(metrics.totalCost > 0 ? .orange : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return "\(String(format: "%.1f", Double(count) / 1_000_000))M"
        } else if count >= 1_000 {
            return "\(String(format: "%.1f", Double(count) / 1_000))K"
        }
        return "\(count)"
    }
}

/// Compact stat display pill
struct StatPill: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Compact provider comparison view for toolbar/menubar
struct CompactProviderStats: View {
    @StateObject private var metricsService = ProviderMetricsService.shared

    var body: some View {
        HStack(spacing: 12) {
            if let bestSpeed = metricsService.bestProvider(by: .speed),
               let metrics = metricsService.providerMetrics[bestSpeed] {
                HStack(spacing: 4) {
                    Image(systemName: "bolt")
                        .font(.system(size: 10))
                    Text(bestSpeed.displayName)
                        .font(.system(size: 10))
                    Text(metrics.formattedDuration)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            if let cheapest = metricsService.bestProvider(by: .cost),
               let metrics = metricsService.providerMetrics[cheapest] {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 10))
                    Text(cheapest.displayName)
                        .font(.system(size: 10))
                    Text(metrics.formattedCost)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ProviderComparisonCard()
        .frame(width: 400)
        .padding()
}
