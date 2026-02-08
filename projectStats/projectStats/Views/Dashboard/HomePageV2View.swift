import SwiftUI
import Charts

struct HomePageV2View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @StateObject private var usageService = ClaudeUsageService.shared

    @State private var hoveredDate: Date?
    @State private var chartMode: ChartMode = .lines

    private enum ChartMode: String, CaseIterable {
        case lines = "Lines"
        case commits = "Commits"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Dashboard")
                        .font(.title.bold())
                    Spacer()
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isLoading)
                }

                // Weekly Activity Graph
                weeklyGraph

                // Stats row
                statsRow

                // Recent Projects
                recentProjectsGrid
            }
            .padding(24)
        }
    }

    // MARK: - Weekly Graph

    private var weeklyGraph: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Activity")
                    .font(.headline)

                Spacer()

                Picker("", selection: $chartMode) {
                    ForEach(ChartMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            let weekData = last7DaysData()

            Chart {
                ForEach(weekData, id: \.date) { entry in
                    if chartMode == .lines {
                        BarMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Lines", entry.linesAdded + entry.linesRemoved)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    } else {
                        BarMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Commits", entry.commits)
                        )
                        .foregroundStyle(Color.green.gradient)
                    }

                    if let hoveredDate, Calendar.current.isDate(hoveredDate, inSameDayAs: entry.date) {
                        RuleMark(x: .value("Day", entry.date, unit: .day))
                            .foregroundStyle(.secondary.opacity(0.3))
                            .annotation(position: .top, spacing: 4) {
                                tooltipView(for: entry)
                            }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if let date: Date = proxy.value(atX: location.x) {
                                    hoveredDate = date
                                }
                            case .ended:
                                hoveredDate = nil
                            }
                        }
                }
            }
            .frame(height: 200)
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func tooltipView(for entry: DayEntry) -> some View {
        VStack(spacing: 4) {
            Text(entry.date, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if chartMode == .lines {
                Text("\(entry.linesAdded + entry.linesRemoved) lines")
                    .font(.caption.bold())
            } else {
                Text("\(entry.commits) commits")
                    .font(.caption.bold())
            }
        }
        .padding(6)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(radius: 2)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard("Active Projects", value: "\(viewModel.activeProjectCount)", icon: "folder.fill", color: .green)
            statCard("Total Lines", value: viewModel.formattedTotalLineCount, icon: "text.alignleft", color: .blue)
            statCard("Streak", value: "\(viewModel.aggregatedStats.currentStreak)d", icon: "flame.fill", color: .orange)

            if let todayStats = usageService.globalTodayStats {
                statCard("Today Cost", value: "$\(String(format: "%.2f", todayStats.totalCost))", icon: "dollarsign.circle", color: .purple)
            }
        }
    }

    private func statCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Recent Projects

    private var recentProjectsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Projects")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.homeProjects) { project in
                    projectCard(project)
                        .onTapGesture {
                            openProject(project)
                        }
                }
            }
        }
    }

    private func projectCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(project.status == .active ? Color.green : .gray)
                    .frame(width: 8, height: 8)
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
            }

            HStack(spacing: 12) {
                Label("\(project.formattedLineCount)", systemImage: "text.alignleft")
                if let commits = project.totalCommits {
                    Label("\(commits)", systemImage: "arrow.triangle.branch")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let commit = project.lastCommit {
                Text(commit.date.relativeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private struct DayEntry {
        let date: Date
        let linesAdded: Int
        let linesRemoved: Int
        let commits: Int
    }

    private func last7DaysData() -> [DayEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            if let stats = viewModel.activities[date] {
                return DayEntry(date: date, linesAdded: stats.linesAdded, linesRemoved: stats.linesRemoved, commits: stats.commits)
            }
            return DayEntry(date: date, linesAdded: 0, linesRemoved: 0, commits: 0)
        }
    }

    private func openProject(_ project: Project) {
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
