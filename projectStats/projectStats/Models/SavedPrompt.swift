import Foundation
import SwiftData

@Model
final class SavedPrompt {
    var id: UUID
    var text: String
    var projectPath: String?
    var createdAt: Date
    var wasExecuted: Bool
    var sourceFile: String?  // e.g. "1.md", "10.md" - tracks imported file origin

    init(text: String, projectPath: String? = nil, wasExecuted: Bool = true) {
        self.id = UUID()
        self.text = text
        self.projectPath = projectPath
        self.createdAt = Date()
        self.wasExecuted = wasExecuted
        self.sourceFile = nil
    }
}
