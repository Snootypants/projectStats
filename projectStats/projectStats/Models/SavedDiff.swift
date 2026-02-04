import Foundation
import SwiftData

@Model
final class SavedDiff {
    var id: UUID
    var projectPath: String
    var commitHash: String?
    var diffText: String
    var filesChanged: Int
    var linesAdded: Int
    var linesRemoved: Int
    var createdAt: Date
    var promptId: UUID?  // Link to the prompt that caused this diff
    var sourceFile: String?  // For imported diffs

    init(
        projectPath: String,
        commitHash: String? = nil,
        diffText: String,
        filesChanged: Int = 0,
        linesAdded: Int = 0,
        linesRemoved: Int = 0,
        promptId: UUID? = nil,
        sourceFile: String? = nil
    ) {
        self.id = UUID()
        self.projectPath = projectPath
        self.commitHash = commitHash
        self.diffText = diffText
        self.filesChanged = filesChanged
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.createdAt = Date()
        self.promptId = promptId
        self.sourceFile = sourceFile
    }
}
