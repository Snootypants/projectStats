import SwiftUI

struct CompactLockoutBar: View {
    @ObservedObject var usageService = ClaudePlanUsageService.shared

    var body: some View {
        HStack(spacing: 12) {
            barView(
                label: "Session",
                percent: usageService.fiveHourUtilization,
                countdown: usageService.fiveHourTimeRemaining
            )
            barView(
                label: "Weekly",
                percent: usageService.sevenDayUtilization,
                countdown: usageService.sevenDayTimeRemaining
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func barView(label: String, percent: Double, countdown: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text("\(label) (\(Int(percent * 100))%, resets \(countdown))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(for: percent))
                        .frame(width: geo.size.width * min(percent, 1.0))
                }
            }
            .frame(height: 6)
        }
    }

    private func barColor(for value: Double) -> Color {
        if value < 0.6 { return .green }
        if value < 0.85 { return .yellow }
        return .red
    }
}
