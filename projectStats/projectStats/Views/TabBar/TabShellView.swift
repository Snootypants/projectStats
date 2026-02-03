import SwiftUI
import AppKit

struct TabShellView: View {
    @EnvironmentObject var tabManager: TabManagerViewModel
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var previousTabs: [AppTab] = []
    @State private var showCommandPalette = false

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
        .onAppear {
            previousTabs = tabManager.tabs
        }
        .onChange(of: tabManager.activeTabID) { _, _ in
            if let activeTab = tabManager.activeTab,
               case .projectWorkspace(let path) = activeTab.content {
                Task { await DashboardViewModel.shared.syncSingleProject(path: path) }
            }
        }
        .onChange(of: tabManager.tabs) { newTabs in
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

            Button(\"\") { showCommandPalette.toggle() }
                .keyboardShortcut(\"k\", modifiers: [.command])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    private func commandPaletteCommands() -> [Command] {
        [
            Command(name: \"New Terminal Tab\", icon: \"terminal\", shortcut: \"⌘T\", action: { /* TODO */ }),
            Command(name: \"Commit Changes\", icon: \"arrow.up.circle\", shortcut: \"⌘⇧C\", action: { /* TODO */ }),
            Command(name: \"Refresh Project Stats\", icon: \"arrow.clockwise\", shortcut: \"⌘R\", action: { Task { await dashboardVM.refresh() } }),
            Command(name: \"Open Settings\", icon: \"gear\", shortcut: \"⌘,\", action: { NSApp.sendAction(Selector((\"showPreferencesWindow:\")), to: nil, from: nil) })
        ]
    }
}
