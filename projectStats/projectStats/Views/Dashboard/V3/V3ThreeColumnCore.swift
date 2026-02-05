import SwiftUI
import Charts

/// V3 Three Column Core - Left: Time/Usage, Center: Activity Graph, Right: Notifications/Achievements
struct V3ThreeColumnCore: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @StateObject private var achievementService = AchievementService.shared
    @StateObject private var planUsage = ClaudePlanUsageService.shared
    @ObservedObject var timeService = TimeTrackingService.shared
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // LEFT COLUMN - Time & Usage
            leftColumn
                .frame(width: 180)

            // CENTER COLUMN - Activity Graph (the visual centerpiece)
            centerColumn
                .frame(maxWidth: .infinity)

            // RIGHT COLUMN - Notifications & Achievements
            rightColumn
                .frame(width: 200)
        }
        .onReceive(refreshTimer) { _ in
            now = Date()
        }
    }

    // MARK: - Left Column

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Big clock
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(todayTimeFormatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Session usage
            VStack(alignment: .leading, spacing: 8) {
                Text("Session: \(Int(planUsage.fiveHourUtilization * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                usageBar(value: planUsage.fiveHourUtilization)
            }

            // Weekly usage
            VStack(alignment: .leading, spacing: 8) {
                Text("Weekly: \(Int(planUsage.sevenDayUtilization * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                usageBar(value: planUsage.sevenDayUtilization)
            }
        }
    }

    private func usageBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: max(0, geo.size.width * min(value, 1)))
            }
        }
        .frame(height: 8)
    }

    private var todayTimeFormatted: String {
        let humanCurrent = timeService.humanSessionStart.map { now.timeIntervalSince($0) } ?? 0
        let aiCurrent = timeService.aiSessionStart.map { now.timeIntervalSince($0) } ?? 0
        let total = timeService.todayHumanTotal + timeService.todayAITotal + humanCurrent + aiCurrent
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }

    // MARK: - Center Column

    private var centerColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            // Chart
            activityChart
                .frame(height: 200)
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(accentColor).frame(width: 8, height: 8)
                    Text("Lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var activityChart: some View {
        Chart(chartData) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Lines", point.lines)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            AreaMark(
                x: .value("Date", point.date),
                y: .value("Lines", point.lines)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .shadow(color: accentColor.opacity(0.4), radius: 6)
    }

    private var chartData: [V3ChartDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().compactMap { daysAgo -> V3ChartDataPoint? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            // activities is [Date: ActivityStats], find by date key
            let activity = viewModel.activities[date]
            return V3ChartDataPoint(
                date: date,
                lines: activity?.linesAdded ?? 0,
                commits: activity?.commits ?? 0
            )
        }
    }

    // MARK: - Right Column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Notifications placeholder
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                if let todayActivity = viewModel.activities[Calendar.current.startOfDay(for: Date())] {
                    notificationRow(icon: "arrow.triangle.branch", text: "\(todayActivity.commits) commits today", color: .blue)
                }

                if planUsage.fiveHourUtilization > 0.5 {
                    notificationRow(icon: "exclamationmark.triangle", text: "\(Int(planUsage.fiveHourUtilization * 100))% session used", color: .yellow)
                }

                if let recent = achievementService.mostRecentAchievement {
                    notificationRow(icon: recent.icon, text: recent.title, color: .purple)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Achievements progress
            VStack(alignment: .leading, spacing: 8) {
                Text("Achievements")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack {
                    Text("\(achievementService.unlockedAchievements.count)/\(Achievement.allCases.count)")
                        .font(.headline)
                    Spacer()
                    achievementBar
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // GitHub placeholder
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                if let lastActivity = viewModel.activities.values.sorted(by: { $0.date > $1.date }).first {
                    Text("Last push: \(lastActivity.date.timeAgoString)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No recent activity")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func notificationRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
    }

    private var achievementBar: some View {
        GeometryReader { geo in
            let progress = Double(achievementService.unlockedAchievements.count) / Double(max(Achievement.allCases.count, 1))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.purple)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Chart Data Point

private struct V3ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let lines: Int
    let commits: Int
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

// MARK: - Date Extension

private extension Date {
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    V3ThreeColumnCore()
        .environmentObject(DashboardViewModel.shared)
}
