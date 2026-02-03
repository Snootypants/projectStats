import SwiftUI

struct ClaudeUsageCard: View {
    @StateObject private var planUsage = ClaudePlanUsageService.shared
    @State private var refreshTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Plan Usage Limits")
                    .font(.headline)
                Spacer()
                Button {
                    Task {
                        await planUsage.fetchUsage()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if planUsage.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Current Session")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                UsageRow(
                    label: "",
                    progress: planUsage.fiveHourUtilization,
                    percentLabel: percentString(planUsage.fiveHourUtilization),
                    detail: "Resets in \(planUsage.fiveHourTimeRemaining)"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly Limits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                UsageRow(
                    label: "All models",
                    progress: planUsage.sevenDayUtilization,
                    percentLabel: percentString(planUsage.sevenDayUtilization),
                    detail: resetLabel(planUsage.sevenDayResetsAt)
                )

                UsageRow(
                    label: "Sonnet only",
                    progress: planUsage.sonnetUtilization ?? 0,
                    percentLabel: percentString(planUsage.sonnetUtilization ?? 0),
                    detail: resetLabel(planUsage.sonnetResetsAt)
                )
            }

            HStack {
                Text("Last updated: \(lastUpdatedLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let error = planUsage.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .task {
            await planUsage.fetchUsage()
        }
        .onReceive(refreshTimer) { _ in
            Task { await planUsage.fetchUsage() }
        }
    }

    private func percentString(_ value: Double) -> String {
        String(format: "%.0f%% used", value * 100)
    }

    private func resetLabel(_ date: Date?) -> String {
        guard let date else { return "Resets --" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return "Resets \(formatter.string(from: date))"
    }

    private var lastUpdatedLabel: String {
        guard let lastUpdated = planUsage.lastUpdated else { return "--" }
        let interval = Int(Date().timeIntervalSince(lastUpdated))
        if interval < 60 { return "just now" }
        let minutes = interval / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }
}

private struct UsageRow: View {
    let label: String
    let progress: Double
    let percentLabel: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }

            HStack(spacing: 12) {
                UsageBar(progress: progress)
                    .frame(height: 8)
                Text(percentLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
