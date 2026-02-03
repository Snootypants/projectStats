import SwiftUI

struct ShareCardView: View {
    let achievement: Achievement

    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 12) {
                Image(systemName: achievement.icon)
                    .font(.system(size: 48))
                    .foregroundColor(.white)

                Text(achievement.title)
                    .font(.title)
                    .foregroundColor(.white)

                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))

                Text("+\(achievement.points) XP · \(achievement.rarity.rawValue.uppercased())")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))

                Text("ProjectStats")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
        }
        .frame(width: 600, height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    ShareCardView(achievement: .nightOwl)
}
