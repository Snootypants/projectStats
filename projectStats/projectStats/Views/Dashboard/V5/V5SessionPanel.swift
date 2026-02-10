import SwiftUI

/// V5 Session Panel - Big timer with You vs Claude split
struct V5SessionPanel: View {
    @ObservedObject var timeService = TimeTrackingService.shared
    @AppStorage(AppStorageKeys.accentColorHex) private var accentColorHex: String = "#FF9500"
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(accentColor)
                Text("ACTIVE SESSION")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Big timer
            Text(totalTimeFormatted)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()

            // You vs Claude bars
            VStack(spacing: 8) {
                meterRow(label: "You", value: humanProgress, time: humanTimeFormatted, color: .green)
                meterRow(label: "Claude", value: aiProgress, time: aiTimeFormatted, color: .pink)
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onReceive(refreshTimer) { _ in
            now = Date()
        }
    }

    private func meterRow(label: String, value: Double, time: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                Spacer()
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * value))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Time Calculations

    private var totalTime: TimeInterval {
        let humanCurrent = timeService.humanSessionStart.map { now.timeIntervalSince($0) } ?? 0
        let aiCurrent = timeService.aiSessionStart.map { now.timeIntervalSince($0) } ?? 0
        return timeService.todayHumanTotal + timeService.todayAITotal + humanCurrent + aiCurrent
    }

    private var humanTime: TimeInterval {
        let current = timeService.humanSessionStart.map { now.timeIntervalSince($0) } ?? 0
        return timeService.todayHumanTotal + current
    }

    private var aiTime: TimeInterval {
        let current = timeService.aiSessionStart.map { now.timeIntervalSince($0) } ?? 0
        return timeService.todayAITotal + current
    }

    private var humanProgress: Double {
        guard totalTime > 0 else { return 0.5 }
        return humanTime / totalTime
    }

    private var aiProgress: Double {
        guard totalTime > 0 else { return 0.5 }
        return aiTime / totalTime
    }

    private var totalTimeFormatted: String {
        formatDuration(totalTime)
    }

    private var humanTimeFormatted: String {
        formatDuration(humanTime)
    }

    private var aiTimeFormatted: String {
        formatDuration(aiTime)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
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
    V5SessionPanel()
        .frame(width: 300)
        .padding()
}
