import SwiftUI

/// V5 XP Header - Large XP bar, level, streak and achievement count
struct V5XPHeader: View {
    @StateObject private var achievementService = AchievementService.shared
    @EnvironmentObject var viewModel: DashboardViewModel
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
        return Double(xp - currentLevelXP) / Double(nextLevelXP - currentLevelXP)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Large XP bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * xpProgress)
                        .shadow(color: accentColor.opacity(0.5), radius: 8)

                    // XP text overlay
                    HStack {
                        Spacer()
                        Text("\(totalXP) / \(currentLevel * 250) XP")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                }
            }
            .frame(height: 24)

            // Level and badges
            HStack(spacing: 24) {
                Text("LEVEL \(currentLevel)")
                    .font(.system(size: 28, weight: .black, design: .rounded))

                Divider()
                    .frame(height: 30)

                // Streak
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(viewModel.aggregatedStats.currentStreak) DAY STREAK")
                        .font(.subheadline.bold())
                }

                Divider()
                    .frame(height: 30)

                // Achievements
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("\(achievementService.unlockedAchievements.count) / \(Achievement.allCases.count) ACHIEVEMENTS")
                        .font(.subheadline.bold())
                }
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    V5XPHeader()
        .environmentObject(DashboardViewModel.shared)
        .padding()
}
