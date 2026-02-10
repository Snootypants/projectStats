import AppKit
import Foundation
import SwiftUI
import ServiceManagement
import os.log

enum Editor: String, CaseIterable, Codable {
    case vscode = "Visual Studio Code"
    case xcode = "Xcode"
    case cursor = "Cursor"
    case sublime = "Sublime Text"
    case finder = "Finder"

    var icon: String {
        switch self {
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .xcode: return "hammer"
        case .cursor: return "cursorarrow"
        case .sublime: return "text.alignleft"
        case .finder: return "folder"
        }
    }
}

enum Terminal: String, CaseIterable, Codable {
    case terminal = "Terminal"
    case iterm = "iTerm"
    case warp = "Warp"
}

enum AppTheme: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()
    private let store = SettingsStoreService.shared

    @AppStorage(AppStorageKeys.codeDirectoryPath) private var codeDirectoryPath: String = ""
    @AppStorage(AppStorageKeys.defaultEditorRaw) private var defaultEditorRaw: String = Editor.vscode.rawValue

    var githubToken: String {
        get { KeychainService.shared.get(key: "githubToken") ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.shared.delete(key: "githubToken")
            } else {
                KeychainService.shared.save(key: "githubToken", value: newValue)
            }
            objectWillChange.send()
        }
    }
    @AppStorage(AppStorageKeys.defaultTerminalRaw) private var defaultTerminalRaw: String = Terminal.terminal.rawValue
    @AppStorage(AppStorageKeys.refreshInterval) var refreshInterval: Int = 15
    @AppStorage(AppStorageKeys.launchAtLogin) var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }
    @AppStorage(AppStorageKeys.showInDock) var showInDock: Bool = false
    @AppStorage(AppStorageKeys.themeRaw) private var themeRaw: String = AppTheme.system.rawValue
    @AppStorage(AppStorageKeys.syncEnabled) var syncEnabled: Bool = false  // Disabled by default

    @AppStorage(AppStorageKeys.notifyClaudeFinished) var notifyClaudeFinished: Bool = true
    @AppStorage(AppStorageKeys.playSoundOnClaudeFinished) var playSoundOnClaudeFinished: Bool = true
    @AppStorage(AppStorageKeys.notificationSound) var notificationSound: String = "Ping"
    @AppStorage(AppStorageKeys.notifyBuildComplete) var notifyBuildComplete: Bool = true
    @AppStorage(AppStorageKeys.notifyServerStart) var notifyServerStart: Bool = true
    @AppStorage(AppStorageKeys.notifyContextHigh) var notifyContextHigh: Bool = true
    @AppStorage(AppStorageKeys.notifyPlanUsageHigh) var notifyPlanUsageHigh: Bool = true
    @AppStorage(AppStorageKeys.notifyGitPushCompleted) var notifyGitPushCompleted: Bool = false
    @AppStorage(AppStorageKeys.notifyAchievementUnlocked) var notifyAchievementUnlocked: Bool = false
    @AppStorage(AppStorageKeys.pushNotificationsEnabled) var pushNotificationsEnabled: Bool = false
    @AppStorage(AppStorageKeys.ntfyTopic) var ntfyTopic: String = ""

    @AppStorage(AppStorageKeys.messagingService) private var messagingServiceRaw: String = MessagingServiceType.telegram.rawValue
    @AppStorage(AppStorageKeys.messagingTelegramToken) var telegramBotToken: String = ""
    @AppStorage(AppStorageKeys.messagingTelegramChat) var telegramChatId: String = ""
    @AppStorage(AppStorageKeys.messagingSlackWebhook) var slackWebhookURL: String = ""
    @AppStorage(AppStorageKeys.messagingDiscordWebhook) var discordWebhookURL: String = ""
    @AppStorage(AppStorageKeys.messagingNtfyTopic) var messagingNtfyTopic: String = ""
    @AppStorage(AppStorageKeys.messagingNotificationsEnabled) var messagingNotificationsEnabled: Bool = false
    @AppStorage(AppStorageKeys.messagingRemoteEnabled) var remoteCommandsEnabled: Bool = false {
        didSet {
            startRemotePollingIfNeeded()
        }
    }
    @AppStorage(AppStorageKeys.messagingRemoteInterval) var remoteCommandsInterval: Int = 30 {
        didSet {
            startRemotePollingIfNeeded()
        }
    }

    @AppStorage(AppStorageKeys.aiProvider) private var aiProviderRaw: String = AIProvider.anthropic.rawValue
    @AppStorage(AppStorageKeys.aiModel) var aiModel: String = "claude-sonnet-4-20250514"

    var aiApiKey: String {
        get { KeychainService.shared.get(key: "ai.apiKey") ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.shared.delete(key: "ai.apiKey")
            } else {
                KeychainService.shared.save(key: "ai.apiKey", value: newValue)
            }
            objectWillChange.send()
        }
    }
    @AppStorage(AppStorageKeys.aiBaseURL) var aiBaseURL: String = ""

    // AI Model & Thinking Settings
    @AppStorage(AppStorageKeys.aiDefaultModel) var defaultModelRaw: String = "claude-sonnet-4-20250514"
    @AppStorage(AppStorageKeys.aiDefaultThinkingLevel) var defaultThinkingLevelRaw: String = "none"
    @AppStorage(AppStorageKeys.aiShowModelInToolbar) var showModelInToolbar: Bool = true

    // IDE Tab visibility
    @AppStorage(AppStorageKeys.showPromptsTab) var showPromptsTab: Bool = true
    @AppStorage(AppStorageKeys.showDiffsTab) var showDiffsTab: Bool = true
    @AppStorage(AppStorageKeys.showEnvironmentTab) var showEnvironmentTab: Bool = true

    // MARK: - Agent Teams (Swarm) Settings
    @AppStorage(AppStorageKeys.agentTeamsEnabled) var agentTeamsEnabled: Bool = false

    // MARK: - Terminal Button Settings
    @AppStorage(AppStorageKeys.terminalClaudeModel) var terminalClaudeModelRaw: String = "claude-opus-4-6"
    @AppStorage(AppStorageKeys.terminalClaudeFlags) var terminalClaudeFlags: String = ""
    @AppStorage(AppStorageKeys.terminalCcyoloModel) var terminalCcyoloModelRaw: String = "claude-opus-4-6"
    @AppStorage(AppStorageKeys.terminalCodexModel) var terminalCodexModel: String = "codex"
    @AppStorage(AppStorageKeys.terminalShowClaudeButton) var showClaudeButton: Bool = true
    @AppStorage(AppStorageKeys.terminalShowCcyoloButton) var showCcyoloButton: Bool = true
    @AppStorage(AppStorageKeys.terminalShowCodexButton) var showCodexButton: Bool = true

    var terminalClaudeModel: AIModel {
        get { AIModel(rawValue: terminalClaudeModelRaw) ?? .claudeOpus46 }
        set { terminalClaudeModelRaw = newValue.rawValue }
    }

    var terminalCcyoloModel: AIModel {
        get { AIModel(rawValue: terminalCcyoloModelRaw) ?? .claudeOpus46 }
        set { terminalCcyoloModelRaw = newValue.rawValue }
    }

    // MARK: - Home Page Layout
    @AppStorage(AppStorageKeys.homePageLayout) var homePageLayout: String = "v5"
    // Available: "v1" (classic), "v2" (refined)
    @AppStorage(AppStorageKeys.chartTimeRange) var chartTimeRange: String = "week"
    // Available: "week", "month", "quarter", "year"
    @AppStorage(AppStorageKeys.chartDataType) var chartDataType: String = "lines"
    // Available: "lines", "commits"

    // MARK: - Claude Usage Display Settings
    @AppStorage(AppStorageKeys.ccusageShowCost) var ccusageShowCost: Bool = true
    @AppStorage(AppStorageKeys.ccusageShowChart) var ccusageShowChart: Bool = true
    @AppStorage(AppStorageKeys.ccusageShowInputTokens) var ccusageShowInputTokens: Bool = false
    @AppStorage(AppStorageKeys.ccusageShowOutputTokens) var ccusageShowOutputTokens: Bool = false
    @AppStorage(AppStorageKeys.ccusageShowCacheTokens) var ccusageShowCacheTokens: Bool = false
    @AppStorage(AppStorageKeys.ccusageShowModelBreakdown) var ccusageShowModelBreakdown: Bool = false
    @AppStorage(AppStorageKeys.ccusageDaysToShow) var ccusageDaysToShow: Int = 7

    // MARK: - API Keys (stored in Keychain for security)
    @AppStorage(AppStorageKeys.elevenLabsVoiceId) var elevenLabsVoiceId: String = ""

    var openAIApiKey: String {
        get { KeychainService.shared.get(key: "openai_apiKey") ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.shared.delete(key: "openai_apiKey")
            } else {
                KeychainService.shared.save(key: "openai_apiKey", value: newValue)
            }
            objectWillChange.send()
        }
    }

    var elevenLabsApiKey: String {
        get { KeychainService.shared.get(key: "elevenLabs_apiKey") ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.shared.delete(key: "elevenLabs_apiKey")
            } else {
                KeychainService.shared.save(key: "elevenLabs_apiKey", value: newValue)
            }
            objectWillChange.send()
        }
    }

    // MARK: - Voice
    @AppStorage(AppStorageKeys.ttsEnabled) var ttsEnabled: Bool = false
    @AppStorage(AppStorageKeys.ttsProvider) var ttsProvider: String = "openai"
    @AppStorage(AppStorageKeys.voiceAutoTranscribe) var voiceAutoTranscribe: Bool = true

    // Focus Mode
    @AppStorage(AppStorageKeys.focusModeEdgeFXMode) var focusModeEdgeFXRaw: String = "fire"

    // Custom Project Paths
    @AppStorage(AppStorageKeys.customProjectPaths) var customProjectPathsJSON: String = "[]"

    var customProjectPaths: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(customProjectPathsJSON.utf8))) ?? [] }
        set { customProjectPathsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    func addCustomProjectPath(_ path: String) {
        var paths = customProjectPaths
        if !paths.contains(path) {
            paths.append(path)
            customProjectPaths = paths
        }
    }

    // Lockout Bar Colors
    @AppStorage(AppStorageKeys.lockoutBarSessionColor) var sessionBarColorHex: String = "#3B82F6"
    @AppStorage(AppStorageKeys.lockoutBarWeeklyColor) var weeklyBarColorHex: String = "#3B82F6"
    @AppStorage(AppStorageKeys.lockoutBarWarningColor) var warningBarColorHex: String = "#EF4444"

    var focusModeEdgeFX: EdgeFXOverlay.Mode {
        get {
            switch focusModeEdgeFXRaw {
            case "smoke": return .smoke
            case "cubes": return .cubes
            default: return .fire
            }
        }
        set {
            switch newValue {
            case .fire: focusModeEdgeFXRaw = "fire"
            case .smoke: focusModeEdgeFXRaw = "smoke"
            case .cubes: focusModeEdgeFXRaw = "cubes"
            }
        }
    }

    var codeDirectory: URL {
        get {
            if codeDirectoryPath.isEmpty {
                return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code")
            }
            return URL(fileURLWithPath: codeDirectoryPath)
        }
        set {
            codeDirectoryPath = newValue.path
        }
    }

    var defaultEditor: Editor {
        get { Editor(rawValue: defaultEditorRaw) ?? .vscode }
        set {
            defaultEditorRaw = newValue.rawValue
        }
    }

    var defaultTerminal: Terminal {
        get { Terminal(rawValue: defaultTerminalRaw) ?? .terminal }
        set {
            defaultTerminalRaw = newValue.rawValue
        }
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .system }
        set {
            themeRaw = newValue.rawValue
            applyTheme()
        }
    }

    var messagingServiceType: MessagingServiceType {
        get { MessagingServiceType(rawValue: messagingServiceRaw) ?? .telegram }
        set {
            messagingServiceRaw = newValue.rawValue
        }
    }

    var aiProvider: AIProvider {
        get { AIProvider(rawValue: aiProviderRaw) ?? .anthropic }
        set {
            aiProviderRaw = newValue.rawValue
        }
    }

    var defaultModel: AIModel {
        get { AIModel(rawValue: defaultModelRaw) ?? .claudeSonnet4 }
        set {
            defaultModelRaw = newValue.rawValue
        }
    }

    var defaultThinkingLevel: ThinkingLevel {
        get { ThinkingLevel(rawValue: defaultThinkingLevelRaw) ?? .none }
        set {
            defaultThinkingLevelRaw = newValue.rawValue
        }
    }

    @MainActor func migrateSettingsToDBIfNeeded() {
        let migrated = store.getBool("settings.migrated")
        guard !migrated else { return }

        // Migrate basic settings from UserDefaults
        let keysToMigrate = [
            "codeDirectoryPath",
            "defaultEditorRaw",
            "defaultTerminalRaw",
            "refreshInterval",
            "launchAtLogin",
            "showInDock",
            "themeRaw",
            "homePageLayout",
            "showPromptsTab",
            "showDiffsTab",
            "showEnvironmentTab",
            "agentTeams.enabled",
            "focusMode.edgeFXMode"
        ]

        for key in keysToMigrate {
            if let value = UserDefaults.standard.string(forKey: key) {
                store.set(key, value: value)
            }
        }

        store.set("settings.migrated", value: true)
    }

    private init() {
        // Theme will be applied when app is ready
    }

    private func startRemotePollingIfNeeded() {
        Task { @MainActor in
            MessagingService.shared.startPollingIfNeeded()
        }
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.general.error("Failed to update launch at login: \(error)")
        }
    }

    private func applyTheme() {
        guard let app = NSApp else { return }

        switch theme {
        case .system:
            app.appearance = nil
        case .light:
            app.appearance = NSAppearance(named: .aqua)
        case .dark:
            app.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func applyThemeIfNeeded() {
        applyTheme()
    }

    func selectCodeDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your code directory"

        if panel.runModal() == .OK, let url = panel.url {
            codeDirectory = url
        }
    }

    func openInTerminal(_ path: URL) {
        let terminalApp: String

        switch defaultTerminal {
        case .terminal:
            terminalApp = "Terminal"
        case .iterm:
            terminalApp = "iTerm"
        case .warp:
            terminalApp = "Warp"
        }

        Shell.run("open -a \"\(terminalApp)\" \"\(path.path)\"")
    }

    func testNotification() {
        NotificationService.shared.sendNotification(title: "ProjectStats", message: "Test notification sent.")
    }
}
