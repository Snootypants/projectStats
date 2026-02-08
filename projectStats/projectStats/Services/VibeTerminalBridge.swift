import Foundation
import SwiftData

@MainActor
final class VibeTerminalBridge: ObservableObject {
    let projectPath: URL
    @Published var outputStream: String = ""
    @Published var isClaudeActive: Bool = false
    @Published var executionOutputStream: String = ""
    @Published var isExecuting: Bool = false

    @Published private(set) var planningTab: TerminalTabItem?
    private var executionTab: TerminalTabItem?
    private let conversationService = VibeConversationService.shared
    private let maxOutputSize = 512_000 // ~500KB

    init(projectPath: URL) {
        self.projectPath = projectPath
    }

    /// Boot the planning terminal — starts Claude in /plan mode
    func boot() {
        guard planningTab == nil else { return }

        let tab = TerminalTabItem(kind: .claude, title: "Vibe Planning")
        tab.onOutputCallback = { [weak self] text in
            self?.handleOutput(text)
        }
        planningTab = tab

        // Commands enqueued here will be sent once VibeTerminalHostView attaches the shell
        tab.enqueueCommand("claude")
        // /plan needs to be sent after claude starts
        Task {
            try? await Task.sleep(for: .seconds(2))
            tab.enqueueCommand("/plan")
        }

        _ = conversationService.startConversation(projectPath: projectPath.path)
    }

    /// Send user input to the planning terminal
    func send(_ text: String) {
        guard let tab = planningTab else { return }
        tab.sendCommand(text)
    }

    /// Send a slash command (e.g. /plan, /usage)
    func sendSlashCommand(_ cmd: String) {
        guard let tab = planningTab else { return }
        tab.sendCommand(cmd)
    }

    /// Handle terminal output — called from the terminal view's onOutput callback
    func handleOutput(_ text: String) {
        let stripped = TerminalTabItem.stripAnsiCodes(text)
        outputStream += stripped

        // Trim if too large
        if outputStream.count > maxOutputSize {
            let dropCount = outputStream.count - maxOutputSize
            outputStream = String(outputStream.dropFirst(dropCount))
        }

        // Persist to conversation
        conversationService.appendToLog(stripped)
        // Note: monitor and time tracking handled by VibeTerminalHostView's onOutput
    }

    /// Handle execution terminal output
    func handleExecutionOutput(_ text: String) {
        let stripped = TerminalTabItem.stripAnsiCodes(text)
        executionOutputStream += stripped

        // Detect completion
        if stripped.contains("✻ Cooked for") || stripped.contains("✻ Crunched for") {
            isExecuting = false
            // Try to parse duration
            if let duration = parseDuration(from: stripped) {
                conversationService.completeExecution(duration: duration)
            } else {
                conversationService.completeExecution(duration: 0)
            }
        }
    }

    /// Lock the plan and compose the prompt
    func lockPlanAndCompose(summary: String, template: PromptTemplate?) {
        conversationService.lockPlan(summary: summary)
        conversationService.composePrompt(templateContent: template?.content)
        if let template {
            conversationService.activeConversation?.templateId = template.id
        }
    }

    /// Execute the composed prompt in a new terminal
    func executePrompt() {
        guard let conv = conversationService.activeConversation,
              let prompt = conv.composedPrompt else { return }

        conversationService.startExecution()
        isExecuting = true
        executionOutputStream = ""

        let tab = TerminalTabItem(kind: .claude, title: "Vibe Execution")
        tab.onOutputCallback = { [weak self] text in
            self?.handleExecutionOutput(text)
        }
        executionTab = tab

        let command = ThinkingLevelService.shared.generatePromptCommand(prompt: prompt)
        tab.enqueueCommand(command)

        // Add to the project's terminal tabs so it gets a terminal view
        let termVM = TerminalTabsViewModel.shared
        termVM.tabs.append(tab)
    }

    private func parseDuration(from text: String) -> Double? {
        // Parse "✻ Cooked for 4m 2s" or "✻ Crunched for 30s"
        let pattern = "(?:Cooked|Crunched) for\\s+((?:\\d+h\\s*)?(?:\\d+m\\s*)?(?:\\d+s)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }

        let timeStr = String(text[range])
        var total: Double = 0

        let hPattern = try? NSRegularExpression(pattern: "(\\d+)h")
        let mPattern = try? NSRegularExpression(pattern: "(\\d+)m")
        let sPattern = try? NSRegularExpression(pattern: "(\\d+)s")
        let nsRange = NSRange(timeStr.startIndex..., in: timeStr)

        if let hMatch = hPattern?.firstMatch(in: timeStr, range: nsRange),
           let r = Range(hMatch.range(at: 1), in: timeStr) {
            total += (Double(timeStr[r]) ?? 0) * 3600
        }
        if let mMatch = mPattern?.firstMatch(in: timeStr, range: nsRange),
           let r = Range(mMatch.range(at: 1), in: timeStr) {
            total += (Double(timeStr[r]) ?? 0) * 60
        }
        if let sMatch = sPattern?.firstMatch(in: timeStr, range: nsRange),
           let r = Range(sMatch.range(at: 1), in: timeStr) {
            total += Double(timeStr[r]) ?? 0
        }

        return total > 0 ? total : nil
    }
}
