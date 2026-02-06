import Foundation
import SwiftData

@Model
final class PromptExecution {
    var id: UUID
    var promptId: UUID?
    var projectPath: String
    var createdAt: Date

    // What was sent
    var sendMode: String
    var model: String
    var isSwarm: Bool
    var promptCharCount: Int
    var scopeCount: Int

    // Usage at send time
    var startSessionPercent: Double
    var startWeeklyPercent: Double
    var startTime: Date

    // Usage at completion (nil until Claude finishes)
    var endSessionPercent: Double?
    var endWeeklyPercent: Double?
    var endTime: Date?
    var durationSeconds: Double?

    // Computed deltas (stored for query performance)
    var sessionDelta: Double?
    var weeklyDelta: Double?

    // Result tracking
    var commitCount: Int?
    var selfGrade: String?

    init(
        projectPath: String,
        sendMode: String,
        model: String,
        isSwarm: Bool,
        promptCharCount: Int,
        scopeCount: Int,
        startSessionPercent: Double,
        startWeeklyPercent: Double
    ) {
        self.id = UUID()
        self.projectPath = projectPath
        self.createdAt = Date()
        self.sendMode = sendMode
        self.model = model
        self.isSwarm = isSwarm
        self.promptCharCount = promptCharCount
        self.scopeCount = scopeCount
        self.startSessionPercent = startSessionPercent
        self.startWeeklyPercent = startWeeklyPercent
        self.startTime = Date()
    }

    var isComplete: Bool { endTime != nil }

    var sessionCostPercent: Double? {
        guard let end = endSessionPercent else { return nil }
        return end - startSessionPercent
    }

    var weeklyCostPercent: Double? {
        guard let end = endWeeklyPercent else { return nil }
        return end - startWeeklyPercent
    }

    func completeExecution(
        endSessionPercent: Double,
        endWeeklyPercent: Double,
        durationSeconds: Double?,
        commitCount: Int?
    ) {
        self.endSessionPercent = endSessionPercent
        self.endWeeklyPercent = endWeeklyPercent
        self.endTime = Date()
        self.durationSeconds = durationSeconds
        self.commitCount = commitCount
        self.sessionDelta = endSessionPercent - startSessionPercent
        self.weeklyDelta = endWeeklyPercent - startWeeklyPercent
    }
}
