import AppKit
import Foundation
import SwiftTerm

enum TerminalTabKind: String, Codable {
    case shell
    case claude
    case ccYolo
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

    fileprivate weak var terminalView: LocalProcessTerminalView?
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

    init(id: UUID = UUID(), kind: TerminalTabKind, title: String, isGhost: Bool = false) {
        self.id = id
        self.kind = kind
        self.title = title
        self.isGhost = isGhost
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
            pendingCommands.append(command)
            return
        }

        lastInputAt = Date()
        hasNewOutputSinceInput = false
        hasNotifiedAttention = false
        ghostCloseDeadline = nil

        recordCommand(command)
        terminalView.getTerminal().sendResponse(text: command + "\n")

        if kind == .devServer {
            startTime = Date()
        }
    }

    func sendControlC() {
        guard let terminalView else { return }
        terminalView.getTerminal().sendResponse(text: "\u{3}")
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
            guard let self, let terminalView = self.terminalView else { return }

            let atBottom = !terminalView.canScroll || terminalView.scrollPosition >= 0.99
            if atBottom && terminalView.scrollPosition < 0.999 {
                terminalView.scroll(toPosition: 1)
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
    @Published var tabs: [TerminalTabItem] = []
    @Published var activeTabID: UUID
    let projectPath: URL

    private var statusTimer: Timer?

    init(projectPath: URL) {
        self.projectPath = projectPath
        let baseTab = TerminalTabItem(kind: .shell, title: "Terminal")
        self.tabs = [baseTab]
        self.activeTabID = baseTab.id
        startStatusTimer()
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
        addTab(kind: .claude, title: "Claude", command: "claude")
    }

    func addCcYoloTab() {
        addTab(kind: .ccYolo, title: "ccYOLO", command: "claude --dangerously-skip-permissions")
    }

    func addDevServerTab(command: String) {
        addTab(kind: .devServer, title: "Dev Server", command: command)
    }

    func addGhostDocUpdateTab() {
        let command = "claude \"Read the current README.md, CHANGELOG.md, and codebase structure. Update the documentation to accurately reflect the current state. Be concise and accurate.\""
        let tab = TerminalTabItem(kind: .ghost, title: "Doc Update", isGhost: true)
        tab.devCommand = command
        tabs.append(tab)
        tab.enqueueCommand(command)
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
        let newTab = TerminalTabItem(kind: tab.kind, title: tab.title)
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

    private func addTab(kind: TerminalTabKind, title: String, command: String?) {
        let tab = TerminalTabItem(kind: kind, title: title)
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

        for tab in tabs {
            tab.updateStatus(now: now, notifyOnAttention: notifyOnAttention && (tab.kind == .claude || tab.kind == .ccYolo || tab.kind == .ghost))
        }
        let ghostsToClose = tabs.filter { $0.shouldCloseGhost(now: now) }
        for tab in ghostsToClose {
            closeTab(tab)
        }
    }
}
