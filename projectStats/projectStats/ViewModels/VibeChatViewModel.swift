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

    // MARK: - Session Control

    func startSession() {
        messages = []
        toolCallCount = 0
        elapsedTime = 0
        rawLines = []
        toolUseIdToMessageIndex = [:]
        autoApproveAll = false
        sessionStartTime = Date()

        startTimer()

        processManager.start(
            projectPath: projectPath,
            permissionMode: selectedPermissionMode
        ) { [weak self] events in
            self?.handleEvents(events)
        }
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
}
