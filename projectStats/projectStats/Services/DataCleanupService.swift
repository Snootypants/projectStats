import Foundation
import SwiftData

@MainActor
class DataCleanupService {
    static let shared = DataCleanupService()

    private let cleanupKey = "hasCleanedPromptDiffs_v1"

    func cleanupIfNeeded(context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: cleanupKey) else { return }

        // Fetch all SavedPrompts
        let descriptor = FetchDescriptor<SavedPrompt>()
        guard let allPrompts = try? context.fetch(descriptor) else { return }

        var movedCount = 0

        for prompt in allPrompts {
            // Check if this looks like a diff
            if isDiffContent(prompt.text) {
                // Create a SavedDiff instead
                let diff = SavedDiff(
                    projectPath: prompt.projectPath ?? "",
                    diffText: prompt.text,
                    sourceFile: prompt.sourceFile
                )
                diff.createdAt = prompt.createdAt

                // Parse diff stats if possible
                let stats = parseDiffStats(prompt.text)
                diff.linesAdded = stats.added
                diff.linesRemoved = stats.removed
                diff.filesChanged = stats.files

                context.insert(diff)
                context.delete(prompt)
                movedCount += 1
            }
        }

        if movedCount > 0 {
            try? context.save()
            print("[DataCleanup] Moved \(movedCount) diffs from SavedPrompt to SavedDiff")
        }

        UserDefaults.standard.set(true, forKey: cleanupKey)
    }

    private func isDiffContent(_ text: String) -> Bool {
        // Check for diff markers
        let diffMarkers = [
            "diff --git",
            "--- a/",
            "+++ b/",
            "@@ -",
            "index "
        ]

        let lowerText = text.lowercased()
        for marker in diffMarkers {
            if lowerText.contains(marker.lowercased()) {
                return true
            }
        }
        return false
    }

    private func parseDiffStats(_ text: String) -> (added: Int, removed: Int, files: Int) {
        var added = 0
        var removed = 0
        var files = Set<String>()

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                added += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                removed += 1
            } else if line.hasPrefix("diff --git") {
                // Extract filename
                files.insert(line)
            }
        }

        return (added, removed, files.count)
    }
}
