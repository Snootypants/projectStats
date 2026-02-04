import Foundation
import SwiftData

@MainActor
class PromptImportService {
    static let shared = PromptImportService()

    private var importedPromptPaths: Set<String> = []
    private var importedWorkLogPaths: Set<String> = []

    // MARK: - Prompt Import

    func importPromptsIfNeeded(for projectPath: URL, context: ModelContext) async {
        let promptsDir = projectPath.appendingPathComponent("prompts")

        // Skip if already imported this session
        guard !importedPromptPaths.contains(promptsDir.path) else { return }
        importedPromptPaths.insert(promptsDir.path)

        guard FileManager.default.fileExists(atPath: promptsDir.path) else { return }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: promptsDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ).filter { $0.pathExtension == "md" }

            // Fetch all existing prompts for this project to check for duplicates
            let projectPathString = projectPath.path
            let descriptor = FetchDescriptor<SavedPrompt>(
                predicate: #Predicate { $0.projectPath == projectPathString }
            )
            let existingPrompts = try context.fetch(descriptor)
            let existingSourceFiles = Set(existingPrompts.compactMap { $0.sourceFile })

            var importCount = 0

            for file in files {
                let filename = file.lastPathComponent

                // Skip if already imported
                guard !existingSourceFiles.contains(filename) else { continue }

                // Read file content
                let content = try String(contentsOf: file, encoding: .utf8)
                let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
                let modDate = attrs[.modificationDate] as? Date ?? Date()

                // Create SavedPrompt
                let prompt = SavedPrompt(
                    text: content,
                    projectPath: projectPathString,
                    wasExecuted: true  // Historical prompt
                )
                prompt.createdAt = modDate
                prompt.sourceFile = filename

                context.insert(prompt)
                importCount += 1
            }

            if importCount > 0 {
                try context.save()
                print("[PromptImport] Imported \(importCount) prompts from \(promptsDir.lastPathComponent)")
            }
        } catch {
            print("[PromptImport] Error: \(error)")
        }
    }

    // MARK: - Work Log Import

    func importWorkLogsIfNeeded(for projectPath: URL, context: ModelContext) async {
        let workDir = projectPath.appendingPathComponent("work")

        // Skip if already imported this session
        guard !importedWorkLogPaths.contains(workDir.path) else { return }
        importedWorkLogPaths.insert(workDir.path)

        guard FileManager.default.fileExists(atPath: workDir.path) else { return }

        do {
            // Get all .md files directly in /work/ (not in subdirectories like /work/stats/)
            let allItems = try FileManager.default.contentsOfDirectory(
                at: workDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey]
            )

            let files = allItems.filter { url in
                // Only .md files that are NOT directories
                guard url.pathExtension == "md" else { return false }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return !(values?.isDirectory ?? true)
            }

            // Fetch existing work logs for this project
            let projectPathString = projectPath.path
            let descriptor = FetchDescriptor<CachedWorkLog>(
                predicate: #Predicate { $0.projectPath == projectPathString }
            )
            let existingLogs = try context.fetch(descriptor)
            let existingSourceFiles = Set(existingLogs.compactMap { $0.sourceFile })

            var importCount = 0

            for file in files {
                let filename = file.lastPathComponent

                // Skip if already imported
                guard !existingSourceFiles.contains(filename) else { continue }

                let content = try String(contentsOf: file, encoding: .utf8)
                let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
                let modDate = attrs[.modificationDate] as? Date ?? Date()

                // Parse filename for the base name (without extension)
                let filenameWithoutExt = file.deletingPathExtension().lastPathComponent

                let workLog = CachedWorkLog(
                    projectPath: projectPathString,
                    filename: filenameWithoutExt,
                    content: content,
                    fileModified: modDate,
                    sourceFile: filename
                )

                context.insert(workLog)
                importCount += 1
            }

            if importCount > 0 {
                try context.save()
                print("[WorkLogImport] Imported \(importCount) work logs from \(workDir.lastPathComponent)")
            }
        } catch {
            print("[WorkLogImport] Error: \(error)")
        }
    }
}
