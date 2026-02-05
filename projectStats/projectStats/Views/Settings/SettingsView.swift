import AppKit
import SwiftUI

// MARK: - Color Hex Extension for Settings

private extension Color {
    static func fromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255

        return Color(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB) else {
            return nil
        }

        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case homePage
    case appearance
    case github
    case messaging
    case cloudSync
    case ai
    case terminal
    case claudeUsage
    case data
    case notifications
    case subscription
    case account
    case about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .homePage: return "house"
        case .appearance: return "paintbrush"
        case .github: return "link"
        case .messaging: return "message"
        case .cloudSync: return "icloud"
        case .ai: return "sparkles"
        case .terminal: return "terminal"
        case .claudeUsage: return "chart.bar"
        case .data: return "tray.full"
        case .notifications: return "bell"
        case .subscription: return "creditcard"
        case .account: return "person.crop.circle"
        case .about: return "info.circle"
        }
    }

    var label: String {
        switch self {
        case .general: return "General"
        case .homePage: return "Home"
        case .appearance: return "Appearance"
        case .github: return "GitHub"
        case .messaging: return "Messaging"
        case .cloudSync: return "Cloud"
        case .ai: return "AI"
        case .terminal: return "Terminal"
        case .claudeUsage: return "Usage"
        case .data: return "Data"
        case .notifications: return "Alerts"
        case .subscription: return "Subscribe"
        case .account: return "Account"
        case .about: return "About"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab = .general
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar - scrollable to fit all items
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(SettingsTab.allCases) { tab in
                        SettingsSidebarItem(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            accentColor: accentColor
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .padding(.horizontal, 4)
            }
            .frame(width: 90)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            // Divider with subtle glow when hovered
            SettingsDivider(accentColor: accentColor)

            // Content
            ScrollView {
                contentView(for: selectedTab)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor).opacity(0.3))
        }
        .environmentObject(viewModel)
        .frame(width: 650, height: 500)
    }

    @ViewBuilder
    private func contentView(for tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            GeneralSettingsView()
        case .homePage:
            HomePageSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .github:
            GitHubSettingsView()
        case .messaging:
            MessagingSettingsView()
        case .cloudSync:
            CloudSyncSettingsView()
        case .ai:
            AISettingsView()
        case .terminal:
            TerminalSettingsView()
        case .claudeUsage:
            ClaudeUsageSettingsView()
        case .data:
            DataManagementView()
        case .notifications:
            NotificationSettingsView()
        case .subscription:
            SubscriptionView()
        case .account:
            AccountView()
        case .about:
            AboutView()
        }
    }
}

// MARK: - Sidebar Item

private struct SettingsSidebarItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                Text(tab.label)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 70, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .shadow(color: isSelected ? accentColor.opacity(0.15) : .clear, radius: 4)
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(isHovering && !isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return accentColor.opacity(0.6)  // Softer accent color
        } else if isHovering {
            return Color.gray.opacity(0.1)
        }
        return Color.clear
    }

    private var foregroundColor: Color {
        isSelected ? .white : .primary
    }
}

// MARK: - Settings Divider

private struct SettingsDivider: View {
    let accentColor: Color
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? accentColor.opacity(0.5) : Color.secondary.opacity(0.2))
            .frame(width: 1)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @AppStorage("showHiddenFiles") private var showHiddenFiles: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("General")
                .font(.title.bold())

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Code Directory
                VStack(alignment: .leading, spacing: 6) {
                    Text("Code Directory")
                        .font(.headline)
                    HStack {
                        TextField("", text: .constant(viewModel.codeDirectory.path))
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)

                        Button("Browse...") {
                            viewModel.selectCodeDirectory()
                        }
                    }
                    Text("The root directory where your projects are located.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Default Editor
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Editor")
                        .font(.headline)
                    Picker("", selection: $viewModel.defaultEditor) {
                        ForEach(Editor.allCases, id: \.self) { editor in
                            Label(editor.rawValue, systemImage: editor.icon)
                                .tag(editor)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                }

                // Default Terminal
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Terminal")
                        .font(.headline)
                    Picker("", selection: $viewModel.defaultTerminal) {
                        ForEach(Terminal.allCases, id: \.self) { terminal in
                            Text(terminal.rawValue).tag(terminal)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                }

                // Refresh Interval
                VStack(alignment: .leading, spacing: 6) {
                    Text("Refresh Interval")
                        .font(.headline)
                    Stepper("\(viewModel.refreshInterval) minutes", value: $viewModel.refreshInterval, in: 5...60, step: 5)
                        .frame(maxWidth: 200)
                    Text("How often to automatically refresh project statistics.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Launch Options
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                    Toggle("Show in Dock", isOn: $viewModel.showInDock)
                }

                Divider()

                // File Browser
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show Hidden Files in File Browser", isOn: $showHiddenFiles)
                    Text("Show dotfiles like .env and .gitignore in the Files panel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"
    @AppStorage("dividerGlowOpacity") private var glowOpacity: Double = 0.5
    @AppStorage("dividerGlowRadius") private var glowRadius: Double = 3.0
    @AppStorage("dividerLineThickness") private var lineThickness: Double = 2.0
    @AppStorage("dividerBarOpacity") private var barOpacity: Double = 1.0
    @AppStorage("previewDividerGlow") private var previewGlow: Bool = false

    private let colorPresets: [(name: String, hex: String)] = [
        ("Orange", "#FF9500"),
        ("Blue", "#007AFF"),
        ("Purple", "#AF52DE"),
        ("Green", "#34C759"),
        ("Pink", "#FF2D55"),
        ("Teal", "#5AC8FA"),
        ("Indigo", "#5856D6")
    ]

    private var glowColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Appearance")
                .font(.title.bold())

            Divider()

            // Theme Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.headline)

                Picker("", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Text("Choose your preferred appearance for the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Accent Color Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Accent Color")
                    .font(.headline)

                Text("Used for dividers, selections, and UI highlights.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(colorPresets, id: \.hex) { preset in
                        ColorPresetButton(
                            name: preset.name,
                            hex: preset.hex,
                            isSelected: accentColorHex == preset.hex
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                accentColorHex = preset.hex
                            }
                        }
                    }

                    Divider()
                        .frame(height: 30)

                    // Custom color picker
                    ColorPicker("", selection: Binding(
                        get: { Color.fromHex(accentColorHex) ?? .orange },
                        set: { accentColorHex = $0.toHex() ?? "#FF9500" }
                    ))
                    .labelsHidden()
                    .frame(width: 30, height: 30)
                }
            }

            Divider()

            // Divider Glow Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Divider Glow")
                    .font(.headline)

                Text("Customize how panel dividers look when hovered")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Preview Toggle
                Toggle("Preview Glow", isOn: $previewGlow)
                    .toggleStyle(.switch)

                // Thickness Slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thickness: \(lineThickness, specifier: "%.1f")px")
                        .font(.subheadline)
                    HStack {
                        Text("Thin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $lineThickness, in: 1.0...6.0)
                        Text("Thick")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Bar Opacity Slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bar Opacity: \(Int(barOpacity * 100))%")
                        .font(.subheadline)
                    HStack {
                        Text("Faint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $barOpacity, in: 0.3...1.0)
                        Text("Solid")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Opacity/Intensity Slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Glow Intensity: \(Int(glowOpacity * 100))%")
                        .font(.subheadline)
                    HStack {
                        Text("Subtle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $glowOpacity, in: 0.1...1.0)
                        Text("Bold")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Glow Radius/Spread Slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Glow Spread: \(glowRadius, specifier: "%.1f")px")
                        .font(.subheadline)
                    HStack {
                        Text("Tight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $glowRadius, in: 1.0...10.0)
                        Text("Wide")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Live Preview Bar
                HStack {
                    Text("Preview:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ZStack {
                        // Glow layer
                        Rectangle()
                            .fill(glowColor.opacity(glowOpacity * 0.6))
                            .frame(width: 100, height: lineThickness * 3)
                            .blur(radius: glowRadius)

                        // Main line
                        Rectangle()
                            .fill(glowColor)
                            .frame(width: 100, height: lineThickness)
                            .shadow(color: glowColor.opacity(glowOpacity), radius: glowRadius)
                    }
                    .frame(height: 30)

                    Spacer()

                    // Reset to Defaults Button
                    Button("Reset to Defaults") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            lineThickness = 2.0
                            barOpacity = 1.0
                            glowOpacity = 0.5
                            glowRadius = 3.0
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }

            Divider()

            // IDE Tabs Section
            VStack(alignment: .leading, spacing: 12) {
                Text("IDE Tabs")
                    .font(.headline)

                Text("Choose which tabs to show in the workspace viewer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Show Prompts Tab", isOn: $viewModel.showPromptsTab)
                    .toggleStyle(.switch)

                Toggle("Show Diffs Tab", isOn: $viewModel.showDiffsTab)
                    .toggleStyle(.switch)

                Toggle("Show Environment Tab", isOn: $viewModel.showEnvironmentTab)
                    .toggleStyle(.switch)
            }

            Spacer()
        }
    }
}

// MARK: - Color Preset Button

private struct ColorPresetButton: View {
    let name: String
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    private var color: Color {
        Color.fromHex(hex) ?? .orange
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: isSelected ? 4 : 0)
                )
                .shadow(color: isHovering ? color.opacity(0.5) : .clear, radius: 4)
                .scaleEffect(isHovering ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .help(name)
    }
}

// MARK: - GitHub Settings

struct GitHubSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showToken = false
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("GitHub")
                .font(.title.bold())

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("Personal Access Token")
                    .font(.headline)

                HStack {
                    if showToken {
                        TextField("GitHub Token", text: $viewModel.githubToken)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("GitHub Token", text: $viewModel.githubToken)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showToken.toggle()
                    } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                .frame(maxWidth: 400)

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("Success") ? .green : .red)
                }

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(viewModel.githubToken.isEmpty || isTesting)

                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()

                    Link("Create Token", destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:user")!)
                }

                Text("Optional. Allows fetching additional repository information like stars and forks. Requires 'repo' scope.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let url = URL(string: "https://api.github.com/user")!
                var request = URLRequest(url: url)
                request.setValue("Bearer \(viewModel.githubToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        testResult = "Success! Token is valid."
                    } else if httpResponse.statusCode == 401 {
                        testResult = "Error: Invalid token."
                    } else {
                        testResult = "Error: HTTP \(httpResponse.statusCode)"
                    }
                }
            } catch {
                testResult = "Error: \(error.localizedDescription)"
            }

            isTesting = false
        }
    }
}

// MARK: - Home Page Settings

struct HomePageSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    // Data Display checkboxes - all disabled for now (stored for future use)
    @AppStorage("homeDataShow_linesPerDay") private var showLinesPerDay = false
    @AppStorage("homeDataShow_commitsPerDay") private var showCommitsPerDay = false
    @AppStorage("homeDataShow_netLines") private var showNetLines = false
    @AppStorage("homeDataShow_codeChurnRate") private var showCodeChurnRate = false
    @AppStorage("homeDataShow_linesPerCommit") private var showLinesPerCommit = false
    @AppStorage("homeDataShow_totalTimeToday") private var showTotalTimeToday = false
    @AppStorage("homeDataShow_humanAiTimeSplit") private var showHumanAiTimeSplit = false
    @AppStorage("homeDataShow_avgSessionLength") private var showAvgSessionLength = false
    @AppStorage("homeDataShow_mostProductiveHour") private var showMostProductiveHour = false
    @AppStorage("homeDataShow_inputOutputTokens") private var showInputOutputTokens = false
    @AppStorage("homeDataShow_cacheTokens") private var showCacheTokens = false
    @AppStorage("homeDataShow_costUsd") private var showCostUsd = false
    @AppStorage("homeDataShow_modelBreakdown") private var showModelBreakdown = false
    @AppStorage("homeDataShow_costPerLine") private var showCostPerLine = false
    @AppStorage("homeDataShow_costPerCommit") private var showCostPerCommit = false
    @AppStorage("homeDataShow_sessionBlockUsage") private var showSessionBlockUsage = false
    @AppStorage("homeDataShow_weeklyUsage") private var showWeeklyUsage = false
    @AppStorage("homeDataShow_usageRate") private var showUsageRate = false
    @AppStorage("homeDataShow_predictedTimeToLimit") private var showPredictedTimeToLimit = false
    @AppStorage("homeDataShow_languageDistribution") private var showLanguageDistribution = false
    @AppStorage("homeDataShow_mostActiveProject") private var showMostActiveProject = false
    @AppStorage("homeDataShow_projectHealth") private var showProjectHealth = false
    @AppStorage("homeDataShow_linesPerDayRolling") private var showLinesPerDayRolling = false
    @AppStorage("homeDataShow_commitsPerDayRolling") private var showCommitsPerDayRolling = false
    @AppStorage("homeDataShow_velocityTrend") private var showVelocityTrend = false
    @AppStorage("homeDataShow_weekOverWeek") private var showWeekOverWeek = false
    @AppStorage("homeDataShow_xpProgress") private var showXpProgress = false
    @AppStorage("homeDataShow_achievementProgress") private var showAchievementProgress = false
    @AppStorage("homeDataShow_currentStreak") private var showCurrentStreak = false
    @AppStorage("homeDataShow_longestStreak") private var showLongestStreak = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Home Page")
                .font(.title.bold())

            Divider()

            // Layout Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Layout")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    layoutOption(
                        value: "v1",
                        title: "V1 (Classic)",
                        description: "Original dashboard layout"
                    )
                    layoutOption(
                        value: "v2",
                        title: "V2 (Refined)",
                        description: "Galaxy layout with centered time display"
                    )
                    layoutOption(
                        value: "v3",
                        title: "V3 (Command Center)",
                        description: "Dense 3-column systems dashboard"
                    )
                    layoutOption(
                        value: "v4",
                        title: "V4 (Timeline)",
                        description: "Week-as-story with vertical heatmap"
                    )
                    layoutOption(
                        value: "v5",
                        title: "V5 (Arcade HUD)",
                        description: "Gamified stats with XP front-and-center"
                    )
                }
            }

            Divider()

            // Data Display Section (Coming Soon)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Data Display")
                        .font(.headline)
                    Text("(Coming Soon)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Activity & Code
                DataDisplayGroup(title: "Activity & Code") {
                    DisabledCheckbox(label: "Lines of Code per Day", isOn: $showLinesPerDay)
                    DisabledCheckbox(label: "Commits per Day", isOn: $showCommitsPerDay)
                    DisabledCheckbox(label: "Net Lines (Added - Removed)", isOn: $showNetLines)
                    DisabledCheckbox(label: "Code Churn Rate", isOn: $showCodeChurnRate)
                    DisabledCheckbox(label: "Lines per Commit", isOn: $showLinesPerCommit)
                }

                // Time Tracking
                DataDisplayGroup(title: "Time Tracking") {
                    DisabledCheckbox(label: "Total Time Today", isOn: $showTotalTimeToday)
                    DisabledCheckbox(label: "Human vs AI Time Split", isOn: $showHumanAiTimeSplit)
                    DisabledCheckbox(label: "Average Session Length", isOn: $showAvgSessionLength)
                    DisabledCheckbox(label: "Most Productive Hour", isOn: $showMostProductiveHour)
                }

                // AI Usage
                DataDisplayGroup(title: "AI Usage") {
                    DisabledCheckbox(label: "Input / Output Tokens", isOn: $showInputOutputTokens)
                    DisabledCheckbox(label: "Cache Tokens", isOn: $showCacheTokens)
                    DisabledCheckbox(label: "Cost (USD)", isOn: $showCostUsd)
                    DisabledCheckbox(label: "Model Breakdown", isOn: $showModelBreakdown)
                    DisabledCheckbox(label: "Cost per Line of Code", isOn: $showCostPerLine)
                    DisabledCheckbox(label: "Cost per Commit", isOn: $showCostPerCommit)
                }

                // Plan Limits
                DataDisplayGroup(title: "Plan Limits") {
                    DisabledCheckbox(label: "Session Block Usage %", isOn: $showSessionBlockUsage)
                    DisabledCheckbox(label: "Weekly Usage %", isOn: $showWeeklyUsage)
                    DisabledCheckbox(label: "Usage Rate (% per hour)", isOn: $showUsageRate)
                    DisabledCheckbox(label: "Predicted Time to Limit", isOn: $showPredictedTimeToLimit)
                }

                // Projects
                DataDisplayGroup(title: "Projects") {
                    DisabledCheckbox(label: "Language Distribution", isOn: $showLanguageDistribution)
                    DisabledCheckbox(label: "Most Active Project Today", isOn: $showMostActiveProject)
                    DisabledCheckbox(label: "Project Health / Staleness", isOn: $showProjectHealth)
                }

                // Velocity & Trends
                DataDisplayGroup(title: "Velocity & Trends") {
                    DisabledCheckbox(label: "Lines per Day (Rolling Avg)", isOn: $showLinesPerDayRolling)
                    DisabledCheckbox(label: "Commits per Day (Rolling Avg)", isOn: $showCommitsPerDayRolling)
                    DisabledCheckbox(label: "Velocity Trend", isOn: $showVelocityTrend)
                    DisabledCheckbox(label: "Week-over-Week Comparison", isOn: $showWeekOverWeek)
                }

                // Gamification
                DataDisplayGroup(title: "Gamification") {
                    DisabledCheckbox(label: "XP Progress", isOn: $showXpProgress)
                    DisabledCheckbox(label: "Achievement Progress", isOn: $showAchievementProgress)
                    DisabledCheckbox(label: "Current Streak", isOn: $showCurrentStreak)
                    DisabledCheckbox(label: "Longest Streak", isOn: $showLongestStreak)
                }
            }
            .opacity(0.4)
        }
    }

    // MARK: - Layout Option Row

    @ViewBuilder
    private func layoutOption(value: String, title: String, description: String) -> some View {
        Button {
            viewModel.homePageLayout = value
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.homePageLayout == value ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(viewModel.homePageLayout == value ? .blue : .secondary)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.homePageLayout == value ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Data Display Helpers

private struct DataDisplayGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
            content
        }
        .padding(.leading, 8)
    }
}

private struct DisabledCheckbox: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.checkbox)
            .disabled(true)
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("ProjectStats")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("A developer dashboard for tracking your coding activity across all projects.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 300)

            Spacer()

            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/Snootypants/projectStats")!)
                Text("•")
                    .foregroundStyle(.secondary)
                Link("Report Issue", destination: URL(string: "https://github.com/Snootypants/projectStats/issues")!)
            }
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel.shared)
        .environmentObject(DashboardViewModel.shared)
}
