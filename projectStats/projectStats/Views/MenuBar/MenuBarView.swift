import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("ProjectStats")
                    .font(.headline)
                Spacer()
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Quick stats
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("\(formatNumber(dashboardViewModel.aggregatedStats.today.totalLines))")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                        Text("lines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Commits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(dashboardViewModel.aggregatedStats.today.commits)")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                }

                Spacer()

                if dashboardViewModel.aggregatedStats.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(dashboardViewModel.aggregatedStats.currentStreak) day streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Recent projects
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("Recent Projects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(dashboardViewModel.recentProjects) { project in
                            QuickProjectRow(project: project)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 280)
            }

            Divider()

            // Footer
            HStack {
                Button {
                    openDashboard()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.expand.vertical")
                        Text("Open Dashboard")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                if dashboardViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Button {
                        Task {
                            await dashboardViewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 340)
        .task {
            if dashboardViewModel.projects.isEmpty {
                await dashboardViewModel.loadData()
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000.0)
        }
        return "\(number)"
    }

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.isEmpty || $0.title == "ProjectStats" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Open a new window
            NSApp.sendAction(Selector(("newWindowForTab:")), to: nil, from: nil)
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(DashboardViewModel())
        .environmentObject(SettingsViewModel.shared)
}
