import SwiftUI

struct ClaudeUsageCard: View {
    @StateObject private var planUsage = ClaudePlanUsageService.shared
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Plan Usage")
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

            // Current Session
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current Session \(percentStringSimple(planUsage.fiveHourUtilization))")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(countdownString(to: planUsage.fiveHourResetsAt))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                UsageBar(progress: planUsage.fiveHourUtilization)
                    .frame(height: 10)
            }

            // Weekly
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weekly \(percentStringSimple(planUsage.sevenDayUtilization))")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(countdownStringWithDays(to: planUsage.sevenDayResetsAt))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                UsageBar(progress: planUsage.sevenDayUtilization)
                    .frame(height: 10)
            }

            // Sonnet & Opus percentages side by side
            HStack {
                VStack(spacing: 4) {
                    Text("Sonnet")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(percentString(planUsage.sonnetUtilization))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 30)

                VStack(spacing: 4) {
                    Text("Opus")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(percentString(planUsage.opusUtilization))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
            }

            // Error or Last Updated
            HStack {
                if let error = planUsage.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    Text("Last updated: \(lastUpdatedLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
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
            now = Date()
        }
    }

    private func countdownString(to date: Date?) -> String {
        guard let date else { return "--:--:--" }
        let interval = max(0, date.timeIntervalSince(now))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func countdownStringWithDays(to date: Date?) -> String {
        guard let date else { return "-:--:--:--" }
        let interval = max(0, date.timeIntervalSince(now))
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d:%02d:%02d", days, hours, minutes, seconds)
    }

    private func percentString(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%.0f%%", value * 100)
    }

    private func percentStringSimple(_ value: Double) -> String {
        return String(format: "%.0f%%", value * 100)
    }

    private var lastUpdatedLabel: String {
        guard let lastUpdated = planUsage.lastUpdated else { return "--" }
        let interval = Int(now.timeIntervalSince(lastUpdated))
        if interval < 60 { return "just now" }
        let minutes = interval / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
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
            return .blue
        case 0.5..<0.75:
            return .yellow
        case 0.75..<0.9:
            return .orange
        default:
            return .red
        }
    }
}
