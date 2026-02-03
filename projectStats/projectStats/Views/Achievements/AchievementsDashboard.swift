import SwiftUI

struct AchievementsDashboard: View {
    @StateObject private var service = AchievementService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.title2)
                Spacer()
                Text("\(service.unlockedAchievements.count)/\(Achievement.allCases.count)")
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(service.unlockedAchievements.count), total: Double(Achievement.allCases.count))

            Text("Recently Unlocked")
                .font(.headline)

            if service.unlockedAchievements.isEmpty {
                Text("No achievements yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Achievement.allCases.filter { service.unlockedAchievements.contains($0) }, id: \.self) { achievement in
                    AchievementRow(achievement: achievement)
                }
            }
        }
        .padding()
    }
}

private struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack {
            Image(systemName: achievement.icon)
            VStack(alignment: .leading) {
                Text(achievement.title)
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("+\(achievement.points) XP")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AchievementsDashboard()
}
