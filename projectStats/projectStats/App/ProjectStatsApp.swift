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
            CachedCommit.self,
            ChatMessage.self,
            TimeEntry.self,
            AchievementUnlock.self,
            ProjectNote.self,
            SavedPrompt.self,
            SavedDiff.self,
            ClaudeUsageSnapshot.self,
            ClaudePlanUsageSnapshot.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("[SwiftData] ModelContainer creation failed: \(error). Clearing store and retrying.")
            if let cleanupError = deletePersistentStoreFiles() {
                print("[SwiftData] Failed to clear store: \(cleanupError)")
            }
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after cleanup: \(error)")
            }
        }
    }()

    private static func deletePersistentStoreFiles() -> Error? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.calebbelshe.projectStats"
        let candidateDirs = [
            appSupport,
            appSupport.appendingPathComponent(bundleID, isDirectory: true)
        ]

        var firstError: Error?
        for dir in candidateDirs {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
                continue
            }
            for url in items where url.lastPathComponent.hasPrefix("default.store") {
                do {
                    try fm.removeItem(at: url)
                } catch {
                    if firstError == nil {
                        firstError = error
                    }
                }
            }
        }

        return firstError
    }
}

@main
struct ProjectStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dashboardViewModel = DashboardViewModel.shared
    @StateObject private var settingsViewModel = SettingsViewModel.shared
    @StateObject private var tabManager = TabManagerViewModel.shared
    @StateObject private var claudePlanUsage = ClaudePlanUsageService.shared
    @StateObject private var claudeContextMonitor = ClaudeContextMonitor.shared
    @StateObject private var messagingService = MessagingService.shared
    @StateObject private var cloudSyncService = CloudSyncService.shared
    @StateObject private var achievementService = AchievementService.shared
    @StateObject private var timeTrackingService = TimeTrackingService.shared
    @StateObject private var featureFlags = FeatureFlags.shared
    @StateObject private var githubService = GitHubService.shared
    @State private var hasMigrated = false

    var body: some Scene {
        // Main window with tab-based navigation
        WindowGroup(id: "main") {
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
                    await DataCleanupService.shared.cleanupIfNeeded(context: context)
                    await DashboardViewModel.shared.loadDataIfNeeded()
                    ClaudePlanUsageService.shared.startHourlyPolling()
                    await ClaudeContextMonitor.shared.refresh()
                    tabManager.restoreState()
                }
                .onDisappear {
                    tabManager.saveState()
                }
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .modelContainer(AppModelContainer.shared)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 750)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Enter Focus Mode") {
                    NotificationCenter.default.post(name: .enterFocusMode, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }

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
                .environmentObject(dashboardViewModel)
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

    func applicationDidBecomeActive(_ notification: Notification) {
        // Bring main window to front after system dialogs (e.g., Keychain prompts)
        DispatchQueue.main.async {
            if let mainWindow = NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey }) {
                mainWindow.makeKeyAndOrderFront(nil)
            }
        }
    }
}
