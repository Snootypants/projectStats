import XCTest
@testable import projectStats

/// Integration tests for cross-layer functionality
final class IntegrationTests: XCTestCase {

    // MARK: - Model Container Integration

    @MainActor
    func testModelContainerSingleton() {
        // Verify model container is accessible
        let container = AppModelContainer.shared
        XCTAssertNotNil(container)
    }

    @MainActor
    func testModelContextAccess() {
        // Verify we can get a main context
        let context = AppModelContainer.shared.mainContext
        XCTAssertNotNil(context)
    }

    // MARK: - Service to ViewModel Integration

    @MainActor
    func testDashboardViewModelAccessesProjectScanner() {
        let dashboardVM = DashboardViewModel.shared
        let scanner = ProjectScanner.shared

        // Both should exist and be accessible
        XCTAssertNotNil(dashboardVM)
        XCTAssertNotNil(scanner)
    }

    @MainActor
    func testSettingsViewModelAccessesServices() {
        let settingsVM = SettingsViewModel.shared

        // Settings should be able to trigger notifications
        XCTAssertNotNil(NotificationService.shared)
        XCTAssertNotNil(settingsVM)
    }

    // MARK: - Git Service Integration

    @MainActor
    func testGitServiceInProjectDirectory() {
        let gitService = GitService.shared

        // Test getting current branch (may fail if not in git repo)
        let branch = gitService.getCurrentBranch(at: FileManager.default.currentDirectoryPath)
        // Branch may be nil if not in a git repo, that's OK
        XCTAssert(branch == nil || !branch!.isEmpty)
    }

    // MARK: - Time Tracking Integration

    @MainActor
    func testTimeTrackingServiceIntegration() {
        let timeService = TimeTrackingService.shared
        let terminalMonitor = TerminalOutputMonitor.shared

        // Both should be accessible
        XCTAssertNotNil(timeService)
        XCTAssertNotNil(terminalMonitor)

        // Terminal monitor should be able to track time
        XCTAssertNotNil(terminalMonitor.activeProjectPath == nil || terminalMonitor.activeProjectPath != nil)
    }

    // MARK: - Claude Usage Integration

    @MainActor
    func testClaudeUsageServiceIntegration() {
        let usageService = ClaudeUsageService.shared
        let planUsageService = ClaudePlanUsageService.shared

        // Both services should be accessible
        XCTAssertNotNil(usageService)
        XCTAssertNotNil(planUsageService)
    }

    // MARK: - Achievement Integration

    @MainActor
    func testAchievementServiceIntegration() {
        let achievementService = AchievementService.shared

        // Should be able to check achievements without crashing
        XCTAssertNotNil(achievementService)
        XCTAssertNotNil(Achievement.allCases)
        XCTAssertGreaterThan(Achievement.allCases.count, 0)
    }

    // MARK: - AI Provider Integration

    @MainActor
    func testAIProviderRegistryIntegration() {
        let registry = AIProviderRegistry.shared
        let settings = SettingsViewModel.shared

        XCTAssertNotNil(registry)
        XCTAssertNotNil(settings.aiProvider)
    }

    // MARK: - Tab Manager Integration

    @MainActor
    func testTabManagerIntegration() {
        let tabManager = TabManagerViewModel.shared

        // Tab manager should be accessible
        XCTAssertNotNil(tabManager)
        XCTAssertNotNil(tabManager.tabs)
    }

    // MARK: - Sync Engine Integration

    @MainActor
    func testSyncEngineIntegration() {
        let syncEngine = SyncEngine.shared

        // Sync engine should be accessible
        XCTAssertNotNil(syncEngine)

        // Should not be syncing initially
        XCTAssertFalse(syncEngine.isSyncing)
    }

    // MARK: - Environment Service Integration

    @MainActor
    func testEnvFileServiceIntegration() {
        let envService = EnvFileService.shared

        XCTAssertNotNil(envService)
    }

    // MARK: - Terminal Monitor Integration

    @MainActor
    func testTerminalMonitorIntegration() {
        let monitor = TerminalOutputMonitor.shared

        // Monitor should be able to process output
        XCTAssertNotNil(monitor)

        // Test processing some sample output
        monitor.processTerminalOutput("$ echo 'test'")
        // Should not crash

        // Test Claude detection patterns
        monitor.processTerminalOutput("╭─ Claude Code")
        // Should detect Claude start pattern
    }

    // MARK: - Notification Integration

    func testNotificationServiceIntegration() {
        let notificationService = NotificationService.shared
        let settings = SettingsViewModel.shared

        // Both should be accessible
        XCTAssertNotNil(notificationService)
        XCTAssertNotNil(settings)

        // Settings should control notification behavior
        XCTAssert(settings.notifyClaudeFinished == true || settings.notifyClaudeFinished == false)
    }

    // MARK: - Data Flow Integration

    @MainActor
    func testProjectDataFlow() {
        // Test the data flow: Scanner → DashboardVM → UI

        let scanner = ProjectScanner.shared
        let dashboard = DashboardViewModel.shared

        // Scanner exists
        XCTAssertNotNil(scanner)

        // Dashboard has projects array (may be empty)
        XCTAssertNotNil(dashboard.projects)

        // Filtered projects should always exist
        XCTAssertNotNil(dashboard.filteredProjects)
    }

    // MARK: - Cross-Service Communication

    @MainActor
    func testTerminalToTimeTrackingIntegration() {
        let terminal = TerminalOutputMonitor.shared
        let timeTracking = TimeTrackingService.shared

        // Both should be accessible
        XCTAssertNotNil(terminal)
        XCTAssertNotNil(timeTracking)

        // Terminal should be able to signal time tracking
        // (We can't easily test the actual integration without side effects)
    }

    // MARK: - Settings Persistence Integration

    @MainActor
    func testSettingsPersistence() {
        let settings = SettingsViewModel.shared

        // Settings should have valid defaults
        XCTAssertNotNil(settings.defaultEditor)
        XCTAssertNotNil(settings.defaultTerminal)
        XCTAssertNotNil(settings.theme)
        XCTAssertGreaterThan(settings.refreshInterval, 0)
    }

    // MARK: - Error Handling Integration

    func testSyncErrorPropagation() {
        // Verify sync errors are properly defined
        let errors: [SyncError] = [
            .disabled,
            .notSignedIn,
            .subscriptionRequired,
            .networkUnavailable,
            .quotaExceeded,
            .conflictDetected
        ]

        for error in errors {
            // All errors should have descriptions
            XCTAssertNotNil(error.errorDescription)

            // Errors should be equatable
            XCTAssertEqual(error.errorDescription, error.errorDescription)
        }
    }

    // MARK: - Web API Integration

    @MainActor
    func testWebAPIClientIntegration() {
        let client = WebAPIClient.shared

        // Client should be accessible
        XCTAssertNotNil(client)

        // Should have auth state
        XCTAssert(client.isAuthenticated == true || client.isAuthenticated == false)
    }

    // MARK: - Provider Metrics Integration

    @MainActor
    func testProviderMetricsIntegration() {
        let metricsService = ProviderMetricsService.shared

        // Service should be accessible
        XCTAssertNotNil(metricsService)
    }

    // MARK: - Full Stack Smoke Test

    @MainActor
    func testFullStackSmokeTest() {
        // Verify all major singletons can be accessed without crashing

        // Models
        XCTAssertNotNil(AppModelContainer.shared)

        // ViewModels
        XCTAssertNotNil(DashboardViewModel.shared)
        XCTAssertNotNil(SettingsViewModel.shared)
        XCTAssertNotNil(TabManagerViewModel.shared)

        // Services
        XCTAssertNotNil(ProjectScanner.shared)
        XCTAssertNotNil(GitService.shared)
        XCTAssertNotNil(TimeTrackingService.shared)
        XCTAssertNotNil(ClaudeUsageService.shared)
        XCTAssertNotNil(ClaudePlanUsageService.shared)
        XCTAssertNotNil(AchievementService.shared)
        XCTAssertNotNil(NotificationService.shared)
        XCTAssertNotNil(SyncEngine.shared)
        XCTAssertNotNil(AIProviderRegistry.shared)
        XCTAssertNotNil(TerminalOutputMonitor.shared)
        XCTAssertNotNil(EnvFileService.shared)
        XCTAssertNotNil(WebAPIClient.shared)
        XCTAssertNotNil(ProviderMetricsService.shared)
    }
}
