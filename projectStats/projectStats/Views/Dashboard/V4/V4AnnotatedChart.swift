import SwiftUI
import Charts

/// V4 Annotated Chart - Large glowing line chart with floating annotation chips
struct V4AnnotatedChart: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @StateObject private var usageService = ClaudeUsageService.shared
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    private var chartData: [V4ChartDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().compactMap { daysAgo -> V4ChartDataPoint? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let activity = viewModel.activities[date]
            return V4ChartDataPoint(
                date: date,
                lines: activity?.linesAdded ?? 0,
                commits: activity?.commits ?? 0
            )
        }
    }

    private var annotations: [ChartAnnotation] {
        var result: [ChartAnnotation] = []

        // Find peak day
        if let peak = chartData.max(by: { $0.lines < $1.lines }), peak.lines > 0 {
            result.append(ChartAnnotation(
                date: peak.date,
                text: "\(peak.lines) lines",
                color: .green
            ))
        }

        // Find commit peak
        if let commitPeak = chartData.max(by: { $0.commits < $1.commits }), commitPeak.commits > 0 {
            result.append(ChartAnnotation(
                date: commitPeak.date,
                text: "\(commitPeak.commits) commits",
                color: .blue
            ))
        }

        // Today's cost if available
        if let todayCost = usageService.globalTodayStats?.totalCost, todayCost > 0 {
            result.append(ChartAnnotation(
                date: Calendar.current.startOfDay(for: Date()),
                text: String(format: "$%.2f", todayCost),
                color: .yellow
            ))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)

            ZStack {
                // Main chart
                Chart(chartData) { point in
                    // Area fill
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

                    // Line
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Lines", point.lines)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    // Points
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Lines", point.lines)
                    )
                    .foregroundStyle(accentColor)
                    .symbolSize(30)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
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
                .shadow(color: accentColor.opacity(0.5), radius: 8)
                .shadow(color: accentColor.opacity(0.3), radius: 16)

                // Floating annotation chips
                annotationOverlay
            }
            .frame(height: 250)
        }
    }

    private var annotationOverlay: some View {
        GeometryReader { geo in
            ForEach(annotations) { annotation in
                if let position = chartPosition(for: annotation.date, in: geo.size) {
                    AnnotationChip(text: annotation.text, color: annotation.color)
                        .position(x: position.x, y: max(40, position.y - 30))
                }
            }
        }
    }

    private func chartPosition(for date: Date, in size: CGSize) -> CGPoint? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let daysAgo = calendar.dateComponents([.day], from: date, to: today).day else { return nil }
        let dayIndex = 6 - daysAgo

        guard dayIndex >= 0, dayIndex < 7 else { return nil }

        let x = (size.width / 7) * CGFloat(dayIndex) + (size.width / 14)

        // Find y position based on data
        let activity = viewModel.activities[date]
        let lines = activity?.linesAdded ?? 0
        let maxLines = chartData.map(\.lines).max() ?? 1
        let yRatio = CGFloat(lines) / CGFloat(max(maxLines, 1))
        let y = size.height - (size.height * yRatio * 0.8) - 20

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Chart Data Point

private struct V4ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let lines: Int
    let commits: Int
}

// MARK: - Chart Annotation

private struct ChartAnnotation: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
    let color: Color
}

// MARK: - Annotation Chip

private struct AnnotationChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
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
    V4AnnotatedChart()
        .environmentObject(DashboardViewModel.shared)
        .padding()
}
