import SwiftUI

struct TimeTrackingCard: View {
    @ObservedObject var timeService = TimeTrackingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Time Tracking")
                    .font(.headline)
                Spacer()
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Total time (big number)
            Text(totalTimeFormatted)
                .font(.system(size: 32, weight: .medium, design: .rounded))

            // Breakdown
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("You: \(timeService.todayHumanFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Circle().fill(.purple).frame(width: 8, height: 8)
                    Text("Claude: \(timeService.todayAIFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Status
            if timeService.isPaused {
                Text("Paused (idle)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let project = timeService.currentProject {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Tracking: \(URL(fileURLWithPath: project).lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Not tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
    }

    private var totalTimeFormatted: String {
        let total = timeService.todayHumanTotal + timeService.todayAITotal
        // Add current session if active
        if let start = timeService.humanSessionStart {
            let current = Date().timeIntervalSince(start)
            return formatDuration(total + current)
        }
        return formatDuration(total)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

#Preview {
    TimeTrackingCard()
}
