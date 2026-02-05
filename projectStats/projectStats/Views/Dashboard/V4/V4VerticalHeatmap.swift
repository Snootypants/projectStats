import SwiftUI

/// V4 Vertical Heatmap - Days of week as vertical column with activity bars
struct V4VerticalHeatmap: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    private var weekData: [(day: String, date: Date, activity: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            let activity = viewModel.activities[date]?.linesAdded ?? 0
            return (day: dayName, date: date, activity: activity)
        }
    }

    private var maxActivity: Int {
        max(weekData.map(\.activity).max() ?? 1, 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(weekData, id: \.date) { item in
                HStack(spacing: 8) {
                    Text(item.day)
                        .font(.caption.bold())
                        .frame(width: 32, alignment: .leading)
                        .foregroundStyle(item.date == Calendar.current.startOfDay(for: Date()) ? .primary : .secondary)

                    // Activity bar
                    GeometryReader { geo in
                        let barWidth = max(4, geo.size.width * CGFloat(item.activity) / CGFloat(maxActivity))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(for: item.activity))
                            .frame(width: barWidth, height: 16)
                    }
                    .frame(height: 16)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    item.date == Calendar.current.startOfDay(for: Date())
                        ? accentColor.opacity(0.1)
                        : Color.clear
                )
            }
        }
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.03))
    }

    private func barColor(for activity: Int) -> Color {
        let intensity = Double(activity) / Double(maxActivity)
        if intensity > 0.7 {
            return accentColor
        } else if intensity > 0.3 {
            return accentColor.opacity(0.6)
        } else if activity > 0 {
            return accentColor.opacity(0.3)
        } else {
            return Color.gray.opacity(0.2)
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
    V4VerticalHeatmap()
        .environmentObject(DashboardViewModel.shared)
        .frame(width: 100, height: 400)
}
