import Foundation

@MainActor
final class VibeSummarizerService: ObservableObject {
    static let shared = VibeSummarizerService()

    @Published var isSummarizing: Bool = false
    @Published var lastSummary: String?

    private var ghostTab: TerminalTabItem?
    private var outputBuffer: String = ""
    private let maxInlineLength = 10_000

    private init() {}

    /// Build the summarize command for a conversation (exposed for testing)
    func buildSummarizeCommand(for conversation: VibeConversation) -> String {
        let prompt = "Summarize the following development conversation. Extract: key decisions, technical requirements, open questions, and the final agreed plan. Be concise."
        let log = conversation.rawLog

        if log.count > maxInlineLength {
            // Write to temp file for large logs
            let tempId = conversation.id.uuidString.prefix(8)
            let tempPath = "/tmp/vibe_summary_\(tempId).txt"
            let truncated = String(log.suffix(50_000))
            try? truncated.write(toFile: tempPath, atomically: true, encoding: .utf8)
            let filePrompt = "\(prompt)\n\nRead \(tempPath) and summarize the development conversation in it."
            return ThinkingLevelService.shared.generatePromptCommand(
                prompt: filePrompt,
                model: .claudeHaiku4
            )
        } else {
            let escaped = log
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let fullPrompt = "\(prompt)\n\n\(escaped)"
            return ThinkingLevelService.shared.generatePromptCommand(
                prompt: fullPrompt,
                model: .claudeHaiku4
            )
        }
    }

    /// Summarize a conversation using a ghost terminal
    func summarize(conversation: VibeConversation) {
        guard !isSummarizing else { return }
        isSummarizing = true
        outputBuffer = ""

        let tab = TerminalTabItem(kind: .ghost, title: "Vibe Summary", isGhost: true)
        tab.onOutputCallback = { [weak self] text in
            self?.handleGhostOutput(text)
        }
        ghostTab = tab

        let command = buildSummarizeCommand(for: conversation)
        tab.enqueueCommand(command)

        // Add to terminal tabs so it gets a view
        TerminalTabsViewModel.shared.tabs.append(tab)
    }

    /// Called when ghost terminal output arrives
    func handleGhostOutput(_ text: String) {
        let stripped = TerminalTabItem.stripAnsiCodes(text)
        outputBuffer += stripped

        // Check for completion
        if stripped.contains("✻ Cooked for") || stripped.contains("✻ Crunched for") {
            lastSummary = outputBuffer
            isSummarizing = false

            // Save to conversation
            VibeConversationService.shared.activeConversation?.planSummary = outputBuffer
            try? AppModelContainer.shared.mainContext.save()

            // Clean up temp file
            if let conv = VibeConversationService.shared.activeConversation {
                let tempId = conv.id.uuidString.prefix(8)
                let tempPath = "/tmp/vibe_summary_\(tempId).txt"
                try? FileManager.default.removeItem(atPath: tempPath)
            }

            ghostTab = nil
        }
    }
}
