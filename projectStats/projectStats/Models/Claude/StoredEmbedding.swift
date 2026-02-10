import Foundation

struct StoredEmbedding: Codable {
    let id: UUID
    let sessionId: String
    let projectPath: String
    let chunkIndex: Int
    let content: String
    let embedding: [Float]
    let chunkType: String
    let timestamp: Date

    init(sessionId: String, projectPath: String, chunkIndex: Int, content: String, embedding: [Float], chunkType: String, timestamp: Date) {
        self.id = UUID()
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.chunkIndex = chunkIndex
        self.content = content
        self.embedding = embedding
        self.chunkType = chunkType
        self.timestamp = timestamp
    }
}

struct SearchResult {
    let embedding: StoredEmbedding
    let score: Float
}
