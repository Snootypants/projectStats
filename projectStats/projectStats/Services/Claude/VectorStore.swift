import Foundation

@MainActor
final class VectorStore {
    static let shared = VectorStore()
    private init() {}

    /// In-memory cache: projectPath -> embeddings
    private var cache: [String: [StoredEmbedding]] = [:]

    /// Store new embeddings for a project
    func store(embeddings: [StoredEmbedding], projectPath: String) {
        var existing = loadEmbeddings(for: projectPath)
        existing.append(contentsOf: embeddings)
        cache[projectPath] = existing
        saveToDisk(embeddings: existing, projectPath: projectPath)
    }

    /// Search for similar chunks
    func search(query: [Float], projectPath: String, topK: Int = 5) -> [SearchResult] {
        let embeddings = loadEmbeddings(for: projectPath)
        guard !embeddings.isEmpty else { return [] }

        var results = embeddings.map { emb in
            SearchResult(embedding: emb, score: cosineSimilarity(query, emb.embedding))
        }
        results.sort { $0.score > $1.score }
        return Array(results.prefix(topK))
    }

    /// Check if a session has already been indexed
    func hasSession(sessionId: String, projectPath: String) -> Bool {
        let embeddings = loadEmbeddings(for: projectPath)
        return embeddings.contains { $0.sessionId == sessionId }
    }

    /// Delete all embeddings for a project (for rebuild)
    func deleteProject(projectPath: String) {
        cache.removeValue(forKey: projectPath)
        let url = embeddingsURL(for: projectPath)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private func loadEmbeddings(for projectPath: String) -> [StoredEmbedding] {
        if let cached = cache[projectPath] { return cached }

        let url = embeddingsURL(for: projectPath)
        guard let data = try? Data(contentsOf: url),
              let embeddings = try? JSONDecoder().decode([StoredEmbedding].self, from: data) else {
            return []
        }
        cache[projectPath] = embeddings
        return embeddings
    }

    private func saveToDisk(embeddings: [StoredEmbedding], projectPath: String) {
        let url = embeddingsURL(for: projectPath)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if let data = try? JSONEncoder().encode(embeddings) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func embeddingsURL(for projectPath: String) -> URL {
        URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("embeddings.json")
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var magA: Float = 0
        var magB: Float = 0
        for i in a.indices {
            dot += a[i] * b[i]
            magA += a[i] * a[i]
            magB += b[i] * b[i]
        }
        let denom = sqrt(magA) * sqrt(magB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }
}
