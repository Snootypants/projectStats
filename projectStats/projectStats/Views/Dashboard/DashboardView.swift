import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @StateObject private var projectListVM = ProjectListViewModel()
    @State private var selectedTab = 0
    @State private var showSyncLog = false

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Logo header
                HStack(spacing: 10) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title)
                        .foregroundStyle(.blue)
                    Text("ProjectStats")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)

                Divider()

                // Navigation
                List(selection: $selectedTab) {
                    Section {
                        Label("Overview", systemImage: "square.grid.2x2")
                            .tag(0)
                        Label("Projects", systemImage: "folder")
                            .tag(1)
                        Label("Activity", systemImage: "chart.line.uptrend.xyaxis")
                            .tag(2)
                    }

                    Section("Quick Stats") {
                        HStack {
                            Text("Active Projects")
                            Spacer()
                            Text("\(viewModel.activeProjectCount)")
                                .foregroundStyle(.secondary)
                        }
                        .tag(-1)

                        HStack {
                            Text("Total Projects")
                            Spacer()
                            if viewModel.archivedProjectCount > 0 {
                                Text("\(viewModel.countableProjectCount)")
                                    .foregroundStyle(.secondary)
                                Text("(\(viewModel.projects.count))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("\(viewModel.projects.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(-2)

                        HStack {
                            Text("Total Lines")
                            Spacer()
                            Text(viewModel.formattedTotalLineCount)
                                .foregroundStyle(.secondary)
                        }
                        .tag(-4)

                        if viewModel.aggregatedStats.currentStreak > 0 {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                Text("Streak")
                                Spacer()
                                Text("\(viewModel.aggregatedStats.currentStreak) days")
                                    .foregroundStyle(.secondary)
                            }
                            .tag(-3)
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                // Refresh button
                HStack {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        showSyncLog = true
                    } label: {
                        Image(systemName: "doc.plaintext")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    SettingsLink {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(minWidth: 200)
        } detail: {
            // Main content
            Group {
                switch selectedTab {
                case 0:
                    OverviewTab()
                case 1:
                    ProjectsTab(viewModel: projectListVM)
                case 2:
                    ActivityTab()
                default:
                    OverviewTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showSyncLog) {
            SyncLogView(lines: viewModel.syncLogLines)
        }
        .task {
            await viewModel.loadDataIfNeeded()
            projectListVM.updateProjects(viewModel.projects)
        }
        .onChange(of: viewModel.projects) { _, newValue in
            projectListVM.updateProjects(newValue)
        }
    }
}

// MARK: - Overview Tab
struct OverviewTab: View {
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Stats cards
                StatsCardsView(stats: viewModel.aggregatedStats)

                // Activity heat map
                VStack(alignment: .leading, spacing: 12) {
                    Text("Activity")
                        .font(.headline)

                    ActivityHeatMap(activities: viewModel.activities)
                        .frame(height: 120)
                }

                // Recent projects - 3 columns, 2 rows
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Projects")
                            .font(.headline)
                        Spacer()
                        if viewModel.archivedProjectCount > 0 {
                            Text("\(viewModel.countableProjectCount) active (\(viewModel.projects.count) total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(viewModel.projects.count) total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Array(viewModel.recentProjects.prefix(6))) { project in
                            CompactProjectCard(project: project)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Projects Tab
struct ProjectsTab: View {
    @ObservedObject var viewModel: ProjectListViewModel
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @State private var showCombineSheet = false
    @State private var showManageGroups = false

    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search projects...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Picker("Sort", selection: $viewModel.sortOption) {
                    ForEach(ProjectSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)

                Picker("Filter", selection: $viewModel.filterOption) {
                    ForEach(ProjectFilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Spacer()

                Button {
                    showCombineSheet = true
                } label: {
                    Label("Combine Projects", systemImage: "square.stack.3d.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button {
                    showManageGroups = true
                } label: {
                    Label("Manage", systemImage: "folder.badge.gearshape")
                }
                .buttonStyle(.bordered)
                .help("Manage Groups")
            }
            .padding()

            Divider()

            // Project list
            ProjectListView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCombineSheet) {
            ProjectGroupSheet(projects: dashboardVM.projects) {
                // Refresh after grouping
            }
        }
        .sheet(isPresented: $showManageGroups) {
            ManageGroupsView()
        }
    }
}

// MARK: - Activity Tab
struct ActivityTab: View {
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Full heat map
                VStack(alignment: .leading, spacing: 12) {
                    Text("Contribution Activity")
                        .font(.headline)

                    ActivityHeatMap(activities: viewModel.activities, weeks: 52)
                        .frame(height: 140)
                }

                // Activity chart
                ActivityChart(activities: viewModel.activities)
                    .frame(height: 250)

                // Stats breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Statistics")
                        .font(.headline)

                    HStack(spacing: 20) {
                        StatBox(title: "Total Lines Added", value: "\(viewModel.aggregatedStats.total.linesAdded)", icon: "plus.circle.fill", color: .green)
                        StatBox(title: "Total Lines Removed", value: "\(viewModel.aggregatedStats.total.linesRemoved)", icon: "minus.circle.fill", color: .red)
                        StatBox(title: "Total Commits", value: "\(viewModel.aggregatedStats.total.commits)", icon: "arrow.triangle.branch", color: .blue)
                    }
                }
            }
            .padding(24)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardView()
        .environmentObject(DashboardViewModel())
        .environmentObject(SettingsViewModel.shared)
        .frame(width: 1100, height: 750)
}
