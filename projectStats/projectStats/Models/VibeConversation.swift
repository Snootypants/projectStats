import Foundation
import SwiftData

@Model
final class VibeConversation {
    var id: UUID
    var projectPath: String
    var startedAt: Date
    var updatedAt: Date
    var title: String
    var rawLog: String
    var status: String
    var planSummary: String?
    var composedPrompt: String?
    var executionDurationSeconds: Double?
    var templateId: UUID?

    init(projectPath: String) {
        self.id = UUID()
        self.projectPath = projectPath
        self.startedAt = Date()
        self.updatedAt = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        self.title = "Vibe Session - \(formatter.string(from: Date()))"
        self.rawLog = ""
        self.status = "planning"
    }
}
