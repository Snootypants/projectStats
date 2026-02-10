import SwiftUI

/// Scope E: Token economics dashboard card for V5 home page
struct V5TokenEconomicsCard: View {
    @StateObject private var service = TokenEconomicsService.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text("TOKEN ECONOMICS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let econ = service.economics {
                // Big number — total tokens
                Text(formatTokenCount(econ.totalTokens))
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("total tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    statCell(label: "Sessions", value: "\(econ.totalSessions)")
                    statCell(label: "Total Cost", value: econ.formattedTotalCost)
                    statCell(label: "Avg/Session", value: String(format: "$%.4f", econ.avgCostPerSession))
                    statCell(label: "$/1K Tokens", value: String(format: "$%.4f", econ.costPerThousandTokens))
                }

                Divider()

                // Token breakdown bars
                VStack(alignment: .leading, spacing: 6) {
                    tokenBar(label: "Input", count: econ.totalInputTokens, total: econ.totalTokens, color: .blue)
                    tokenBar(label: "Output", count: econ.totalOutputTokens, total: econ.totalTokens, color: .green)
                    tokenBar(label: "Cache Read", count: econ.totalCacheReadTokens, total: econ.totalTokens, color: .cyan)
                    tokenBar(label: "Cache Write", count: econ.totalCacheCreationTokens, total: econ.totalTokens, color: .orange)
                }

                Divider()

                // Performance metrics
                HStack(spacing: 16) {
                    miniStat(label: "Cache Hit", value: String(format: "%.0f%%", econ.cacheHitRate * 100))
                    miniStat(label: "tok/s", value: String(format: "%.0f", econ.avgOutputTokensPerSecond))
                    if econ.errorCount > 0 {
                        miniStat(label: "Errors", value: "\(econ.errorCount)")
                    }
                }
            } else {
                Text("No session data yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            service.computeGlobal()
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .rounded).bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func tokenBar(label: String, count: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTokenCount(count))
                    .font(.caption2.bold())
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: max(4, geo.size.width * (total > 0 ? CGFloat(count) / CGFloat(total) : 0)))
            }
            .frame(height: 4)
        }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    V5TokenEconomicsCard()
        .frame(width: 300)
        .padding()
}
