import Foundation
import Combine

@MainActor
final class MemoryPipeline: ObservableObject {
    static let shared = MemoryPipeline()
    private init() {}

    @Published var indexingState: IndexingState = .idle

    enum IndexingState: Equatable {
        case idle
        case indexing(String)
        case done
        case error(String)
    }

    /// Index a single session's conversation data
    func indexSession(
        projectPath: String,
        sessionId: String,
        rawLines: [String],
        summary: String
    ) async {
        // Skip if already indexed
        guard !VectorStore.shared.hasSession(sessionId: sessionId, projectPath: projectPath) else {
            print("[MemoryPipeline] Session \(sessionId.prefix(8)) already indexed, skipping")
            return
        }

        indexingState = .indexing(sessionId)

        do {
            // 1. Chunk the summary
            let chunks = ConversationChunker.shared.chunkFromMarkdown(
                summary: summary,
                sessionId: sessionId,
                projectPath: projectPath,
                timestamp: Date()
            )

            guard !chunks.isEmpty else {
                print("[MemoryPipeline] No chunks produced for session \(sessionId.prefix(8))")
                indexingState = .done
                return
            }

            // 2. Embed the chunks
            let texts = chunks.map(\.content)
            let vectors = try await EmbeddingService.shared.embed(texts: texts)

            // 3. Store embeddings
            let storedEmbeddings = zip(chunks, vectors).map { chunk, vector in
                StoredEmbedding(
                    sessionId: chunk.sessionId,
                    projectPath: chunk.projectPath,
                    chunkIndex: chunk.chunkIndex,
                    content: chunk.content,
                    embedding: vector,
                    chunkType: chunk.chunkType.rawValue,
                    timestamp: chunk.timestamp
                )
            }
            VectorStore.shared.store(embeddings: storedEmbeddings, projectPath: projectPath)

            print("[MemoryPipeline] Indexed session \(sessionId.prefix(8)): \(chunks.count) chunks")
            indexingState = .done
        } catch {
            print("[MemoryPipeline] Failed to index session \(sessionId.prefix(8)): \(error.localizedDescription)")
            indexingState = .error(error.localizedDescription)
        }
    }

    /// Re-index all sessions for a project
    func rebuildMemory(projectPath: String) async {
        indexingState = .indexing("rebuilding")

        // Clear existing embeddings
        VectorStore.shared.deleteProject(projectPath: projectPath)

        // Find all .md files in conversations directory
        let conversationsDir = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude/conversations")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: conversationsDir, includingPropertiesForKeys: nil
        ) else {
            indexingState = .done
            return
        }

        let mdFiles = files.filter { $0.pathExtension == "md" }
        print("[MemoryPipeline] Rebuilding memory: \(mdFiles.count) sessions found")

        for mdFile in mdFiles {
            guard let content = try? String(contentsOf: mdFile, encoding: .utf8) else { continue }

            // Extract session ID from filename (format: yyyy-MM-dd_HHmm_SHORTID.md)
            let filename = mdFile.deletingPathExtension().lastPathComponent
            let parts = filename.components(separatedBy: "_")
            let sessionId = parts.count >= 3 ? parts.last ?? filename : filename

            await indexSession(
                projectPath: projectPath,
                sessionId: sessionId,
                rawLines: [],
                summary: content
            )
        }

        indexingState = .done
        print("[MemoryPipeline] Rebuild complete")
    }
}
