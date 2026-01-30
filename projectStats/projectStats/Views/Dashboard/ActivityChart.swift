import SwiftUI
import Charts

struct ActivityChart: View {
    let activities: [Date: ActivityStats]
    @State private var selectedRange: ChartRange = .month

    enum ChartRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }

    var chartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<selectedRange.days).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let startOfDay = date.startOfDay
            let activity = activities[startOfDay]

            return ChartDataPoint(
                date: startOfDay,
                commits: activity?.commits ?? 0,
                linesAdded: activity?.linesAdded ?? 0,
                linesRemoved: activity?.linesRemoved ?? 0
            )
        }.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity Over Time")
                    .font(.headline)

                Spacer()

                Picker("Range", selection: $selectedRange) {
                    ForEach(ChartRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            Chart(chartData) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Commits", point.commits)
                )
                .foregroundStyle(Color.blue.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var xAxisStride: Calendar.Component {
        switch selectedRange {
        case .week: return .day
        case .month: return .weekOfYear
        case .quarter: return .month
        case .year: return .month
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.day().month(.abbreviated)
        case .quarter, .year:
            return .dateTime.month(.abbreviated)
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let commits: Int
    let linesAdded: Int
    let linesRemoved: Int

    var totalLines: Int { linesAdded + linesRemoved }
}

#Preview {
    var activities: [Date: ActivityStats] = [:]
    let calendar = Calendar.current

    for i in 0..<365 {
        let date = calendar.date(byAdding: .day, value: -i, to: Date())!.startOfDay
        let commits = Int.random(in: 0...15)
        if commits > 0 || Int.random(in: 0...3) == 0 {
            activities[date] = ActivityStats(
                date: date,
                linesAdded: Int.random(in: 50...800),
                linesRemoved: Int.random(in: 20...300),
                commits: commits
            )
        }
    }

    return ActivityChart(activities: activities)
        .frame(height: 300)
        .padding()
}
