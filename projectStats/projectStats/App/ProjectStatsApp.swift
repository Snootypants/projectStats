import AppKit
import SwiftUI
import SwiftData

/// Shared model container for the app
enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            CachedProject.self,
            CachedDailyActivity.self,
            CachedPrompt.self,
            CachedWorkLog.self,
            CachedCommit.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

@main
struct ProjectStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dashboardViewModel = DashboardViewModel.shared
    @StateObject private var settingsViewModel = SettingsViewModel.shared
    @StateObject private var tabManager = TabManagerViewModel.shared
    @State private var hasMigrated = false

    var body: some Scene {
        // Main window with tab-based navigation
        WindowGroup {
            TabShellView()
                .environmentObject(dashboardViewModel)
                .environmentObject(settingsViewModel)
                .environmentObject(tabManager)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    guard !hasMigrated else { return }
                    hasMigrated = true
                    let context = AppModelContainer.shared.mainContext
                    await DataMigrationService.shared.migrateIfNeeded(modelContext: context)
                    await DashboardViewModel.shared.loadDataIfNeeded()
                    tabManager.restoreState()
                }
                .onDisappear {
                    tabManager.saveState()
                }
        }
        .modelContainer(AppModelContainer.shared)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 750)

        // Menu bar
        MenuBarExtra("ProjectStats", systemImage: "chart.bar.xaxis") {
            MenuBarView()
                .environmentObject(dashboardViewModel)
                .environmentObject(settingsViewModel)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(settingsViewModel)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !SettingsViewModel.shared.showInDock {
            NSApplication.shared.setActivationPolicy(.accessory)
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
        }
        SettingsViewModel.shared.applyThemeIfNeeded()
    }
}
