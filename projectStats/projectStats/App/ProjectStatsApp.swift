import AppKit
import SwiftUI
import SwiftData

@main
struct ProjectStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dashboardViewModel = DashboardViewModel.shared
    @StateObject private var settingsViewModel = SettingsViewModel.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedProject.self,
            CachedDailyActivity.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Pass the model container to the app delegate for migration
        appDelegate.modelContainer = sharedModelContainer
    }

    var body: some Scene {
        // Main dashboard window
        WindowGroup {
            DashboardView()
                .environmentObject(dashboardViewModel)
                .environmentObject(settingsViewModel)
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(sharedModelContainer)
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
    var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !SettingsViewModel.shared.showInDock {
            NSApplication.shared.setActivationPolicy(.accessory)
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
        }
        SettingsViewModel.shared.applyThemeIfNeeded()

        // Run migration if needed, then load data
        Task { @MainActor in
            if let container = modelContainer {
                let context = container.mainContext
                await DataMigrationService.shared.migrateIfNeeded(modelContext: context)
            }
            await DashboardViewModel.shared.loadDataIfNeeded()
        }
    }
}
