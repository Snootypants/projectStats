import SwiftUI
import AppKit

struct TabShellView: View {
    @EnvironmentObject var tabManager: TabManagerViewModel
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @StateObject private var achievementService = AchievementService.shared
    @State private var previousTabs: [AppTab] = []
    @State private var showCommandPalette = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar at top
            TabBarView()

            Divider()

            // XP Progress Bar
            XPProgressBar()

            // Active tab content
            if let activeTab = tabManager.activeTab {
                tabContent(for: activeTab)
                    .id(activeTab.id)  // Force view refresh when switching tabs
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Hidden buttons for keyboard shortcuts
        .background {
            keyboardShortcutButtons
        }
        .onAppear {
            previousTabs = tabManager.tabs
        }
        .onChange(of: tabManager.activeTabID) { _, _ in
            if let activeTab = tabManager.activeTab,
               case .projectWorkspace(let path) = activeTab.content {
                Task { await DashboardViewModel.shared.syncSingleProject(path: path) }
            }
        }
        .onChange(of: tabManager.tabs) { _, newTabs in
            let removedTabs = previousTabs.filter { oldTab in
                !newTabs.contains(where: { $0.id == oldTab.id })
            }
            previousTabs = newTabs

            for tab in removedTabs {
                if case .projectWorkspace(let path) = tab.content {
                    Task { await DashboardViewModel.shared.syncSingleProject(path: path) }
                }
            }
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView(commands: commandPaletteCommands())
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab.content {
        case .home:
            HomeView()

        case .projectPicker:
            ProjectPickerView()

        case .projectWorkspace(let path):
            WorkspaceView(projectPath: path)
        }
    }

    // Hidden buttons that capture keyboard shortcuts
    private var keyboardShortcutButtons: some View {
        Group {
            Button("") { tabManager.newTab() }
                .keyboardShortcut("t", modifiers: [.command, .shift])

            Button("") {
                if let id = tabManager.activeTab?.id, tabManager.activeTab?.isCloseable == true {
                    tabManager.closeTab(id)
                }
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])

            Button("") { tabManager.nextTab() }
                .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("") { tabManager.previousTab() }
                .keyboardShortcut("[", modifiers: [.command, .shift])

            // Cmd+1 through Cmd+9 for tab switching
            Button("") { tabManager.selectTab(at: 0) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("") { tabManager.selectTab(at: 1) }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("") { tabManager.selectTab(at: 2) }
                .keyboardShortcut("3", modifiers: [.command, .option])
            Button("") { tabManager.selectTab(at: 3) }
                .keyboardShortcut("4", modifiers: [.command, .option])
            Button("") { tabManager.selectTab(at: 4) }
                .keyboardShortcut("5", modifiers: [.command, .option])
            Button("") { tabManager.selectTab(at: 5) }
                .keyboardShortcut("6", modifiers: [.command, .option])
            Button("") { tabManager.selectTab(at: 6) }
                .keyboardShortcut("7", modifiers: [.command, .option])
            Button("") { tabManager.selectTab(at: 7) }
                .keyboardShortcut("8", modifiers: [.command, .option])
            Button("") { tabManager.selectTab(at: 8) }
                .keyboardShortcut("9", modifiers: [.command, .option])

            Button("") { showCommandPalette.toggle() }
                .keyboardShortcut("k", modifiers: [.command])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    private func commandPaletteCommands() -> [Command] {
        [
            Command(name: "New Terminal Tab", icon: "terminal", shortcut: "⌘T", action: { /* TODO */ }),
            Command(name: "Commit Changes", icon: "arrow.up.circle", shortcut: "⌘⇧C", action: { /* TODO */ }),
            Command(name: "Refresh Project Stats", icon: "arrow.clockwise", shortcut: "⌘R", action: { Task { await dashboardVM.refresh() } }),
            Command(name: "Open Settings", icon: "gear", shortcut: "⌘,", action: { NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil) })
        ]
    }
}

// MARK: - XP Progress Bar

struct XPProgressBar: View {
    @StateObject private var achievementService = AchievementService.shared

    private var totalXP: Int {
        achievementService.unlockedAchievements.reduce(0) { $0 + $1.points }
    }

    private var currentLevel: Int {
        // 250 XP per level
        return (totalXP / 250) + 1
    }

    private var xpInCurrentLevel: Int {
        return totalXP % 250
    }

    private var xpForNextLevel: Int {
        return 250
    }

    private var progress: CGFloat {
        guard xpForNextLevel > 0 else { return 0 }
        return CGFloat(xpInCurrentLevel) / CGFloat(xpForNextLevel)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progress))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)

            // XP text
            Text("\(xpInCurrentLevel) / \(xpForNextLevel) XP")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            // Level badge
            Text("Lvl \(currentLevel)")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
