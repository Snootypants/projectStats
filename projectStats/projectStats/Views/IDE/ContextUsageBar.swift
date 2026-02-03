import SwiftUI

struct ContextUsageBar: View {
    @StateObject private var planUsage = ClaudePlanUsageService.shared
    @StateObject private var contextMonitor = ClaudeContextMonitor.shared
    @State private var refreshTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Plan: \(planPercentString)")
                    .font(.system(size: 11, weight: .semibold))
                UsageBar(progress: planUsage.fiveHourUtilization)
                    .frame(width: 120, height: 6)
                Text("(\(planUsage.fiveHourTimeRemaining))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 12)

            HStack(spacing: 8) {
                Text("Context: \(contextPercentString)")
                    .font(.system(size: 11, weight: .semibold))
                UsageBar(progress: contextPercent)
                    .frame(width: 120, height: 6)
                Text(contextTokensString)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
        .task {
            await planUsage.fetchUsage()
            await contextMonitor.refresh()
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await planUsage.fetchUsage()
            }
        }
    }

    private var planPercentString: String {
        String(format: "%.0f%%", planUsage.fiveHourUtilization * 100)
    }

    private var contextPercent: Double {
        contextMonitor.latestContextSummary?.percent ?? 0
    }

    private var contextPercentString: String {
        String(format: "%.0f%%", contextPercent * 100)
    }

    private var contextTokensString: String {
        guard let summary = contextMonitor.latestContextSummary else { return "--" }
        return "\(summary.totalTokens / 1000)k/\(summary.maxTokens / 1000)k"
    }
}

private struct UsageBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, min(proxy.size.width, proxy.size.width * progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(colorForProgress(progress))
                    .frame(width: width)
            }
        }
    }

    private func colorForProgress(_ value: Double) -> Color {
        switch value {
        case 0..<0.5:
            return .green
        case 0.5..<0.75:
            return .yellow
        case 0.75..<0.9:
            return .orange
        default:
            return .red
        }
    }
}
