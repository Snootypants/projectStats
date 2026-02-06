import XCTest
@testable import projectStats

/// Tests for ViewModel classes
final class ViewModelTests: XCTestCase {

    // MARK: - DashboardViewModel Tests

    @MainActor
    func testDashboardViewModelSingleton() {
        let instance1 = DashboardViewModel.shared
        let instance2 = DashboardViewModel.shared
        XCTAssertIdentical(instance1, instance2)
    }

    @MainActor
    func testDashboardViewModelInitialState() {
        let vm = DashboardViewModel.shared
        // Initial state checks
        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.projects)
    }

    @MainActor
    func testDashboardViewModelFilteredProjects() {
        let vm = DashboardViewModel.shared

        // Test search filter behavior
        vm.searchText = ""
        let unfilteredCount = vm.filteredProjects.count

        vm.searchText = "ZZZNONEXISTENT"
        let filteredCount = vm.filteredProjects.count

        // Filtered should be <= unfiltered
        XCTAssertLessThanOrEqual(filteredCount, unfilteredCount)
    }

    // MARK: - SettingsViewModel Tests

    @MainActor
    func testSettingsViewModelSingleton() {
        let instance1 = SettingsViewModel.shared
        let instance2 = SettingsViewModel.shared
        XCTAssertIdentical(instance1, instance2)
    }

    @MainActor
    func testSettingsViewModelDefaultEditor() {
        let vm = SettingsViewModel.shared

        // Default editor should be valid
        XCTAssertNotNil(vm.defaultEditor)
        XCTAssert(Editor.allCases.contains(vm.defaultEditor))
    }

    @MainActor
    func testSettingsViewModelDefaultTerminal() {
        let vm = SettingsViewModel.shared

        // Default terminal should be valid
        XCTAssertNotNil(vm.defaultTerminal)
        XCTAssert(Terminal.allCases.contains(vm.defaultTerminal))
    }

    @MainActor
    func testSettingsViewModelTheme() {
        let vm = SettingsViewModel.shared

        // Theme should be valid
        XCTAssertNotNil(vm.theme)
        XCTAssert(AppTheme.allCases.contains(vm.theme))
    }

    @MainActor
    func testSettingsViewModelRefreshInterval() {
        let vm = SettingsViewModel.shared

        // Refresh interval should be reasonable
        XCTAssertGreaterThan(vm.refreshInterval, 0)
        XCTAssertLessThanOrEqual(vm.refreshInterval, 3600) // Max 1 hour
    }

    @MainActor
    func testSettingsViewModelCodeDirectory() {
        let vm = SettingsViewModel.shared

        // Code directory should be a valid URL
        XCTAssertNotNil(vm.codeDirectory)
        XCTAssert(vm.codeDirectory.isFileURL)
    }

    @MainActor
    func testSettingsViewModelAIProvider() {
        let vm = SettingsViewModel.shared

        // AI provider should be valid
        XCTAssertNotNil(vm.aiProvider)
        XCTAssert(AIProvider.allCases.contains(vm.aiProvider))
    }

    @MainActor
    func testSettingsViewModelDefaultModel() {
        let vm = SettingsViewModel.shared

        // Default model should be valid
        XCTAssertNotNil(vm.defaultModel)
        XCTAssert(AIModel.allCases.contains(vm.defaultModel))
    }

    @MainActor
    func testSettingsViewModelDefaultThinkingLevel() {
        let vm = SettingsViewModel.shared

        // Default thinking level should be valid
        XCTAssertNotNil(vm.defaultThinkingLevel)
        XCTAssert(ThinkingLevel.allCases.contains(vm.defaultThinkingLevel))
    }

    // MARK: - TabManagerViewModel Tests

    @MainActor
    func testTabManagerViewModelSingleton() {
        let instance1 = TabManagerViewModel.shared
        let instance2 = TabManagerViewModel.shared
        XCTAssertIdentical(instance1, instance2)
    }

    @MainActor
    func testTabManagerViewModelTabs() {
        let vm = TabManagerViewModel.shared

        // Tabs array should exist
        XCTAssertNotNil(vm.tabs)
    }

    @MainActor
    func testTabManagerViewModelActiveTab() {
        let vm = TabManagerViewModel.shared

        // If there are tabs, active tab should be set
        if !vm.tabs.isEmpty {
            XCTAssertNotNil(vm.activeTab)
        }
    }

    // MARK: - EnvironmentViewModel Tests

    @MainActor
    func testEnvironmentViewModelInitialization() {
        let vm = EnvironmentViewModel()

        // Should initialize without crashing
        XCTAssertNotNil(vm)
        XCTAssertNotNil(vm.variables)
    }

    // MARK: - GitControlsViewModel Tests

    @MainActor
    func testGitControlsViewModelInitialization() {
        let vm = GitControlsViewModel(projectPath: "/test/path")

        XCTAssertNotNil(vm)
        XCTAssertEqual(vm.projectPath, "/test/path")
    }

    @MainActor
    func testGitControlsViewModelBranchState() {
        let vm = GitControlsViewModel(projectPath: "/test/path")

        // Branch should be initialized
        XCTAssertNotNil(vm.currentBranch)
    }

    // MARK: - TerminalTabsViewModel Tests

    @MainActor
    func testTerminalTabsViewModelInitialization() {
        let vm = TerminalTabsViewModel()

        XCTAssertNotNil(vm)
        XCTAssertNotNil(vm.tabs)
    }

    // MARK: - Editor Enum Tests

    func testEditorCases() {
        XCTAssertEqual(Editor.allCases.count, 5)
        XCTAssert(Editor.allCases.contains(.vscode))
        XCTAssert(Editor.allCases.contains(.xcode))
        XCTAssert(Editor.allCases.contains(.cursor))
        XCTAssert(Editor.allCases.contains(.sublime))
        XCTAssert(Editor.allCases.contains(.finder))
    }

    func testEditorIcons() {
        for editor in Editor.allCases {
            XCTAssertFalse(editor.icon.isEmpty)
        }
    }

    func testEditorRawValues() {
        XCTAssertEqual(Editor.vscode.rawValue, "Visual Studio Code")
        XCTAssertEqual(Editor.xcode.rawValue, "Xcode")
        XCTAssertEqual(Editor.cursor.rawValue, "Cursor")
        XCTAssertEqual(Editor.sublime.rawValue, "Sublime Text")
        XCTAssertEqual(Editor.finder.rawValue, "Finder")
    }

    // MARK: - Terminal Enum Tests

    func testTerminalCases() {
        XCTAssertEqual(Terminal.allCases.count, 3)
        XCTAssert(Terminal.allCases.contains(.terminal))
        XCTAssert(Terminal.allCases.contains(.iterm))
        XCTAssert(Terminal.allCases.contains(.warp))
    }

    func testTerminalRawValues() {
        XCTAssertEqual(Terminal.terminal.rawValue, "Terminal")
        XCTAssertEqual(Terminal.iterm.rawValue, "iTerm")
        XCTAssertEqual(Terminal.warp.rawValue, "Warp")
    }

    // MARK: - AppTheme Enum Tests

    func testAppThemeCases() {
        XCTAssertEqual(AppTheme.allCases.count, 3)
        XCTAssert(AppTheme.allCases.contains(.system))
        XCTAssert(AppTheme.allCases.contains(.light))
        XCTAssert(AppTheme.allCases.contains(.dark))
    }

    func testAppThemeRawValues() {
        XCTAssertEqual(AppTheme.system.rawValue, "System")
        XCTAssertEqual(AppTheme.light.rawValue, "Light")
        XCTAssertEqual(AppTheme.dark.rawValue, "Dark")
    }

    // MARK: - Focus Mode EdgeFX Preference Tests

    @MainActor
    func testFocusModeEdgeFXDefaultIsFire() {
        let settings = SettingsViewModel.shared
        // Default should be "fire"
        XCTAssertEqual(settings.focusModeEdgeFXRaw, "fire")
    }

    @MainActor
    func testFocusModeEdgeFXModeConversion() {
        let settings = SettingsViewModel.shared
        let original = settings.focusModeEdgeFXRaw
        defer { settings.focusModeEdgeFXRaw = original }

        settings.focusModeEdgeFXRaw = "smoke"
        // The computed property should return .smoke
        if case .smoke = settings.focusModeEdgeFX {} else {
            XCTFail("Expected .smoke mode")
        }

        settings.focusModeEdgeFXRaw = "cubes"
        if case .cubes = settings.focusModeEdgeFX {} else {
            XCTFail("Expected .cubes mode")
        }

        settings.focusModeEdgeFXRaw = "fire"
        if case .fire = settings.focusModeEdgeFX {} else {
            XCTFail("Expected .fire mode")
        }
    }
}
