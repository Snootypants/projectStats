import AppKit
import Foundation
import SwiftUI
import ServiceManagement

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

    @AppStorage("codeDirectoryPath") private var codeDirectoryPath: String = ""
    @AppStorage("defaultEditorRaw") private var defaultEditorRaw: String = Editor.vscode.rawValue

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
    @AppStorage("defaultTerminalRaw") private var defaultTerminalRaw: String = Terminal.terminal.rawValue
    @AppStorage("refreshInterval") var refreshInterval: Int = 15
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }
    @AppStorage("showInDock") var showInDock: Bool = false
    @AppStorage("themeRaw") private var themeRaw: String = AppTheme.system.rawValue
    @AppStorage("sync_enabled") var syncEnabled: Bool = false  // Disabled by default

    @AppStorage("notifyClaudeFinished") var notifyClaudeFinished: Bool = true
    @AppStorage("playSoundOnClaudeFinished") var playSoundOnClaudeFinished: Bool = true
    @AppStorage("notificationSound") var notificationSound: String = "Ping"
    @AppStorage("notifyBuildComplete") var notifyBuildComplete: Bool = true
    @AppStorage("notifyServerStart") var notifyServerStart: Bool = true
    @AppStorage("notifyContextHigh") var notifyContextHigh: Bool = true
    @AppStorage("notifyPlanUsageHigh") var notifyPlanUsageHigh: Bool = true
    @AppStorage("notifyGitPushCompleted") var notifyGitPushCompleted: Bool = false
    @AppStorage("notifyAchievementUnlocked") var notifyAchievementUnlocked: Bool = false
    @AppStorage("pushNotificationsEnabled") var pushNotificationsEnabled: Bool = false
    @AppStorage("ntfyTopic") var ntfyTopic: String = ""

    @AppStorage("messaging.service") private var messagingServiceRaw: String = MessagingServiceType.telegram.rawValue
    @AppStorage("messaging.telegram.token") var telegramBotToken: String = ""
    @AppStorage("messaging.telegram.chat") var telegramChatId: String = ""
    @AppStorage("messaging.slack.webhook") var slackWebhookURL: String = ""
    @AppStorage("messaging.discord.webhook") var discordWebhookURL: String = ""
    @AppStorage("messaging.ntfy.topic") var messagingNtfyTopic: String = ""
    @AppStorage("messaging.notifications.enabled") var messagingNotificationsEnabled: Bool = false
    @AppStorage("messaging.remote.enabled") var remoteCommandsEnabled: Bool = false {
        didSet {
            startRemotePollingIfNeeded()
        }
    }
    @AppStorage("messaging.remote.interval") var remoteCommandsInterval: Int = 30 {
        didSet {
            startRemotePollingIfNeeded()
        }
    }

    @AppStorage("ai.provider") private var aiProviderRaw: String = AIProvider.anthropic.rawValue
    @AppStorage("ai.model") var aiModel: String = "claude-3-5-sonnet-latest"

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
    @AppStorage("ai.baseUrl") var aiBaseURL: String = ""

    // AI Model & Thinking Settings
    @AppStorage("ai.defaultModel") var defaultModelRaw: String = "claude-sonnet-4-5-20250514"
    @AppStorage("ai.defaultThinkingLevel") var defaultThinkingLevelRaw: String = "none"
    @AppStorage("ai.showModelInToolbar") var showModelInToolbar: Bool = true

    // IDE Tab visibility
    @AppStorage("showPromptsTab") var showPromptsTab: Bool = true
    @AppStorage("showDiffsTab") var showDiffsTab: Bool = true
    @AppStorage("showEnvironmentTab") var showEnvironmentTab: Bool = true

    // MARK: - Claude Usage Display Settings
    @AppStorage("ccusage_showCost") var ccusageShowCost: Bool = true
    @AppStorage("ccusage_showChart") var ccusageShowChart: Bool = true
    @AppStorage("ccusage_showInputTokens") var ccusageShowInputTokens: Bool = false
    @AppStorage("ccusage_showOutputTokens") var ccusageShowOutputTokens: Bool = false
    @AppStorage("ccusage_showCacheTokens") var ccusageShowCacheTokens: Bool = false
    @AppStorage("ccusage_showModelBreakdown") var ccusageShowModelBreakdown: Bool = false
    @AppStorage("ccusage_daysToShow") var ccusageDaysToShow: Int = 7

    // MARK: - API Keys (stored in Keychain for security)
    @AppStorage("elevenLabs_voiceId") var elevenLabsVoiceId: String = ""

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
    @AppStorage("tts_enabled") var ttsEnabled: Bool = false
    @AppStorage("tts_provider") var ttsProvider: String = "openai"
    @AppStorage("voice_autoTranscribe") var voiceAutoTranscribe: Bool = true

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
        get { AIModel(rawValue: defaultModelRaw) ?? .claudeSonnet4_5 }
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
            print("Failed to update launch at login: \(error)")
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
