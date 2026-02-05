import AppKit
import Foundation
import SwiftTerm

enum TerminalTabKind: String, Codable {
    case shell
    case claude
    case ccYolo
    case codex
    case devServer
    case ghost
}

enum TerminalTabStatus: String {
    case idle
    case working
    case error
    case needsAttention
}

@MainActor
final class TerminalTabItem: ObservableObject, Identifiable {
    let id: UUID
    let kind: TerminalTabKind
    @Published var title: String
    @Published var status: TerminalTabStatus = .idle
    @Published var port: Int?
    @Published var commandHistory: [String] = []

    var devCommand: String?
    var isGhost: Bool
    var startTime: Date?

    // AI Provider settings for this tab
    @Published var aiProvider: AIProviderType = .claudeCode
    @Published var aiModel: AIModel = .claudeSonnet4
    @Published var thinkingLevel: ThinkingLevel = .none

    // Strong reference to keep terminal view alive across tab switches
    fileprivate var terminalView: LocalProcessTerminalView?
    fileprivate var pendingCommands: [String] = []

    private var lastOutputAt: Date?
    private var lastPromptAt: Date?
    private var lastInputAt: Date?
    private var lastErrorAt: Date?
    private var hasNewOutputSinceInput = false
    private var followTimer: Timer?
    private var ghostCloseDeadline: Date?
    private var hasNotifiedAttention = false
    private var hasNotifiedServerStart = false

    init(id: UUID = UUID(), kind: TerminalTabKind, title: String, isGhost: Bool = false,
         aiProvider: AIProviderType = .claudeCode, aiModel: AIModel = .claudeSonnet4, thinkingLevel: ThinkingLevel = .none) {
        self.id = id
        self.kind = kind
        self.title = title
        self.isGhost = isGhost
        self.aiProvider = aiProvider
        self.aiModel = aiModel
        self.thinkingLevel = thinkingLevel
    }

    /// Returns existing terminal view if already attached, nil otherwise
    var existingTerminalView: LocalProcessTerminalView? {
        terminalView
    }

    /// Returns true if terminal view is already attached
    var hasTerminalView: Bool {
        terminalView != nil
    }

    func attach(_ terminalView: LocalProcessTerminalView) {
        self.terminalView = terminalView
        startFollowTimer()

        if !pendingCommands.isEmpty {
            for command in pendingCommands {
                sendCommand(command)
            }
            pendingCommands.removeAll()
        }
    }

    func enqueueCommand(_ command: String) {
        if terminalView == nil {
            pendingCommands.append(command)
        } else {
            sendCommand(command)
        }
    }

    func sendCommand(_ command: String) {
        guard let terminalView else {
            print("[Terminal] ⏳ No terminal view yet, queuing command")
            pendingCommands.append(command)
            return
        }

        lastInputAt = Date()
        hasNewOutputSinceInput = false
        hasNotifiedAttention = false
        ghostCloseDeadline = nil

        recordCommand(command)
        // Use carriage return (\r) which is what Enter key sends in terminals
        let textWithReturn = command + "\r"
        if let data = textWithReturn.data(using: .utf8) {
            terminalView.send([UInt8](data))
        }
        print("[Terminal] ✅ Sent \(textWithReturn.count) chars to terminal")

        if kind == .devServer {
            startTime = Date()
        }
    }

    func sendControlC() {
        guard let terminalView else { return }
        terminalView.send([0x03])  // ETX (Ctrl+C)
    }

    func markViewed() {
        if status == .needsAttention {
            status = .idle
        }
        hasNewOutputSinceInput = false
        hasNotifiedAttention = false
    }

    func recordOutput(_ chunk: String) {
        let clean = TerminalTabItem.stripAnsiCodes(chunk)
        let now = Date()
        lastOutputAt = now

        if containsPrompt(clean) {
            lastPromptAt = now
            if let lastInputAt, now >= lastInputAt {
                hasNewOutputSinceInput = true
            }
        }

        if port == nil, let detected = TerminalTabItem.detectPort(in: clean) {
            port = detected
            if kind == .devServer, SettingsViewModel.shared.notifyServerStart, !hasNotifiedServerStart {
                NotificationService.shared.sendNotification(
                    title: "Dev server started",
                    message: "\(title) is running on localhost:\(detected)."
                )
                hasNotifiedServerStart = true
            }
        }

        if clean.localizedCaseInsensitiveContains("error") || clean.localizedCaseInsensitiveContains("failed") {
            lastErrorAt = now
        }
    }

    func updateStatus(now: Date, notifyOnAttention: Bool) {
        if let lastErrorAt, lastErrorAt >= (lastInputAt ?? .distantPast) {
            status = .error
        } else if let lastOutputAt, now.timeIntervalSince(lastOutputAt) < 1.2 {
            status = .working
        } else if hasNewOutputSinceInput, lastPromptAt != nil {
            status = .needsAttention
        } else {
            status = .idle
        }

        if isGhost, (status == .idle || status == .needsAttention) {
            if ghostCloseDeadline == nil {
                ghostCloseDeadline = now.addingTimeInterval(30)
            }
        }

        if status == .needsAttention, notifyOnAttention, !hasNotifiedAttention {
            NotificationService.shared.sendNotification(
                title: "Claude finished",
                message: "\(title) is ready for review."
            )
            hasNotifiedAttention = true
        }
    }

    func shouldCloseGhost(now: Date) -> Bool {
        guard isGhost, let ghostCloseDeadline else { return false }
        return now >= ghostCloseDeadline && status != .working
    }

    func clearOutput() {
        sendCommand("clear")
    }

    func reset() {
        followTimer?.invalidate()
        followTimer = nil
        terminalView = nil
    }

    private func recordCommand(_ command: String) {
        commandHistory.insert(command, at: 0)
        if commandHistory.count > 10 {
            commandHistory = Array(commandHistory.prefix(10))
        }
    }

    private func startFollowTimer() {
        followTimer?.invalidate()
        followTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let terminalView = self.terminalView else { return }

                let atBottom = !terminalView.canScroll || terminalView.scrollPosition >= 0.99
                if atBottom && terminalView.scrollPosition < 0.999 {
                    terminalView.scroll(toPosition: 1)
                }
            }
        }
    }

    private func containsPrompt(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("$") || trimmed.hasSuffix("%") || trimmed.hasSuffix(">") {
            return true
        }
        return false
    }

    static func detectPort(in text: String) -> Int? {
        let patterns = [
            "localhost:(\\d{2,5})",
            "127\\.0\\.0\\.1:(\\d{2,5})",
            "0\\.0\\.0\\.0:(\\d{2,5})",
            "port\\s+(\\d{2,5})",
            "ready on port\\s+(\\d{2,5})"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 2 {
                if let portRange = Range(match.range(at: 1), in: text) {
                    return Int(text[portRange])
                }
            }
        }

        return nil
    }

    static func stripAnsiCodes(_ string: String) -> String {
        let pattern = "\\x1B\\[[0-9;]*[a-zA-Z]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: "")
    }
}

@MainActor
final class TerminalTabsViewModel: ObservableObject {
    static let shared = TerminalTabsViewModel()

    // Store tabs and active tab PER PROJECT PATH - persists across tab switches
    @Published private var tabsByProject: [String: [TerminalTabItem]] = [:]
    @Published private var activeTabByProject: [String: UUID] = [:]

    // Current project path for convenience (set when view appears)
    @Published var currentProjectPath: String = ""

    private var statusTimer: Timer?

    private init() {
        startStatusTimer()
    }

    // MARK: - Per-Project Accessors

    var tabs: [TerminalTabItem] {
        get { tabsByProject[currentProjectPath] ?? [] }
        set { tabsByProject[currentProjectPath] = newValue }
    }

    var activeTabID: UUID {
        get { activeTabByProject[currentProjectPath] ?? UUID() }
        set { activeTabByProject[currentProjectPath] = newValue }
    }

    func setProject(_ path: URL) {
        let pathString = path.path
        currentProjectPath = pathString

        // Initialize tabs for this project if not already present
        if tabsByProject[pathString] == nil {
            let baseTab = TerminalTabItem(kind: .shell, title: "Terminal")
            tabsByProject[pathString] = [baseTab]
            activeTabByProject[pathString] = baseTab.id
        }
    }

    func tabs(for projectPath: String) -> [TerminalTabItem] {
        return tabsByProject[projectPath] ?? []
    }

    func activeTab(for projectPath: String) -> UUID? {
        return activeTabByProject[projectPath]
    }

    // Convenience property to get current project path as URL
    var projectPath: URL {
        URL(fileURLWithPath: currentProjectPath)
    }

    var activeTab: TerminalTabItem? {
        tabs.first { $0.id == activeTabID }
    }

    var runningServers: [TerminalTabItem] {
        tabs.filter { $0.kind == .devServer && $0.startTime != nil }
    }

    func selectTab(_ tab: TerminalTabItem) {
        activeTabID = tab.id
        tab.markViewed()
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        selectTab(tabs[index])
    }

    func addClaudeTab() {
        let settings = SettingsViewModel.shared
        let model = settings.terminalClaudeModel
        let thinking = settings.defaultThinkingLevel
        var command = ThinkingLevelService.shared.generateClaudeCommand(
            model: model,
            thinkingLevel: thinking,
            dangerouslySkipPermissions: false
        )
        // Append extra flags if configured
        let extraFlags = settings.terminalClaudeFlags.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extraFlags.isEmpty {
            command += " \(extraFlags)"
        }
        addTab(kind: .claude, title: "Claude", command: command, aiModel: model, thinkingLevel: thinking)
    }

    func addCcYoloTab() {
        let settings = SettingsViewModel.shared
        let model = settings.terminalCcyoloModel
        let thinking = settings.defaultThinkingLevel
        let command = ThinkingLevelService.shared.generateClaudeCommand(
            model: model,
            thinkingLevel: thinking,
            dangerouslySkipPermissions: true
        )
        addTab(kind: .ccYolo, title: "ccYOLO", command: command, aiModel: model, thinkingLevel: thinking)
    }

    func addCodexTab() {
        let codexModel = SettingsViewModel.shared.terminalCodexModel
        let command = codexModel.isEmpty ? "codex" : "codex --model \(codexModel)"
        addTab(kind: .codex, title: "Codex", command: command, aiProvider: .codex)
    }

    func addCodexFullAutoTab() {
        let codexModel = SettingsViewModel.shared.terminalCodexModel
        let command = codexModel.isEmpty ? "codex --full-auto" : "codex --model \(codexModel) --full-auto"
        addTab(kind: .codex, title: "Codex Auto", command: command, aiProvider: .codex)
    }

    func addDevServerTab(command: String) {
        addTab(kind: .devServer, title: "Dev Server", command: command)
    }

    func addGhostDocUpdateTab() {
        let model = SettingsViewModel.shared.defaultModel
        let command = "claude --model \(model.rawValue) \"Read the current README.md, CHANGELOG.md, and codebase structure. Update the documentation to accurately reflect the current state. Be concise and accurate.\""
        let tab = TerminalTabItem(kind: .ghost, title: "Doc Update", isGhost: true, aiModel: model)
        tab.devCommand = command
        tabs.append(tab)
        tab.enqueueCommand(command)
    }

    /// Add a Claude tab with specific model and thinking level
    func addClaudeTabWithSettings(model: AIModel, thinkingLevel: ThinkingLevel) {
        let command = ThinkingLevelService.shared.generateClaudeCommand(
            model: model,
            thinkingLevel: thinkingLevel,
            dangerouslySkipPermissions: false
        )
        let titleSuffix = thinkingLevel != .none ? " (\(thinkingLevel.displayName))" : ""
        addTab(kind: .claude, title: "Claude\(titleSuffix)", command: command, aiModel: model, thinkingLevel: thinkingLevel)
    }

    func closeTab(_ tab: TerminalTabItem) {
        guard tab.kind != .shell else { return }
        tab.reset()
        tabs.removeAll { $0.id == tab.id }
        if activeTabID == tab.id, let first = tabs.first {
            activeTabID = first.id
        }
    }

    func closeActiveTab() {
        guard let activeTab else { return }
        closeTab(activeTab)
    }

    func clearActiveTab() {
        activeTab?.clearOutput()
    }

    func copyActiveDevServerURL() {
        guard let activeTab, activeTab.kind == .devServer, let port = activeTab.port else { return }
        let url = "http://localhost:\(port)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    func duplicateTab(_ tab: TerminalTabItem) {
        let newTab = TerminalTabItem(kind: tab.kind, title: tab.title,
                                     aiProvider: tab.aiProvider, aiModel: tab.aiModel, thinkingLevel: tab.thinkingLevel)
        newTab.devCommand = tab.devCommand
        tabs.append(newTab)
        activeTabID = newTab.id
        if let command = tab.devCommand {
            newTab.enqueueCommand(command)
        }
    }

    func renameTab(_ tab: TerminalTabItem, title: String) {
        tab.title = title
    }

    private func addTab(kind: TerminalTabKind, title: String, command: String?,
                        aiProvider: AIProviderType = .claudeCode, aiModel: AIModel = .claudeSonnet4, thinkingLevel: ThinkingLevel = .none) {
        let tab = TerminalTabItem(kind: kind, title: title,
                                  aiProvider: aiProvider, aiModel: aiModel, thinkingLevel: thinkingLevel)
        tab.devCommand = command
        tabs.append(tab)
        activeTabID = tab.id
        if let command {
            tab.enqueueCommand(command)
        }
    }

    private func startStatusTimer() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatuses()
            }
        }
    }

    private func refreshStatuses() {
        let now = Date()
        let notifyOnAttention = SettingsViewModel.shared.notifyClaudeFinished

        // Iterate over ALL projects' tabs to keep background terminals updated
        for (projectPath, projectTabs) in tabsByProject {
            for tab in projectTabs {
                tab.updateStatus(now: now, notifyOnAttention: notifyOnAttention && (tab.kind == .claude || tab.kind == .ccYolo || tab.kind == .codex || tab.kind == .ghost))
            }

            let ghostsToClose = projectTabs.filter { $0.shouldCloseGhost(now: now) }
            for tab in ghostsToClose {
                // Close ghost tabs for this specific project
                tab.reset()
                tabsByProject[projectPath]?.removeAll { $0.id == tab.id }
            }
        }
    }
}
