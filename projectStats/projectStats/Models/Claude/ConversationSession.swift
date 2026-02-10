import Foundation
import SwiftData

@Model
final class ConversationSession {
    var id: UUID
    var projectPath: String
    var sessionId: String
    var startedAt: Date
    var endedAt: Date?
    var durationMs: Int
    var costUsd: Double
    var numTurns: Int
    var toolCallCounts: [String: Int]
    var filesTouched: [String]

    // Token economics (Scope B)
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int
    var durationApiMs: Int
    var isError: Bool

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    var tokensPerSecond: Double {
        guard durationApiMs > 0 else { return 0 }
        return Double(outputTokens) / (Double(durationApiMs) / 1000.0)
    }

    var costPerTurn: Double {
        guard numTurns > 0 else { return 0 }
        return costUsd / Double(numTurns)
    }

    init(
        projectPath: String,
        sessionId: String,
        startedAt: Date = Date(),
        durationMs: Int = 0,
        costUsd: Double = 0,
        numTurns: Int = 0,
        toolCallCounts: [String: Int] = [:],
        filesTouched: [String] = [],
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0,
        durationApiMs: Int = 0,
        isError: Bool = false
    ) {
        self.id = UUID()
        self.projectPath = projectPath
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.durationMs = durationMs
        self.costUsd = costUsd
        self.numTurns = numTurns
        self.toolCallCounts = toolCallCounts
        self.filesTouched = filesTouched
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.durationApiMs = durationApiMs
        self.isError = isError
    }
}
