import Foundation
import os.log

@MainActor
final class ContextBuilder {
    static let shared = ContextBuilder()
    private init() {}

    /// Build context from past sessions for injection into a new session.
    /// Returns nil if no embeddings exist or API key isn't configured.
    func buildContext(projectPath: String, initialMessage: String? = nil) async -> String? {
        // Check if API key is available
        let apiKey = SettingsViewModel.shared.aiApiKey
        guard !apiKey.isEmpty else {
            Log.ai.info("No API key configured, skipping context injection")
            return nil
        }

        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
        let queryText = [projectName, initialMessage].compactMap { $0 }.joined(separator: " ")

        do {
            let queryVector = try await EmbeddingService.shared.embed(text: queryText)
            let results = VectorStore.shared.search(query: queryVector, projectPath: projectPath, topK: 8)

            guard !results.isEmpty else {
                Log.ai.debug("No relevant context found for project")
                return nil
            }

            // Format context block
            var contextLines: [String] = []
            contextLines.append("You are working on \(projectName). Here is relevant context from previous sessions:")
            contextLines.append("")

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for result in results where result.score > 0.3 {
                let dateStr = dateFormatter.string(from: result.embedding.timestamp)
                contextLines.append("[\(dateStr)] \(result.embedding.content)")
                contextLines.append("")
            }

            if contextLines.count <= 2 {
                // Only header, no useful results above threshold
                return nil
            }

            contextLines.append("Use this context to inform your work. If the user references something from a previous session, you should be able to recall it from the context above.")

            return contextLines.joined(separator: "\n")
        } catch {
            Log.ai.error("Failed to build context: \(error.localizedDescription)")
            return nil
        }
    }
}
