import SwiftUI

/// V2 Galaxy Layout - Time at center with session/weekly bars flanking
/// The visual metaphor: Time is the "sun" at gravitational center,
/// usage limits orbit around it like satellites
struct V2GalaxyLayout: View {
    @ObservedObject var timeService = TimeTrackingService.shared
    @StateObject private var planUsage = ClaudePlanUsageService.shared
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            // LEFT — Current Session (left-justified, centered vertically)
            sessionColumn
                .frame(maxWidth: .infinity)

            // CENTER — Time (the sun — centered both horizontally and vertically)
            timeColumn
                .frame(maxWidth: .infinity)

            // RIGHT — Weekly (right-justified, centered vertically)
            weeklyColumn
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await planUsage.fetchUsage()
        }
        .onReceive(refreshTimer) { _ in
            now = Date()
        }
    }

    // MARK: - Left Column (Session)

    private var sessionColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current Session \(percentString(planUsage.fiveHourUtilization))")
                .font(.subheadline.weight(.semibold))

            V2ProgressBar(value: planUsage.fiveHourUtilization, accentColor: accentColor)
                .frame(height: 8)

            HStack {
                Text("Resets: \(resetTimeLabel(planUsage.fiveHourResetsAt))")
                Spacer()
                Text("⏱ \(countdownString(to: planUsage.fiveHourResetsAt))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Center Column (Time - The Sun)

    private var timeColumn: some View {
        VStack(spacing: 4) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(totalTimeFormatted)
                .font(.system(size: 48, weight: .bold, design: .rounded))

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("You: \(timeService.todayHumanFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Circle().fill(.pink).frame(width: 6, height: 6)
                    Text("Claude: \(timeService.todayAIFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Right Column (Weekly)

    private var weeklyColumn: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("Weekly \(percentString(planUsage.sevenDayUtilization))")
                .font(.subheadline.weight(.semibold))

            V2ProgressBar(value: planUsage.sevenDayUtilization, accentColor: accentColor)
                .frame(height: 8)

            HStack {
                Text("Resets: \(weeklyResetDayLabel(planUsage.sevenDayResetsAt))")
                Spacer()
                Text("⏱ \(countdownStringWithDays(to: planUsage.sevenDayResetsAt))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var totalTimeFormatted: String {
        let total = timeService.todayHumanTotal + timeService.todayAITotal
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

    private func percentString(_ value: Double) -> String {
        return String(format: "%.0f%%", value * 100)
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
        guard let date else { return "-d --:--" }
        let interval = max(0, date.timeIntervalSince(now))
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: "%dd %02d:%02d", days, hours, minutes)
    }

    private func resetTimeLabel(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }

    private func weeklyResetDayLabel(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mma"
        return formatter.string(from: date)
    }
}

// MARK: - V2 Progress Bar

struct V2ProgressBar: View {
    let value: Double
    let accentColor: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, min(proxy.size.width, proxy.size.width * value))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))

                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: width)
            }
        }
    }
}

// MARK: - Color Hex Extension

private extension Color {
    static func fromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255

        return Color(red: r, green: g, blue: b)
    }
}

#Preview {
    V2GalaxyLayout()
        .frame(width: 800)
        .padding()
}
