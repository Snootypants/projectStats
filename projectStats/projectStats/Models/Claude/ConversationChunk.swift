import Foundation

struct ConversationChunk: Identifiable, Codable {
    let id: UUID
    let sessionId: String
    let projectPath: String
    let timestamp: Date
    let chunkIndex: Int
    let content: String
    let chunkType: ChunkType
    let tokenEstimate: Int

    enum ChunkType: String, Codable {
        case userQuestion
        case assistantResponse
        case decision
        case toolSummary
    }

    init(sessionId: String, projectPath: String, timestamp: Date, chunkIndex: Int, content: String, chunkType: ChunkType) {
        self.id = UUID()
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.timestamp = timestamp
        self.chunkIndex = chunkIndex
        self.content = content
        self.chunkType = chunkType
        self.tokenEstimate = max(1, content.split(separator: " ").count * 13 / 10)
    }
}
