import Foundation
import SwiftData

@Model
final class PromptTemplate {
    var id: UUID
    var name: String
    var content: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var currentVersionNumber: Int
    var oneShotSuccessCount: Int
    var totalPromptsFromVersion: Int

    @Relationship(deleteRule: .cascade)
    var versions: [PromptTemplateVersion]

    init(name: String, content: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
        self.currentVersionNumber = 1
        self.oneShotSuccessCount = 0
        self.totalPromptsFromVersion = 0
        self.versions = []
    }

    /// Edit the template content, creating a version snapshot of the old state
    func edit(newContent: String, editNote: String? = nil) {
        // Snapshot current state into a version
        let version = PromptTemplateVersion(
            versionNumber: currentVersionNumber,
            content: content,
            editNote: editNote,
            oneShotSuccessCount: oneShotSuccessCount,
            totalPromptsFromVersion: totalPromptsFromVersion
        )
        versions.append(version)

        // Update template
        content = newContent
        currentVersionNumber += 1
        oneShotSuccessCount = 0
        totalPromptsFromVersion = 0
        updatedAt = Date()
    }

    /// Record a 1-shot success for the current version
    func recordOneShotSuccess() {
        oneShotSuccessCount += 1
        totalPromptsFromVersion += 1
    }

    /// Record a prompt use (not necessarily 1-shot)
    func recordPromptUse() {
        totalPromptsFromVersion += 1
    }

    /// Version history ordered by date (newest first)
    var orderedVersions: [PromptTemplateVersion] {
        versions.sorted { $0.createdAt > $1.createdAt }
    }
}

@Model
final class PromptTemplateVersion {
    var id: UUID
    var versionNumber: Int
    var content: String
    var editNote: String?
    var createdAt: Date
    var oneShotSuccessCount: Int
    var totalPromptsFromVersion: Int

    init(versionNumber: Int, content: String, editNote: String? = nil,
         oneShotSuccessCount: Int = 0, totalPromptsFromVersion: Int = 0) {
        self.id = UUID()
        self.versionNumber = versionNumber
        self.content = content
        self.editNote = editNote
        self.createdAt = Date()
        self.oneShotSuccessCount = oneShotSuccessCount
        self.totalPromptsFromVersion = totalPromptsFromVersion
    }
}
