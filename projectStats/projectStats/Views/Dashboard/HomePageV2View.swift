import SwiftUI

/// Home Page V2 - Refined layout with grouped stats, galaxy time display, and enhanced charts
/// This is the container view that assembles all V2 components
struct HomePageV2View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Stats Pills Row - Grouped by type
                V2StatsRow()

                // Galaxy Layout - Time center, usage bars flanking
                V2GalaxyLayout()

                // Activity Chart with time range and data toggles
                V2ChartView()

                // Recent Projects - Cards with accent glow
                recentProjectsSection

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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Recent Projects Section

    private var recentProjectsSection: some View {
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
    }

    private func openProjectInNewTab(_ project: Project) {
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

#Preview {
    HomePageV2View()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(SettingsViewModel.shared)
}
