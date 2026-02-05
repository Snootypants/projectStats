import SwiftUI

/// V3 Hero Strip - Today's total time as hero number, with You/Claude split and API spend
struct V3HeroStrip: View {
    @ObservedObject var timeService = TimeTrackingService.shared
    @StateObject private var usageService = ClaudeUsageService.shared
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 8) {
            Text("TODAY: \(totalTimeFormatted)")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("You: \(humanTimeFormatted)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("•")
                    .foregroundStyle(.tertiary)

                HStack(spacing: 6) {
                    Circle().fill(.pink).frame(width: 8, height: 8)
                    Text("Claude: \(aiTimeFormatted)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("•")
                    .foregroundStyle(.tertiary)

                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.yellow)
                    Text("$\(String(format: "%.2f", usageService.globalTodayStats?.totalCost ?? 0)) today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.02))
        .onReceive(refreshTimer) { _ in
            now = Date()
        }
    }

    // MARK: - Time Formatting

    private var totalTimeFormatted: String {
        let humanCurrent = timeService.humanSessionStart.map { now.timeIntervalSince($0) } ?? 0
        let aiCurrent = timeService.aiSessionStart.map { now.timeIntervalSince($0) } ?? 0
        let total = timeService.todayHumanTotal + timeService.todayAITotal + humanCurrent + aiCurrent
        return formatDuration(total)
    }

    private var humanTimeFormatted: String {
        let current = timeService.humanSessionStart.map { now.timeIntervalSince($0) } ?? 0
        return formatDuration(timeService.todayHumanTotal + current)
    }

    private var aiTimeFormatted: String {
        let current = timeService.aiSessionStart.map { now.timeIntervalSince($0) } ?? 0
        return formatDuration(timeService.todayAITotal + current)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

#Preview {
    V3HeroStrip()
}
