import Foundation
import SwiftData

@Model
final class TimeEntry {
    var id: UUID
    var projectPath: String
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval
    var isManual: Bool
    var notes: String?

    // Session type tracking: "human", "claude_code", "codex", "api"
    var sessionType: String
    var aiModel: String?      // "opus-4", "sonnet-4", etc. (for AI sessions)
    var tokensUsed: Int?      // If available from terminal parsing

    init(
        id: UUID = UUID(),
        projectPath: String,
        startTime: Date,
        endTime: Date,
        duration: TimeInterval,
        isManual: Bool = false,
        notes: String? = nil,
        sessionType: String = "human",
        aiModel: String? = nil,
        tokensUsed: Int? = nil
    ) {
        self.id = id
        self.projectPath = projectPath
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.isManual = isManual
        self.notes = notes
        self.sessionType = sessionType
        self.aiModel = aiModel
        self.tokensUsed = tokensUsed
    }
}
