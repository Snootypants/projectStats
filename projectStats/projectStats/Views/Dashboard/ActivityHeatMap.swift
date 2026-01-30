import SwiftUI

struct ActivityHeatMap: View {
    let activities: [Date: ActivityStats]
    var weeks: Int = 26

    @State private var hoveredDate: Date?
    @State private var hoveredActivity: ActivityStats?

    private let calendar = Calendar.current
    private let daySize: CGFloat = 12
    private let spacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Month labels
            HStack(spacing: 0) {
                ForEach(monthLabels(), id: \.0) { offset, label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: (daySize + spacing) * 4, alignment: .leading)
                }
                Spacer()
            }
            .padding(.leading, 30)

            HStack(alignment: .top, spacing: 0) {
                // Day labels
                VStack(alignment: .trailing, spacing: spacing) {
                    Text("")
                        .frame(height: daySize)
                    Text("Mon")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(height: daySize)
                    Text("")
                        .frame(height: daySize)
                    Text("Wed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(height: daySize)
                    Text("")
                        .frame(height: daySize)
                    Text("Fri")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(height: daySize)
                    Text("")
                        .frame(height: daySize)
                }
                .frame(width: 28)

                // Heat map grid
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<weeks, id: \.self) { week in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { day in
                                let date = dateFor(week: week, day: day)
                                let activity = activities[date]
                                let count = activity?.commits ?? 0

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorFor(count: count))
                                    .frame(width: daySize, height: daySize)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .strokeBorder(
                                                hoveredDate == date ? Color.primary.opacity(0.5) : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                                    .onHover { isHovering in
                                        if isHovering {
                                            hoveredDate = date
                                            hoveredActivity = activity
                                        } else if hoveredDate == date {
                                            hoveredDate = nil
                                            hoveredActivity = nil
                                        }
                                    }
                                    .help(tooltipFor(date: date, activity: activity))
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach([0, 1, 3, 5, 8], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorFor(count: level))
                        .frame(width: 10, height: 10)
                }

                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func colorFor(count: Int) -> Color {
        switch count {
        case 0:
            return Color.primary.opacity(0.05)
        case 1...2:
            return Color.green.opacity(0.3)
        case 3...5:
            return Color.green.opacity(0.5)
        case 6...8:
            return Color.green.opacity(0.7)
        default:
            return Color.green.opacity(0.9)
        }
    }

    private func dateFor(week: Int, day: Int) -> Date {
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        let daysFromSunday = todayWeekday - 1

        // Calculate the date
        let weeksAgo = weeks - 1 - week
        let totalDaysAgo = weeksAgo * 7 + (6 - day) + (6 - daysFromSunday)

        return calendar.date(byAdding: .day, value: -totalDaysAgo, to: today)?.startOfDay ?? today
    }

    private func tooltipFor(date: Date, activity: ActivityStats?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let dateStr = dateFormatter.string(from: date)
        let commits = activity?.commits ?? 0
        let lines = (activity?.linesAdded ?? 0) + (activity?.linesRemoved ?? 0)

        if commits == 0 {
            return "\(dateStr): No activity"
        }
        return "\(dateStr): \(commits) commit\(commits == 1 ? "" : "s"), \(lines) lines changed"
    }

    private func monthLabels() -> [(Int, String)] {
        var labels: [(Int, String)] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"

        var currentMonth = -1

        for week in 0..<weeks {
            let date = dateFor(week: week, day: 0)
            let month = calendar.component(.month, from: date)

            if month != currentMonth {
                currentMonth = month
                labels.append((week, dateFormatter.string(from: date)))
            }
        }

        return labels
    }
}

#Preview {
    // Generate sample data
    var activities: [Date: ActivityStats] = [:]
    let calendar = Calendar.current

    for i in 0..<180 {
        let date = calendar.date(byAdding: .day, value: -i, to: Date())!.startOfDay
        let commits = Int.random(in: 0...10)
        if commits > 0 {
            activities[date] = ActivityStats(
                date: date,
                linesAdded: Int.random(in: 10...500),
                linesRemoved: Int.random(in: 5...200),
                commits: commits
            )
        }
    }

    return ActivityHeatMap(activities: activities)
        .padding()
        .frame(width: 800)
}
