import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @State private var showActivityDetails = false
    @State private var showAchievements = false
    @StateObject private var achievementService = AchievementService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Quick Stats row (moved from sidebar)
                quickStatsRow

                HStack(alignment: .top, spacing: 16) {
                    TimeTrackingCard()
                        .frame(maxWidth: .infinity, minHeight: 140)
                    ClaudeTokenUsageCard()
                        .frame(maxWidth: .infinity, minHeight: 140)
                    GitHubNotificationsCard()
                        .frame(maxWidth: .infinity, minHeight: 140)
                }

                // Stats cards (existing component, unchanged)
                StatsCardsView(stats: viewModel.aggregatedStats)

                // Activity heat map (existing component, unchanged)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Activity")
                            .font(.headline)
                        Spacer()
                        Button {
                            showActivityDetails.toggle()
                        } label: {
                            Text(showActivityDetails ? "Show Less" : "Show More")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    ActivityHeatMap(activities: viewModel.activities, weeks: showActivityDetails ? 52 : 16)
                        .frame(height: showActivityDetails ? 140 : 120)

                    if showActivityDetails {
                        // Activity chart when expanded
                        ActivityChart(activities: viewModel.activities)
                            .frame(height: 200)

                        // Stats breakdown
                        HStack(spacing: 20) {
                            StatBox(title: "Total Lines Added", value: "\(viewModel.aggregatedStats.total.linesAdded)", icon: "plus.circle.fill", color: .green)
                            StatBox(title: "Total Lines Removed", value: "\(viewModel.aggregatedStats.total.linesRemoved)", icon: "minus.circle.fill", color: .red)
                            StatBox(title: "Total Commits", value: "\(viewModel.aggregatedStats.total.commits)", icon: "arrow.triangle.branch", color: .blue)
                        }
                    }
                }

                // Recent projects — clicking opens in a new tab
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Projects")
                            .font(.headline)
                        Spacer()
                        if viewModel.archivedProjectCount > 0 {
                            Text("\(viewModel.countableProjectCount) active (\(viewModel.projects.count) total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(viewModel.homeProjects) { project in
                            CompactProjectCard(project: project)
                                .onTapGesture {
                                    openProjectInNewTab(project)
                                }
                        }
                    }
                }

                // Refresh button at bottom
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showAchievements) {
            AchievementsSheet()
        }
    }

    private var quickStatsRow: some View {
        HStack(spacing: 24) {
            QuickStatPill(label: "Active", value: "\(viewModel.activeProjectCount)", color: .green)
            QuickStatPill(label: "Total", value: viewModel.archivedProjectCount > 0 ? "\(viewModel.countableProjectCount)" : "\(viewModel.projects.count)", color: .blue)
            QuickStatPill(label: "Lines", value: viewModel.formattedTotalLineCount, color: .purple)
            if viewModel.aggregatedStats.currentStreak > 0 {
                QuickStatPill(label: "Streak", value: "\(viewModel.aggregatedStats.currentStreak)d", color: .orange, icon: "flame.fill")
            }

            // Achievement badge
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
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .help(achievementService.mostRecentAchievement != nil
                ? "Last: \(achievementService.mostRecentAchievement!.title) — \(achievementService.mostRecentAchievement!.description)"
                : "View Achievements")

            Spacer()
        }
    }

    private func openProjectInNewTab(_ project: Project) {
        // If project is already open in a tab, switch to it
        // Otherwise create a new tab
        let path = project.path.path
        if let existingTab = tabManager.tabs.first(where: {
            if case .projectWorkspace(let p) = $0.content { return p == path }
            return false
        }) {
            tabManager.selectTab(existingTab.id)
        } else {
            tabManager.newTab()
            tabManager.openProject(path: path)
        }
    }
}

struct QuickStatPill: View {
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
