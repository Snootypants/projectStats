import SwiftUI

struct CompactLockoutBar: View {
    @ObservedObject var usageService = ClaudePlanUsageService.shared
    @ObservedObject var settings = SettingsViewModel.shared

    var body: some View {
        if usageService.isOffline {
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 9))
                Text("Usage data unavailable")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        } else {
            HStack(spacing: 12) {
                barView(
                    label: "Session",
                    percent: usageService.fiveHourUtilization,
                    countdown: usageService.fiveHourTimeRemaining,
                    isWeekly: false
                )
                barView(
                    label: "Weekly",
                    percent: usageService.sevenDayUtilization,
                    countdown: usageService.sevenDayTimeRemaining,
                    isWeekly: true
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private func barView(label: String, percent: Double, countdown: String, isWeekly: Bool) -> some View {
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
                        .fill(barColor(for: percent, isWeekly: isWeekly))
                        .frame(width: geo.size.width * min(percent, 1.0))
                    ShimmerOverlay()
                        .frame(width: geo.size.width * min(percent, 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 6)
        }
    }

    private func barColor(for value: Double, isWeekly: Bool) -> Color {
        if value >= 0.85 { return colorFromHex(settings.warningBarColorHex) ?? .red }
        let hex = isWeekly ? settings.weeklyBarColorHex : settings.sessionBarColorHex
        return colorFromHex(hex) ?? .blue
    }

    private func colorFromHex(_ hex: String) -> Color? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.hasPrefix("#") ? String(h.dropFirst()) : h
        guard h.count == 6, let n = UInt64(h, radix: 16) else { return nil }
        return Color(
            red: Double((n & 0xFF0000) >> 16) / 255,
            green: Double((n & 0x00FF00) >> 8) / 255,
            blue: Double(n & 0x0000FF) / 255
        )
    }
}

struct ShimmerOverlay: View {
    @State private var shimmerOffset: CGFloat = -0.3

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.15), .clear],
                        startPoint: .init(x: shimmerOffset - 0.3, y: 0.5),
                        endPoint: .init(x: shimmerOffset + 0.3, y: 0.5)
                    )
                )
                .onAppear {
                    withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                        shimmerOffset = 1.3
                    }
                }
        }
    }
}
