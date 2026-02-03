import SwiftUI

struct AchievementsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = AchievementService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Achievements")
                    .font(.title2.bold())
                Spacer()
                Text("\(service.unlockedAchievements.count)/\(Achievement.allCases.count)")
                    .foregroundStyle(.secondary)
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            // Progress
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(service.unlockedAchievements.count), total: Double(Achievement.allCases.count))
                    .tint(.purple)
                Text("\(totalXP) XP earned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            // Achievement grid/list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(AchievementRarity.allCases, id: \.self) { rarity in
                        Section {
                            ForEach(Achievement.allCases.filter { $0.rarity == rarity }, id: \.self) { achievement in
                                AchievementSheetRow(
                                    achievement: achievement,
                                    isUnlocked: service.unlockedAchievements.contains(achievement)
                                )
                            }
                        } header: {
                            HStack {
                                Text(rarity.rawValue.uppercased())
                                    .font(.caption.bold())
                                    .foregroundStyle(rarityColor(rarity))
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }

    private var totalXP: Int {
        service.unlockedAchievements.reduce(0) { $0 + $1.points }
    }

    private func rarityColor(_ rarity: AchievementRarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

struct AchievementSheetRow: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title3)
                .frame(width: 32)
                .foregroundStyle(isUnlocked ? rarityColor : .secondary.opacity(0.4))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(achievement.title)
                        .fontWeight(.medium)
                    if isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("+\(achievement.points)")
                .font(.caption.bold())
                .foregroundStyle(isUnlocked ? rarityColor : .secondary.opacity(0.4))
        }
        .padding(10)
        .background(isUnlocked ? rarityColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .opacity(isUnlocked ? 1 : 0.5)
    }

    private var rarityColor: Color {
        switch achievement.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

#Preview {
    AchievementsSheet()
}
