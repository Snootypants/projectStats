import Foundation
import SwiftData

@Model
final class SavedPrompt {
    var id: UUID
    var text: String
    var projectPath: String?
    var createdAt: Date
    var wasExecuted: Bool

    init(text: String, projectPath: String? = nil, wasExecuted: Bool = true) {
        self.id = UUID()
        self.text = text
        self.projectPath = projectPath
        self.createdAt = Date()
        self.wasExecuted = wasExecuted
    }
}
