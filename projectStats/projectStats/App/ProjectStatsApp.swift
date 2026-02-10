import AppKit
import SwiftUI
import SwiftData
import os.log

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
            ClaudePlanUsageSnapshot.self,
            // DB v2 Models
            ProjectSession.self,
            DailyMetric.self,
            WorkItem.self,
            WeeklyGoal.self,
            // AI Provider Models
            AIProviderConfig.self,
            AISessionV2.self,
            // Prompt Template Models
            PromptTemplate.self,
            PromptTemplateVersion.self,
            // Prompt Execution Tracking
            PromptExecution.self,
            // Vibe Tab
            ConversationSession.self,
            // Settings Store
            AppSetting.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            Log.data.error("[SwiftData] ModelContainer creation failed: \(error). Backing up and clearing store.")
            // Back up before nuking — this is the last line of defense for user data
            DataBackupService.shared.backupStore()
            if let cleanupError = deletePersistentStoreFiles() {
                Log.data.error("[SwiftData] Failed to clear store: \(cleanupError)")
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

                    // Back up store before any migrations
                    DataBackupService.shared.backupStore()

                    let context = AppModelContainer.shared.mainContext
                    await DataMigrationService.shared.migrateIfNeeded(modelContext: context)
                    await DBv2MigrationService.shared.migrateIfNeeded(context: context)
                    await DataCleanupService.shared.cleanupIfNeeded(context: context)
                    SettingsViewModel.shared.migrateSettingsToDBIfNeeded()
                    seedDefaultTemplateIfNeeded(context: context)
                    await DashboardViewModel.shared.loadDataIfNeeded()
                    ClaudePlanUsageService.shared.startHourlyPolling()
                    await ClaudeContextMonitor.shared.refresh()
                    tabManager.restoreState()

                    // Start periodic Claude usage refresh (every 10 minutes)
                    ClaudeUsageService.shared.startPeriodicRefresh()
                    // Fetch immediately on launch
                    Task { await ClaudeUsageService.shared.refreshGlobal() }
                }
                .onDisappear {
                    tabManager.saveState()
                    // Fetch usage on quit
                    Task { await ClaudeUsageService.shared.refreshGlobal() }
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

// MARK: - Template Seeding

private func seedDefaultTemplateIfNeeded(context: ModelContext) {
    let descriptor = FetchDescriptor<PromptTemplate>(
        predicate: #Predicate { $0.isDefault == true }
    )
    let existing = (try? context.fetch(descriptor)) ?? []
    guard existing.isEmpty else { return }

    let template = PromptTemplate(
        name: "Default",
        content: DefaultPromptTemplate.content,
        isDefault: true
    )
    context.insert(template)
    context.safeSave()
    Log.lifecycle.info("[App] Seeded default prompt template")
}

// MARK: - Default Prompt Template

enum DefaultPromptTemplate {
    static let content = """
    ## META OUTPUT INSTRUCTIONS (NON-NEGOTIABLE)

    1. **Plan:** Outline moves in order. State what you will NOT touch.
    2. **Difficulty:** Brief estimate and likely failure points.
    3. **Execute:** Do the work. Minimal edits. One scope at a time.
    4. **Report + Self-Grade:** What changed, why, grade yourself (A–F).

    ## ENGINEERING PHILOSOPHY (NON-NEGOTIABLE)

    Simplest, most direct solution. Less code is better code. No over-engineering.

    ## PROCESS RULES

    - TDD: Write or update tests FIRST, then implement.
    - Sequential execution. Commit after every scope.
    - Build + tests must pass before moving on.
    - If stuck >10 minutes: skip, add `// TODO:`, note in report.

    ## TASK

    {PROMPT}
    """
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !SettingsViewModel.shared.showInDock {
            NSApplication.shared.setActivationPolicy(.accessory)
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
        }
        SettingsViewModel.shared.applyThemeIfNeeded()

        // Initialize NotificationService to request permissions at launch
        _ = NotificationService.shared
        Log.lifecycle.info("[App] NotificationService initialized, requesting permissions")
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
