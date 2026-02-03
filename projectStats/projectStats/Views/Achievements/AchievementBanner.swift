import SwiftUI

struct AchievementBanner: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 12) {
            Text("ACHIEVEMENT UNLOCKED")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: achievement.icon)
                    .font(.title)
                VStack(alignment: .leading) {
                    Text(achievement.title)
                        .font(.headline)
                    Text(achievement.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("+\(achievement.points) XP")
                    .font(.caption)
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
        .padding()
    }
}

#Preview {
    AchievementBanner(achievement: .nightOwl)
}
