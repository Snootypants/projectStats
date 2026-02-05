import SwiftUI

/// V2 Stats Row - Grouped stats pills with logical separation
/// Left group: Activity metrics (Active, Total, Lines)
/// Right group: Progress metrics (Streak, Achievements)
struct V2StatsRow: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @StateObject private var achievementService = AchievementService.shared
    @State private var showAchievements = false

    var body: some View {
        HStack {
            // Left group: Activity Metrics (left-aligned)
            HStack(spacing: 8) {
                V2StatPill(label: "Active", value: "\(viewModel.activeProjectCount)", color: .green)
                V2StatPill(
                    label: "Total",
                    value: viewModel.archivedProjectCount > 0
                        ? "\(viewModel.countableProjectCount)"
                        : "\(viewModel.projects.count)",
                    color: .blue
                )
                V2StatPill(label: "Lines", value: viewModel.formattedTotalLineCount, color: .purple)
            }

            // Push groups to opposite edges
            Spacer()

            // Right group: Progress Metrics (right-aligned)
            HStack(spacing: 8) {
                if viewModel.aggregatedStats.currentStreak > 0 {
                    V2StatPill(
                        label: "Streak",
                        value: "\(viewModel.aggregatedStats.currentStreak)d",
                        color: .orange,
                        icon: "flame.fill"
                    )
                }

                // Achievement badge (clickable)
                Button {
                    showAchievements = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: achievementService.mostRecentAchievement?.icon ?? "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("\(achievementService.unlockedAchievements.count)/\(Achievement.allCases.count)")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.2))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(achievementService.mostRecentAchievement != nil
                    ? "Last: \(achievementService.mostRecentAchievement!.title) — \(achievementService.mostRecentAchievement!.description)"
                    : "View Achievements")
            }
        }
        .sheet(isPresented: $showAchievements) {
            AchievementsSheet()
        }
    }
}

/// Individual stat pill for V2 layout
struct V2StatPill: View {
    let label: String
    let value: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

#Preview {
    V2StatsRow()
        .environmentObject(DashboardViewModel.shared)
        .padding()
}
