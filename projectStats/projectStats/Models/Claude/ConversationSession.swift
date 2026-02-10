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

    init(
        projectPath: String,
        sessionId: String,
        startedAt: Date = Date(),
        durationMs: Int = 0,
        costUsd: Double = 0,
        numTurns: Int = 0,
        toolCallCounts: [String: Int] = [:],
        filesTouched: [String] = []
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
    }
}
