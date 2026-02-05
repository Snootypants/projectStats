import SwiftUI
import Charts

/// V2 Chart View - Enhanced activity chart with glowing line graph
/// Data toggle (Lines/Commits) and time range picker above chart
struct V2ChartView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @AppStorage("chartTimeRange") private var timeRange: String = "week"
    @AppStorage("chartDataType") private var dataType: String = "lines"
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

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
                        isSelected: dataType == "lines",
                        accentColor: accentColor
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            dataType = "lines"
                        }
                    }

                    DataTogglePill(
                        label: "Commits",
                        isSelected: dataType == "commits",
                        accentColor: accentColor
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

            // Glowing Line Chart
            ZStack {
                // Area fill under the line
                Chart(chartData) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Value", dataType == "lines" ? point.totalLines : point.commits)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor.opacity(0.2), accentColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)

                // Main line with glow effect
                Chart(chartData) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Value", dataType == "lines" ? point.totalLines : point.commits)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(accentColor)

                    // Data points
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Value", dataType == "lines" ? point.totalLines : point.commits)
                    )
                    .symbolSize(16)
                    .foregroundStyle(accentColor)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.primary.opacity(0.1))
                        AxisValueLabel(format: xAxisFormat)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.primary.opacity(0.1))
                        AxisValueLabel()
                            .foregroundStyle(Color.secondary)
                    }
                }
                // Glow effects (layered shadows)
                .shadow(color: accentColor.opacity(0.6), radius: 6)
                .shadow(color: accentColor.opacity(0.3), radius: 12)
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
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
    V2ChartView()
        .environmentObject(DashboardViewModel.shared)
        .frame(height: 300)
        .padding()
}
