import Foundation
import SwiftData

@Model
final class ClaudeUsageSnapshot {
    var id: UUID
    var capturedAt: Date
    var projectPath: String?    // nil = global, otherwise project-specific
    var reportType: String      // "daily", "monthly", "blocks"
    var jsonData: String        // Raw JSON from ccusage

    // Parsed summary fields for quick access
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var totalCacheTokens: Int
    var totalCost: Double

    init(
        projectPath: String? = nil,
        reportType: String = "daily",
        jsonData: String,
        totalInputTokens: Int = 0,
        totalOutputTokens: Int = 0,
        totalCacheTokens: Int = 0,
        totalCost: Double = 0
    ) {
        self.id = UUID()
        self.capturedAt = Date()
        self.projectPath = projectPath
        self.reportType = reportType
        self.jsonData = jsonData
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.totalCacheTokens = totalCacheTokens
        self.totalCost = totalCost
    }
}
