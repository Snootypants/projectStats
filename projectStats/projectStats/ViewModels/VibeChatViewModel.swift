import Foundation
import SwiftUI

/// Shared store that keeps VibeChatViewModel instances alive across tab switches
@MainActor
final class VibeChatViewModelStore {
    static let shared = VibeChatViewModelStore()
    private var viewModels: [String: VibeChatViewModel] = [:]

    func viewModel(for projectPath: String) -> VibeChatViewModel {
        if let existing = viewModels[projectPath] {
            return existing
        }
        let vm = VibeChatViewModel(projectPath: projectPath)
        viewModels[projectPath] = vm
        return vm
    }
}

@MainActor
final class VibeChatViewModel: ObservableObject {
    let projectPath: String

    @Published var messages: [VibeChatMessage] = []
    @Published var sessionState: SessionState = .idle
    @Published var currentInput: String = ""
    @Published var elapsedTime: TimeInterval = 0
    @Published var toolCallCount: Int = 0
    @Published var isThinking: Bool = false
    @Published var autoApproveAll: Bool = false

    @AppStorage("vibePermissionMode") var permissionMode: String = PermissionMode.sansFlavor.rawValue

    var selectedPermissionMode: PermissionMode {
        get { PermissionMode(rawValue: permissionMode) ?? .sansFlavor }
        set { permissionMode = newValue.rawValue }
    }

    // Permission stats
    var approvalsGranted: Int {
        messages.filter { msg in
            if case .permissionRequest(_, _, _, let status) = msg.content {
                return status == .allowed || status == .autoApproved
            }
            return false
        }.count
    }

    var approvalsTotal: Int {
        messages.filter { msg in
            if case .permissionRequest = msg.content { return true }
            return false
        }.count
    }

    // Tool breakdown
    var toolBreakdown: [String: Int] {
        var counts: [String: Int] = [:]
        for msg in messages {
            if case .toolCall(let name, _, _, _, _) = msg.content {
                counts[name, default: 0] += 1
            }
        }
        return counts
    }

    private let processManager = ClaudeProcessManager()
    private var sessionTimer: Timer?
    private var sessionStartTime: Date?
    // Map tool_use_id to message index for attaching results
    private var toolUseIdToMessageIndex: [String: Int] = [:]
    // Track raw NDJSON lines for persistence
    var rawLines: [String] = []

    init(projectPath: String) {
        self.projectPath = projectPath
    }

    var claudeFound: Bool {
        processManager.claudeBinaryPath != nil
    }

    @Published var isReplayMode: Bool = false

    // MARK: - Session Control

    func startSession(appendSystemPrompt: String? = nil) {
        // Prevent double-starts while process is launching
        if sessionState == .running || sessionState == .thinking {
            print("[VibeChatVM] Already running, ignoring startSession()")
            return
        }

        messages = []
        toolCallCount = 0
        elapsedTime = 0
        rawLines = []
        toolUseIdToMessageIndex = [:]
        autoApproveAll = false
        isReplayMode = false
        sessionState = .running // Set immediately so Start button hides
        sessionStartTime = Date()

        startTimer()

        if let prompt = appendSystemPrompt {
            // Explicit prompt provided (e.g., from "Continue" session)
            launchProcess(appendSystemPrompt: prompt)
        } else {
            // Try automatic context injection from project memory
            Task {
                let context = await ContextBuilder.shared.buildContext(projectPath: projectPath)
                launchProcess(appendSystemPrompt: context)
            }
        }
    }

    private func launchProcess(appendSystemPrompt: String?) {
        processManager.start(
            projectPath: projectPath,
            permissionMode: selectedPermissionMode,
            appendSystemPrompt: appendSystemPrompt
        ) { [weak self] events in
            self?.handleEvents(events)
        }
    }

    /// Load a past session as read-only replay
    func loadSessionForReplay(session: ConversationSession) {
        messages = []
        toolCallCount = 0
        isReplayMode = true
        sessionState = .done

        guard let summary = loadSessionSummary(session: session) else {
            messages.append(.fromError("Could not load session summary"))
            return
        }

        // Parse the markdown summary back into messages
        for line in summary.components(separatedBy: "\n") {
            if line.hasPrefix("**User:**") {
                let text = String(line.dropFirst("**User:** ".count))
                messages.append(.fromUser(text))
            } else if line.hasPrefix("**Claude:**") {
                let text = String(line.dropFirst("**Claude:** ".count))
                messages.append(.fromAssistantText(text))
            } else if line.hasPrefix("> Tool:") {
                let text = String(line.dropFirst("> Tool: ".count))
                messages.append(.fromAssistantText("Tool: \(text)"))
            } else if line.hasPrefix("> Error:") {
                let text = String(line.dropFirst("> Error: ".count))
                messages.append(.fromError(text))
            }
        }

        // Add session stats at the end
        messages.append(VibeChatMessage(
            id: UUID(),
            timestamp: Date(),
            role: .system,
            content: .sessionStats(
                cost: String(format: "$%.4f", session.costUsd),
                duration: "\(session.durationMs / 1000)s",
                turns: session.numTurns,
                sessionId: session.sessionId
            )
        ))
    }

    /// Start a new session with context from a previous session
    func continueSession(session: ConversationSession) {
        guard let summary = loadSessionSummary(session: session) else {
            startSession()
            return
        }

        let contextPrompt = """
        You are continuing a previous session on this project. Here's what was discussed:

        \(summary)

        Continue from where we left off.
        """
        startSession(appendSystemPrompt: contextPrompt)
    }

    private func loadSessionSummary(session: ConversationSession) -> String? {
        let projectURL = URL(fileURLWithPath: session.projectPath)
        let conversationsDir = projectURL.appendingPathComponent(".claude/conversations")
        let shortId = String(session.sessionId.prefix(8))

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: conversationsDir, includingPropertiesForKeys: nil
        ) else { return nil }

        guard let mdFile = files.first(where: { $0.lastPathComponent.contains(shortId) && $0.pathExtension == "md" }) else {
            return nil
        }

        return try? String(contentsOf: mdFile, encoding: .utf8)
    }

    func stopSession() {
        processManager.stop()
        stopTimer()
        sessionState = .idle
    }

    func sendMessage() {
        let text = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(.fromUser(text))
        processManager.sendMessage(text)
        currentInput = ""
    }

    // MARK: - Permission Handling

    func approvePermission(messageId: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        if case .permissionRequest(let tool, let desc, let cmd, _) = messages[idx].content {
            messages[idx].content = .permissionRequest(tool: tool, description: desc, command: cmd, status: .allowed)
        }
        processManager.sendPermissionResponse(allow: true)
        sessionState = .running
    }

    func denyPermission(messageId: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        if case .permissionRequest(let tool, let desc, let cmd, _) = messages[idx].content {
            messages[idx].content = .permissionRequest(tool: tool, description: desc, command: cmd, status: .denied)
        }
        processManager.sendPermissionResponse(allow: false)
        sessionState = .running
    }

    func enableAutoApprove() {
        autoApproveAll = true
        // Auto-approve any pending requests
        for i in messages.indices {
            if case .permissionRequest(let tool, let desc, let cmd, .pending) = messages[i].content {
                messages[i].content = .permissionRequest(tool: tool, description: desc, command: cmd, status: .autoApproved)
                processManager.sendPermissionResponse(allow: true)
            }
        }
    }

    func toggleToolExpansion(messageId: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        if case .toolCall(let name, let summary, let input, let result, let expanded) = messages[idx].content {
            messages[idx].content = .toolCall(name: name, summary: summary, input: input, result: result, isExpanded: !expanded)
        }
    }

    // MARK: - Private

    private func handleEvents(_ events: [ClaudeEvent]) {
        for event in events {
            switch event {
            case .system:
                sessionState = .running

            case .assistantText(let text):
                // Append to last assistant message or create new one
                if let lastIdx = messages.indices.last,
                   case .text(let existing) = messages[lastIdx].content,
                   messages[lastIdx].role == .assistant {
                    messages[lastIdx].content = .text(existing + text)
                } else {
                    messages.append(.fromAssistantText(text))
                }
                isThinking = true

            case .toolUse(let toolEvent):
                let msg = VibeChatMessage.fromToolUse(toolEvent)
                toolUseIdToMessageIndex[toolEvent.toolUseId] = messages.count
                messages.append(msg)
                toolCallCount += 1
                isThinking = false

            case .toolResult(let toolUseId, let output):
                // Attach result to the matching tool call message
                if let idx = toolUseIdToMessageIndex[toolUseId],
                   idx < messages.count,
                   case .toolCall(let name, let summary, let input, _, let expanded) = messages[idx].content {
                    messages[idx].content = .toolCall(name: name, summary: summary, input: input, result: output, isExpanded: expanded)
                }

            case .userMessage:
                break // We already added the user message when sending

            case .result(let resultEvent):
                messages.append(.fromResult(resultEvent))
                sessionState = .done
                isThinking = false
                stopTimer()
                saveSession(resultEvent: resultEvent)

            case .error(let msg):
                messages.append(.fromError(msg))
            }
        }

        // Sync state from process manager
        sessionState = processManager.sessionState
    }

    private func startTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.sessionStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func saveSession(resultEvent: ResultEvent) {
        ConversationStore.shared.saveSession(
            projectPath: projectPath,
            sessionId: resultEvent.sessionId,
            messages: messages,
            rawLines: rawLines,
            toolBreakdown: toolBreakdown,
            costUsd: resultEvent.costUsd,
            durationMs: resultEvent.durationMs,
            numTurns: resultEvent.numTurns
        )
    }
}
