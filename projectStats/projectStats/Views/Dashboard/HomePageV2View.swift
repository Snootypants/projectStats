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
    @State private var hoverX: CGFloat?
    @State private var showLines = true
    @State private var showCommits = false
    @State private var chartRange: ChartRange = .week
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private enum ChartRange: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        case custom = "Custom"

        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            case .custom: return 0
            }
        }
    }

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Today + Usage (equal height)
                HStack(alignment: .top, spacing: 16) {
                    timePanel
                        .frame(maxWidth: .infinity, minHeight: 160)
                    usagePanel
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
                .fixedSize(horizontal: false, vertical: true)

                // Activity Chart
                activityChart

                // Project Cards
                projectCardsGrid
            }
            .padding(24)
        }
        .background(Color.primary.opacity(0.02))
        .onReceive(refreshTimer) { _ in
            now = Date()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            Task { await planUsage.fetchUsage() }
        }
        .task {
            await planUsage.fetchUsage()
        }
    }

    // MARK: - Time Panel

    private var timePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
                Text("TIME TODAY")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            Text(totalTimeFormatted)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()

            Spacer().frame(height: 12)

            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("You:")
                        .font(.system(size: 13, weight: .bold))
                    Text(humanTimeFormatted)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 6) {
                    Circle().fill(.pink).frame(width: 8, height: 8)
                    Text("Claude:")
                        .font(.system(size: 13, weight: .bold))
                    Text(aiTimeFormatted)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.pink)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Usage Panel

    private var usagePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "gauge.with.needle.fill")
                    .foregroundStyle(.cyan)
                Text("USAGE")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            VStack(spacing: 14) {
                usageMeter(
                    label: "Session",
                    percent: planUsage.fiveHourUtilization,
                    resetInfo: formatSessionReset(planUsage.fiveHourResetsAt),
                    lines: viewModel.aggregatedStats.today.totalLines,
                    commits: viewModel.aggregatedStats.today.commits
                )
                usageMeter(
                    label: "Weekly",
                    percent: planUsage.sevenDayUtilization,
                    resetInfo: formatWeeklyReset(planUsage.sevenDayResetsAt),
                    lines: viewModel.aggregatedStats.thisWeek.totalLines,
                    commits: viewModel.aggregatedStats.thisWeek.commits
                )
            }

            Spacer()
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func usageMeter(label: String, percent: Double, resetInfo: String, lines: Int, commits: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text("\(Int(percent * 100))%")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(usageColor(percent))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(usageColor(percent))
                        .frame(width: max(4, geo.size.width * min(percent, 1.0)))
                }
            }
            .frame(height: 8)

            HStack(spacing: 8) {
                Text("\(lines.formatted()) lines")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("\(commits) commits")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(resetInfo)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func usageColor(_ value: Double) -> Color {
        if value > 0.8 { return .red }
        if value > 0.6 { return .orange }
        return .cyan
    }

    private func formatSessionReset(_ date: Date?) -> String {
        guard let date else { return "--" }
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "Resets now" }
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "Resets in \(hours) hr \(String(format: "%02d", minutes)) min"
    }

    private func formatWeeklyReset(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE h:mm a"
        return "Resets \(formatter.string(from: date))"
    }

    // MARK: - Activity Chart

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACTIVITY")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                // Time range picker
                HStack(spacing: 2) {
                    ForEach(ChartRange.allCases, id: \.self) { range in
                        Button {
                            chartRange = range
                        } label: {
                            Text(range.rawValue)
                                .font(.system(size: 10, weight: chartRange == range ? .bold : .regular))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(chartRange == range ? Color.cyan.opacity(0.2) : Color.clear)
                                .foregroundStyle(chartRange == range ? .cyan : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().frame(height: 16)

                // Data type checkboxes
                HStack(spacing: 12) {
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

            // Custom date range pickers
            if chartRange == .custom {
                HStack(spacing: 12) {
                    DatePicker("From", selection: $customStart, displayedComponents: .date)
                        .labelsHidden()
                    Text("to")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("To", selection: $customEnd, displayedComponents: .date)
                        .labelsHidden()
                }
                .font(.caption)
            }

            let chartData = dataForRange()

            // Fixed-height summary row (prevents resize on hover)
            chartSummaryFixed(data: chartData)
                .frame(height: 24)

            // Chart with inline tooltip overlay
            Chart {
                if showLines {
                    ForEach(chartData, id: \.date) { entry in
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
                    ForEach(chartData, id: \.date) { entry in
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
                        .foregroundStyle(.cyan.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel(format: xAxisFormat)
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
                                hoverX = location.x
                                if let date: Date = proxy.value(atX: location.x) {
                                    hoveredDate = date
                                }
                            case .ended:
                                hoveredDate = nil
                                hoverX = nil
                            }
                        }
                        .overlay(alignment: .topLeading) {
                            if let hoveredDate, let hoverX,
                               let entry = chartData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: hoveredDate) }) {
                                chartTooltip(entry: entry)
                                    .offset(x: tooltipX(hoverX: hoverX, geoWidth: geo.size.width), y: 4)
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

    private func tooltipX(hoverX: CGFloat, geoWidth: CGFloat) -> CGFloat {
        let tooltipWidth: CGFloat = 160
        let x = hoverX - tooltipWidth / 2
        return max(0, min(x, geoWidth - tooltipWidth))
    }

    private func chartTooltip(entry: DayEntry) -> some View {
        VStack(spacing: 4) {
            if showLines {
                Text("\((entry.linesAdded + entry.linesRemoved).formatted())")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            if showCommits {
                Text("\(entry.commits) commits")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text(entry.date, format: .dateTime.weekday(.abbreviated))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(red: 0.15, green: 0.17, blue: 0.25).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(width: 160)
    }

    @ViewBuilder
    private func chartSummaryFixed(data: [DayEntry]) -> some View {
        let totalLines = data.reduce(0) { $0 + $1.linesAdded + $1.linesRemoved }
        let totalCommits = data.reduce(0) { $0 + $1.commits }
        HStack(spacing: 12) {
            Text("\(chartRange.rawValue) total:")
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
            Spacer()
        }
    }

    // MARK: - X Axis Formatting

    private var xAxisStride: Calendar.Component {
        switch chartRange {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .quarter: return .month
        case .year: return .month
        case .custom:
            let days = Calendar.current.dateComponents([.day], from: customStart, to: customEnd).day ?? 30
            if days <= 7 { return .day }
            if days <= 60 { return .weekOfYear }
            return .month
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch chartRange {
        case .day:
            return .dateTime.hour()
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.day().month(.abbreviated)
        case .quarter, .year:
            return .dateTime.month(.abbreviated)
        case .custom:
            let days = Calendar.current.dateComponents([.day], from: customStart, to: customEnd).day ?? 30
            if days <= 7 { return .dateTime.weekday(.abbreviated) }
            if days <= 60 { return .dateTime.day().month(.abbreviated) }
            return .dateTime.month(.abbreviated)
        }
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

    private func dataForRange() -> [DayEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let startDate: Date
        let endDate: Date

        if chartRange == .custom {
            startDate = cal.startOfDay(for: customStart)
            endDate = cal.startOfDay(for: customEnd)
        } else {
            let numDays = max(chartRange.days, 1)
            startDate = cal.date(byAdding: .day, value: -(numDays - 1), to: today)!
            endDate = today
        }

        let dayCount = max(1, (cal.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)

        return (0..<dayCount).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: startDate)!
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

            Text(project.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)

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
