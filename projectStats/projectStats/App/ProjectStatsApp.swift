import SwiftUI
import SwiftData

@main
struct ProjectStatsApp: App {
    @StateObject private var dashboardViewModel = DashboardViewModel()
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

    init() { }

    var body: some Scene {
        // Main dashboard window
        WindowGroup {
            DashboardView()
                .environmentObject(dashboardViewModel)
                .environmentObject(settingsViewModel)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    if !SettingsViewModel.shared.showInDock {
                        NSApp?.setActivationPolicy(.accessory)
                    }
                    SettingsViewModel.shared.applyThemeIfNeeded()
                }
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
