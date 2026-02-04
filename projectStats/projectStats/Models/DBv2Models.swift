import Foundation
import SwiftData

// MARK: - DB v2 Models
// These models provide better structure for tracking development activity

/// Represents a coding session within a project
@Model
final class ProjectSession {
    var id: UUID
    var projectPath: String
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var commitsMade: Int
    var filesModified: Int
    var linesAdded: Int
    var linesRemoved: Int
    var claudeTokensUsed: Int
    var notes: String?

    init(
        projectPath: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval = 0,
        commitsMade: Int = 0,
        filesModified: Int = 0,
        linesAdded: Int = 0,
        linesRemoved: Int = 0,
        claudeTokensUsed: Int = 0,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.projectPath = projectPath
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.commitsMade = commitsMade
        self.filesModified = filesModified
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.claudeTokensUsed = claudeTokensUsed
        self.notes = notes
    }

    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    var isActive: Bool {
        endTime == nil
    }
}

/// Aggregated daily metrics for quick dashboard loading
@Model
final class DailyMetric {
    var id: UUID
    var date: Date
    var projectPath: String?  // nil = global
    var totalCommits: Int
    var totalTimeMinutes: Int
    var totalLinesAdded: Int
    var totalLinesRemoved: Int
    var totalClaudeTokens: Int
    var totalClaudeCost: Double
    var sessionsCount: Int
    var uniqueFilesModified: Int

    init(
        date: Date,
        projectPath: String? = nil,
        totalCommits: Int = 0,
        totalTimeMinutes: Int = 0,
        totalLinesAdded: Int = 0,
        totalLinesRemoved: Int = 0,
        totalClaudeTokens: Int = 0,
        totalClaudeCost: Double = 0,
        sessionsCount: Int = 0,
        uniqueFilesModified: Int = 0
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.projectPath = projectPath
        self.totalCommits = totalCommits
        self.totalTimeMinutes = totalTimeMinutes
        self.totalLinesAdded = totalLinesAdded
        self.totalLinesRemoved = totalLinesRemoved
        self.totalClaudeTokens = totalClaudeTokens
        self.totalClaudeCost = totalClaudeCost
        self.sessionsCount = sessionsCount
        self.uniqueFilesModified = uniqueFilesModified
    }

    var isGlobal: Bool {
        projectPath == nil
    }
}

/// Work item for tracking tasks, bugs, features
@Model
final class WorkItem {
    var id: UUID
    var projectPath: String
    var title: String
    var descriptionText: String?
    var itemType: String        // "task", "bug", "feature", "improvement"
    var status: String          // "todo", "in_progress", "done", "blocked"
    var priority: Int           // 1-5, where 1 is highest
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var estimatedMinutes: Int?
    var actualMinutes: Int?
    var linkedCommitHashes: Data?  // JSON encoded [String]
    var tags: Data?                // JSON encoded [String]

    init(
        projectPath: String,
        title: String,
        descriptionText: String? = nil,
        itemType: String = "task",
        status: String = "todo",
        priority: Int = 3,
        estimatedMinutes: Int? = nil
    ) {
        self.id = UUID()
        self.projectPath = projectPath
        self.title = title
        self.descriptionText = descriptionText
        self.itemType = itemType
        self.status = status
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
        self.estimatedMinutes = estimatedMinutes
    }

    var linkedCommits: [String] {
        get {
            guard let data = linkedCommitHashes else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            linkedCommitHashes = try? JSONEncoder().encode(newValue)
        }
    }

    var tagList: [String] {
        get {
            guard let data = tags else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            tags = try? JSONEncoder().encode(newValue)
        }
    }

    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }
}

/// Weekly goal for tracking progress
@Model
final class WeeklyGoal {
    var id: UUID
    var weekStartDate: Date
    var projectPath: String?  // nil = global
    var goalText: String
    var targetCommits: Int?
    var targetHours: Int?
    var actualCommits: Int
    var actualMinutes: Int
    var isCompleted: Bool
    var reflectionNotes: String?

    init(
        weekStartDate: Date,
        projectPath: String? = nil,
        goalText: String,
        targetCommits: Int? = nil,
        targetHours: Int? = nil
    ) {
        self.id = UUID()
        // Normalize to start of week
        self.weekStartDate = Calendar.current.startOfDay(for: weekStartDate)
        self.projectPath = projectPath
        self.goalText = goalText
        self.targetCommits = targetCommits
        self.targetHours = targetHours
        self.actualCommits = 0
        self.actualMinutes = 0
        self.isCompleted = false
    }

    var progress: Double {
        if let target = targetCommits, target > 0 {
            return min(1.0, Double(actualCommits) / Double(target))
        }
        if let target = targetHours, target > 0 {
            return min(1.0, Double(actualMinutes) / Double(target * 60))
        }
        return isCompleted ? 1.0 : 0.0
    }
}
