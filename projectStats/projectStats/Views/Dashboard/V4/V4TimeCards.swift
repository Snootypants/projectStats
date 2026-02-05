import SwiftUI

/// V4 Time Cards - Stacked time period cards showing time and cost
struct V4TimeCards: View {
    @ObservedObject var timeService = TimeTrackingService.shared
    @StateObject private var usageService = ClaudeUsageService.shared
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    var body: some View {
        HStack(spacing: 16) {
            TimeCard(
                title: "Today",
                time: todayTime,
                cost: usageService.globalTodayStats?.totalCost ?? 0
            )

            TimeCard(
                title: "This Week",
                time: weekTime,
                cost: usageService.globalWeekStats.reduce(0) { $0 + $1.totalCost }
            )

            TimeCard(
                title: "This Month",
                time: monthTime,
                cost: nil // No month data available easily
            )

            TimeCard(
                title: "All Time",
                time: allTimeFormatted,
                cost: nil
            )
        }
        .onReceive(refreshTimer) { _ in
            now = Date()
        }
    }

    private var todayTime: String {
        let humanCurrent = timeService.humanSessionStart.map { now.timeIntervalSince($0) } ?? 0
        let aiCurrent = timeService.aiSessionStart.map { now.timeIntervalSince($0) } ?? 0
        let total = timeService.todayHumanTotal + timeService.todayAITotal + humanCurrent + aiCurrent
        return formatDuration(total)
    }

    private var weekTime: String {
        // Sum up the week from activities
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var total: TimeInterval = 0

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                // Approximate 1 hour per 100 lines as a rough estimate
                let lines = viewModel.activities[date]?.linesAdded ?? 0
                total += Double(lines) / 100 * 3600
            }
        }

        // Add current session if it's today
        let humanCurrent = timeService.humanSessionStart.map { now.timeIntervalSince($0) } ?? 0
        let aiCurrent = timeService.aiSessionStart.map { now.timeIntervalSince($0) } ?? 0
        total += humanCurrent + aiCurrent + timeService.todayHumanTotal + timeService.todayAITotal

        return formatDurationWithHours(total)
    }

    private var monthTime: String {
        // Rough estimate from activity data
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var totalLines = 0

        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                totalLines += viewModel.activities[date]?.linesAdded ?? 0
            }
        }

        // Rough estimate: 100 lines per hour
        let hours = Double(totalLines) / 100
        return formatDurationWithHours(hours * 3600)
    }

    private var allTimeFormatted: String {
        let totalLines = viewModel.activities.values.reduce(0) { $0 + $1.linesAdded }
        let hours = Double(totalLines) / 100 // Rough estimate
        return formatDurationWithHours(hours * 3600)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func formatDurationWithHours(_ duration: TimeInterval) -> String {
        let totalHours = Int(duration) / 3600
        if totalHours >= 24 {
            let days = totalHours / 24
            let hours = totalHours % 24
            return "\(days)d \(hours)h"
        }
        let minutes = (Int(duration) % 3600) / 60
        return "\(totalHours)h \(minutes)m"
    }
}

// MARK: - Time Card

private struct TimeCard: View {
    let title: String
    let time: String
    let cost: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(time)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            if let cost = cost {
                Text(String(format: "$%.2f", cost))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    V4TimeCards()
        .environmentObject(DashboardViewModel.shared)
        .padding()
}
