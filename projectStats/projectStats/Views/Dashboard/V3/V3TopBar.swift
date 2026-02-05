import SwiftUI

/// V3 Top Bar - XP progress bar with level, streak badge, session active indicator
struct V3TopBar: View {
    @StateObject private var achievementService = AchievementService.shared
    @EnvironmentObject var viewModel: DashboardViewModel
    @ObservedObject var timeService = TimeTrackingService.shared
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    private var totalXP: Int {
        achievementService.unlockedAchievements.reduce(0) { $0 + $1.points }
    }

    private var currentLevel: Int {
        max(1, (totalXP / 250) + 1)
    }

    private var xpProgress: Double {
        let xp = totalXP
        let level = currentLevel
        let currentLevelXP = (level - 1) * 250
        let nextLevelXP = level * 250
        guard nextLevelXP > currentLevelXP else { return 1.0 }
        let progressInLevel = Double(xp - currentLevelXP) / Double(nextLevelXP - currentLevelXP)
        return min(max(progressInLevel, 0), 1)
    }

    private var isSessionActive: Bool {
        timeService.humanSessionStart != nil || timeService.aiSessionStart != nil
    }

    var body: some View {
        HStack(spacing: 16) {
            // XP Progress Bar
            HStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor)
                            .frame(width: geo.size.width * xpProgress)
                    }
                }
                .frame(height: 8)
                .frame(maxWidth: 200)

                Text("\(totalXP)/\(currentLevel * 250) XP")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text("Lvl \(currentLevel)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.2))
                    .clipShape(Capsule())
            }

            Divider()
                .frame(height: 20)

            // Streak badge
            if viewModel.aggregatedStats.currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(viewModel.aggregatedStats.currentStreak)d Streak")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }

            Spacer()

            // Session Active indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(isSessionActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(isSessionActive ? "Active" : "Idle")
                    .font(.caption)
                    .foregroundStyle(isSessionActive ? .primary : .secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.03))
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
    V3TopBar()
        .environmentObject(DashboardViewModel.shared)
}
