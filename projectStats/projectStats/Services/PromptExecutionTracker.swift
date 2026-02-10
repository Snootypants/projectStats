import Foundation
import SwiftData

@MainActor
final class PromptExecutionTracker: ObservableObject {
    static let shared = PromptExecutionTracker()

    /// Currently active (incomplete) execution IDs per project
    @Published var activeExecutions: [String: UUID] = [:]

    private init() {}

    func startExecution(
        projectPath: String,
        promptText: String,
        sendMode: String,
        model: String,
        isSwarm: Bool,
        promptId: UUID?
    ) {
        let usage = ClaudePlanUsageService.shared

        let scopeCount = promptText.components(separatedBy: "## SCOPE").count - 1

        let execution = PromptExecution(
            projectPath: projectPath,
            sendMode: sendMode,
            model: model,
            isSwarm: isSwarm,
            promptCharCount: promptText.count,
            scopeCount: max(scopeCount, 1),
            startSessionPercent: usage.fiveHourUtilization,
            startWeeklyPercent: usage.sevenDayUtilization
        )
        execution.promptId = promptId

        let context = AppModelContainer.shared.mainContext
        context.insert(execution)
        context.safeSave()

        activeExecutions[projectPath] = execution.id
    }

    func completeExecution(
        projectPath: String,
        durationSeconds: Double?
    ) {
        let usage = ClaudePlanUsageService.shared

        Task {
            await usage.fetchUsage()

            guard let executionId = activeExecutions[projectPath] else { return }

            let context = AppModelContainer.shared.mainContext
            let descriptor = FetchDescriptor<PromptExecution>(
                predicate: #Predicate { $0.id == executionId }
            )
            guard let execution = try? context.fetch(descriptor).first else { return }

            execution.completeExecution(
                endSessionPercent: usage.fiveHourUtilization,
                endWeeklyPercent: usage.sevenDayUtilization,
                durationSeconds: durationSeconds,
                commitCount: nil
            )
            context.safeSave()

            activeExecutions.removeValue(forKey: projectPath)
        }
    }

    /// Parse scope count from prompt text
    static func parseScopeCount(from text: String) -> Int {
        max(text.components(separatedBy: "## SCOPE").count - 1, 1)
    }
}
