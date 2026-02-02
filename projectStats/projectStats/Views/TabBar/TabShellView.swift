import SwiftUI

struct TabShellView: View {
    @EnvironmentObject var tabManager: TabManagerViewModel
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar at top
            TabBarView()

            Divider()

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
                .keyboardShortcut("t", modifiers: .command)

            Button("") {
                if let id = tabManager.activeTab?.id, tabManager.activeTab?.isCloseable == true {
                    tabManager.closeTab(id)
                }
            }
            .keyboardShortcut("w", modifiers: .command)

            Button("") { tabManager.nextTab() }
                .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("") { tabManager.previousTab() }
                .keyboardShortcut("[", modifiers: [.command, .shift])

            // Cmd+1 through Cmd+9 for tab switching
            Button("") { tabManager.selectTab(at: 0) }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { tabManager.selectTab(at: 1) }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { tabManager.selectTab(at: 2) }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { tabManager.selectTab(at: 3) }
                .keyboardShortcut("4", modifiers: .command)
            Button("") { tabManager.selectTab(at: 4) }
                .keyboardShortcut("5", modifiers: .command)
            Button("") { tabManager.selectTab(at: 5) }
                .keyboardShortcut("6", modifiers: .command)
            Button("") { tabManager.selectTab(at: 6) }
                .keyboardShortcut("7", modifiers: .command)
            Button("") { tabManager.selectTab(at: 7) }
                .keyboardShortcut("8", modifiers: .command)
            Button("") { tabManager.selectTab(at: 8) }
                .keyboardShortcut("9", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }
}
