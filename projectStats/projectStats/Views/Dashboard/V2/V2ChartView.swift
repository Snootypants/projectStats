import SwiftUI
import Charts

/// V2 Chart View - Enhanced activity chart with external controls
/// Data toggle (Lines/Commits) and time range picker moved above chart
struct V2ChartView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @AppStorage("chartTimeRange") private var timeRange: String = "week"
    @AppStorage("chartDataType") private var dataType: String = "lines"

    private var selectedRange: ChartRange {
        ChartRange(rawValue: timeRange) ?? .week
    }

    private var chartData: [V2ChartDataPoint] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<selectedRange.days).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let startOfDay = date.startOfDay
            let activity = viewModel.activities[startOfDay]

            return V2ChartDataPoint(
                date: startOfDay,
                commits: activity?.commits ?? 0,
                linesAdded: activity?.linesAdded ?? 0,
                linesRemoved: activity?.linesRemoved ?? 0
            )
        }.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toolbar row - data toggle left, time range right
            HStack {
                // Data toggle (Lines vs Commits) - left aligned
                HStack(spacing: 12) {
                    DataTogglePill(
                        label: "Lines",
                        isSelected: dataType == "lines"
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            dataType = "lines"
                        }
                    }

                    DataTogglePill(
                        label: "Commits",
                        isSelected: dataType == "commits"
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            dataType = "commits"
                        }
                    }
                }

                Spacer()

                // Time range picker - right aligned
                Picker("Range", selection: $timeRange) {
                    Text("Week").tag("week")
                    Text("Month").tag("month")
                    Text("Quarter").tag("quarter")
                    Text("Year").tag("year")
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            // Chart
            Chart(chartData) { point in
                if dataType == "lines" {
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Lines", point.totalLines)
                    )
                    .foregroundStyle(Color.purple.gradient)
                } else {
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Commits", point.commits)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
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

// MARK: - Chart Range Enum

enum ChartRange: String, CaseIterable {
    case week
    case month
    case quarter
    case year

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

// MARK: - Chart Data Point

struct V2ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let commits: Int
    let linesAdded: Int
    let linesRemoved: Int

    var totalLines: Int { linesAdded + linesRemoved }
}

// MARK: - Data Toggle Pill

private struct DataTogglePill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    V2ChartView()
        .environmentObject(DashboardViewModel.shared)
        .frame(height: 300)
        .padding()
}
