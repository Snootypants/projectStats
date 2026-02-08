import SwiftUI
import Charts

struct HomePageV2View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @StateObject private var usageService = ClaudeUsageService.shared
    @StateObject private var planUsage = ClaudePlanUsageService.shared
    @ObservedObject private var timeService = TimeTrackingService.shared
    @StateObject private var achievementService = AchievementService.shared
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    @State private var hoveredDate: Date?
    @State private var showLines = true
    @State private var showCommits = false
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Today + Lockout Bars
                HStack(alignment: .top, spacing: 16) {
                    timePanel
                        .frame(maxWidth: .infinity)
                    lockoutPanel
                        .frame(maxWidth: .infinity)
                }

                // Weekly Chart
                weeklyChart

                // Project Cards
                projectCardsGrid
            }
            .padding(24)
        }
        .background(Color.primary.opacity(0.02))
        .onReceive(refreshTimer) { _ in
            now = Date()
        }
        .task {
            await planUsage.fetchUsage()
        }
    }

    // MARK: - Time Panel

    private var timePanel: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
                Text("TIME TODAY")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(totalTimeFormatted)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()

            VStack(spacing: 8) {
                meterRow(label: "You", value: humanProgress, time: humanTimeFormatted, color: .green)
                meterRow(label: "Claude", value: aiProgress, time: aiTimeFormatted, color: .pink)
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func meterRow(label: String, value: Double, time: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                Spacer()
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * value))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Lockout Panel

    private var lockoutPanel: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "gauge.with.needle.fill")
                    .foregroundStyle(.cyan)
                Text("USAGE")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let todayCost = usageService.globalTodayStats?.totalCost {
                Text(String(format: "$%.2f", todayCost))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                lockoutMeter(
                    label: "Session",
                    percent: planUsage.fiveHourUtilization,
                    countdown: planUsage.fiveHourTimeRemaining
                )
                lockoutMeter(
                    label: "Weekly",
                    percent: planUsage.sevenDayUtilization,
                    countdown: planUsage.sevenDayTimeRemaining
                )
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func lockoutMeter(label: String, percent: Double, countdown: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                Spacer()
                Text("\(Int(percent * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(countdown)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(lockoutColor(percent))
                        .frame(width: max(4, geo.size.width * min(percent, 1.0)))
                }
            }
            .frame(height: 8)
        }
    }

    private func lockoutColor(_ value: Double) -> Color {
        if value > 0.8 { return .red }
        if value > 0.6 { return .orange }
        return .cyan
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WEEKLY ACTIVITY")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                // Checkbox toggles
                HStack(spacing: 16) {
                    Toggle(isOn: $showLines) {
                        HStack(spacing: 4) {
                            Circle().fill(.cyan).frame(width: 8, height: 8)
                            Text("Lines")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.checkbox)

                    Toggle(isOn: $showCommits) {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("Commits")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            let weekData = last7DaysData()

            // Summary tooltip
            if let hoveredDate,
               let entry = weekData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: hoveredDate) }) {
                HStack(spacing: 12) {
                    Text(entry.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if showLines {
                        Text("\((entry.linesAdded + entry.linesRemoved).formatted()) lines")
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                    }
                    if showCommits {
                        Text("\(entry.commits) commits")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
            } else {
                // Week total
                let totalLines = weekData.reduce(0) { $0 + $1.linesAdded + $1.linesRemoved }
                let totalCommits = weekData.reduce(0) { $0 + $1.commits }
                HStack(spacing: 12) {
                    Text("This week:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if showLines {
                        Text("\(totalLines.formatted()) lines")
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                    }
                    if showCommits {
                        Text("\(totalCommits) commits")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }
            }

            Chart {
                if showLines {
                    ForEach(weekData, id: \.date) { entry in
                        LineMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Lines", entry.linesAdded + entry.linesRemoved)
                        )
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Lines", entry.linesAdded + entry.linesRemoved)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan.opacity(0.3), .cyan.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }

                if showCommits {
                    ForEach(weekData, id: \.date) { entry in
                        LineMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Commits", entry.commits)
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Commits", entry.commits)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green.opacity(0.2), .green.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }

                if let hoveredDate {
                    RuleMark(x: .value("Day", hoveredDate, unit: .day))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
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
            .frame(height: 220)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.18))
            )
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Project Cards

    private var projectCardsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(viewModel.homeProjects) { project in
                V2ProjectCard(project: project, accentColor: accentColor)
                    .onTapGesture {
                        openProject(project)
                    }
            }
        }
    }

    // MARK: - Time Calculations

    private var totalTime: TimeInterval {
        let humanCurrent = timeService.humanSessionStart.map { now.timeIntervalSince($0) } ?? 0
        let aiCurrent = timeService.aiSessionStart.map { now.timeIntervalSince($0) } ?? 0
        return timeService.todayHumanTotal + timeService.todayAITotal + humanCurrent + aiCurrent
    }

    private var humanTime: TimeInterval {
        let current = timeService.humanSessionStart.map { now.timeIntervalSince($0) } ?? 0
        return timeService.todayHumanTotal + current
    }

    private var aiTime: TimeInterval {
        let current = timeService.aiSessionStart.map { now.timeIntervalSince($0) } ?? 0
        return timeService.todayAITotal + current
    }

    private var humanProgress: Double {
        guard totalTime > 0 else { return 0.5 }
        return humanTime / totalTime
    }

    private var aiProgress: Double {
        guard totalTime > 0 else { return 0.5 }
        return aiTime / totalTime
    }

    private var totalTimeFormatted: String { formatDuration(totalTime) }
    private var humanTimeFormatted: String { formatDuration(humanTime) }
    private var aiTimeFormatted: String { formatDuration(aiTime) }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    // MARK: - Data Helpers

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

// MARK: - Project Card

private struct V2ProjectCard: View {
    let project: Project
    let accentColor: Color
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Top row: language tag + star
            HStack {
                if let language = project.language {
                    Text(language)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(languageColor(language).opacity(0.2))
                        .foregroundStyle(languageColor(language))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                Image(systemName: project.status == .active ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(project.status == .active ? .yellow : .gray.opacity(0.4))
            }
            .padding(.bottom, 10)

            // Project name centered
            Text(project.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)

            // Bottom row: time ago + line count
            HStack {
                Text(project.lastActivityString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(project.formattedLineCount)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isHovering ? .green.opacity(0.5) : Color.green.opacity(0.15),
                    lineWidth: isHovering ? 2 : 1
                )
        )
        .shadow(color: isHovering ? .green.opacity(0.2) : .clear, radius: 8)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(Rectangle())
    }

    private func languageColor(_ language: String) -> Color {
        switch language.lowercased() {
        case "swift": return .orange
        case "javascript", "typescript": return .yellow
        case "python": return .blue
        case "rust": return .red
        case "go": return .cyan
        case "ruby": return .red
        default: return .gray
        }
    }
}

// MARK: - Color Hex Extension

private extension Color {
    static func fromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized
        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else { return nil }
        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255
        return Color(red: r, green: g, blue: b)
    }
}
