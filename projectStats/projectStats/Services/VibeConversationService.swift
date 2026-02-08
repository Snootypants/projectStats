import Foundation
import SwiftData

@MainActor
final class VibeConversationService: ObservableObject {
    static let shared = VibeConversationService()

    @Published var activeConversation: VibeConversation?

    private var logBuffer: String = ""
    private var flushTask: Task<Void, Never>?

    private init() {}

    func startConversation(projectPath: String) -> VibeConversation {
        let conv = VibeConversation(projectPath: projectPath)
        activeConversation = conv
        let context = AppModelContainer.shared.mainContext
        context.insert(conv)
        try? context.save()
        return conv
    }

    func appendToLog(_ text: String) {
        logBuffer += text

        // Debounce: flush after 2 seconds of inactivity
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.flushLogBuffer()
        }
    }

    func flushLogBuffer() {
        guard !logBuffer.isEmpty, let conv = activeConversation else { return }
        conv.rawLog += logBuffer
        conv.updatedAt = Date()
        logBuffer = ""
        try? AppModelContainer.shared.mainContext.save()
    }

    func lockPlan(summary: String) {
        guard let conv = activeConversation else { return }
        flushLogBuffer()
        conv.planSummary = summary
        conv.status = "ready"
        conv.updatedAt = Date()
        try? AppModelContainer.shared.mainContext.save()
    }

    func composePrompt(templateContent: String?) {
        guard let conv = activeConversation, let summary = conv.planSummary else { return }
        conv.composedPrompt = PromptHelperComposer.compose(userText: summary, templateContent: templateContent)
        conv.updatedAt = Date()
        try? AppModelContainer.shared.mainContext.save()
    }

    func startExecution() {
        guard let conv = activeConversation else { return }
        conv.status = "executing"
        conv.updatedAt = Date()
        try? AppModelContainer.shared.mainContext.save()
    }

    func completeExecution(duration: Double) {
        guard let conv = activeConversation else { return }
        conv.status = "completed"
        conv.executionDurationSeconds = duration
        conv.updatedAt = Date()
        try? AppModelContainer.shared.mainContext.save()
    }

    func endConversation() {
        flushLogBuffer()
        try? AppModelContainer.shared.mainContext.save()
        activeConversation = nil
    }
}
