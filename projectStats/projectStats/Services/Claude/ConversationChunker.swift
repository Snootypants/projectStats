import Foundation

final class ConversationChunker {
    static let shared = ConversationChunker()
    private init() {}

    // MARK: - Token Limits

    private let minTokens = 100
    private let maxTokens = 500
    private let charsPerToken: Double = 4.0  // ~4 chars per token on average

    // MARK: - Markdown Chunking

    /// Break a markdown conversation summary into semantic chunks
    func chunkFromMarkdown(
        summary: String,
        sessionId: String,
        projectPath: String,
        timestamp: Date
    ) -> [ConversationChunk] {
        let lines = summary.components(separatedBy: "\n")
        var rawSegments: [(String, ConversationChunk.ChunkType)] = []
        var currentText = ""
        var currentType: ConversationChunk.ChunkType = .assistantResponse

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("**User:**") {
                // Flush previous segment
                if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rawSegments.append((currentText.trimmingCharacters(in: .whitespacesAndNewlines), currentType))
                }
                currentText = trimmed
                currentType = .userQuestion
            } else if trimmed.hasPrefix("**Claude:**") {
                if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rawSegments.append((currentText.trimmingCharacters(in: .whitespacesAndNewlines), currentType))
                }
                currentText = trimmed
                currentType = .assistantResponse
            } else if trimmed.hasPrefix("> Tool:") {
                if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rawSegments.append((currentText.trimmingCharacters(in: .whitespacesAndNewlines), currentType))
                }
                // Tool lines get their own segment
                rawSegments.append((trimmed, .toolSummary))
                currentText = ""
                currentType = .assistantResponse
            } else {
                // Continuation of current segment
                if currentText.isEmpty {
                    currentText = trimmed
                } else {
                    currentText += "\n" + line
                }
            }
        }

        // Flush final segment
        if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rawSegments.append((currentText.trimmingCharacters(in: .whitespacesAndNewlines), currentType))
        }

        // Split oversized segments and build chunks
        var chunks: [ConversationChunk] = []
        var index = 0

        for (text, type) in rawSegments {
            let pieces = splitToFit(text)
            for piece in pieces {
                let chunk = ConversationChunk(
                    sessionId: sessionId,
                    projectPath: projectPath,
                    timestamp: timestamp,
                    chunkIndex: index,
                    content: piece,
                    chunkType: type
                )
                chunks.append(chunk)
                index += 1
            }
        }

        // Merge consecutive small tool summaries
        chunks = mergeSmallChunks(chunks, sessionId: sessionId, projectPath: projectPath, timestamp: timestamp)

        return chunks
    }

    // MARK: - JSONL Chunking

    /// Break JSONL conversation content into semantic chunks
    func chunkFromJSONL(
        jsonlContent: String,
        sessionId: String,
        projectPath: String,
        timestamp: Date
    ) -> [ConversationChunk] {
        let lines = jsonlContent.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var rawSegments: [(String, ConversationChunk.ChunkType)] = []

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let type = json["type"] as? String ?? ""
            let content = extractContent(from: json)

            guard !content.isEmpty else { continue }

            switch type {
            case "user":
                rawSegments.append((content, .userQuestion))

            case "assistant":
                // Check if this looks like a decision/reasoning
                let lowerContent = content.lowercased()
                if lowerContent.contains("i'll") || lowerContent.contains("let me") || lowerContent.contains("i need to") {
                    rawSegments.append((content, .decision))
                } else {
                    rawSegments.append((content, .assistantResponse))
                }

            case "tool_use", "tool_result":
                let toolName = json["name"] as? String ?? "tool"
                let summary = "\(toolName): \(content)"
                rawSegments.append((summary, .toolSummary))

            default:
                // Group unknown types as assistant response
                if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rawSegments.append((content, .assistantResponse))
                }
            }
        }

        // Group related consecutive tool summaries
        rawSegments = groupToolSummaries(rawSegments)

        // Split oversized and build final chunks
        var chunks: [ConversationChunk] = []
        var index = 0

        for (text, type) in rawSegments {
            let pieces = splitToFit(text)
            for piece in pieces {
                let chunk = ConversationChunk(
                    sessionId: sessionId,
                    projectPath: projectPath,
                    timestamp: timestamp,
                    chunkIndex: index,
                    content: piece,
                    chunkType: type
                )
                chunks.append(chunk)
                index += 1
            }
        }

        return chunks
    }

    // MARK: - Private Helpers

    /// Estimate token count from text
    private func estimateTokens(_ text: String) -> Int {
        max(1, text.split(separator: " ").count * 13 / 10)
    }

    /// Split text to fit within token bounds, preserving semantic boundaries
    private func splitToFit(_ text: String) -> [String] {
        let tokens = estimateTokens(text)
        if tokens <= maxTokens {
            return [text]
        }

        // Try splitting on double newlines first
        let doubleNewlineParts = text.components(separatedBy: "\n\n")
        if doubleNewlineParts.count > 1 {
            return rebucket(doubleNewlineParts)
        }

        // Try single newlines
        let newlineParts = text.components(separatedBy: "\n")
        if newlineParts.count > 1 {
            return rebucket(newlineParts)
        }

        // Fall back to sentence boundaries
        let sentenceParts = text.components(separatedBy: ". ")
        if sentenceParts.count > 1 {
            // Re-add the period to each part except the last
            var restored: [String] = []
            for (i, part) in sentenceParts.enumerated() {
                if i < sentenceParts.count - 1 {
                    restored.append(part + ".")
                } else {
                    restored.append(part)
                }
            }
            return rebucket(restored)
        }

        // Can't split meaningfully, return as-is
        return [text]
    }

    /// Combine small pieces into buckets that stay under maxTokens
    private func rebucket(_ pieces: [String]) -> [String] {
        var buckets: [String] = []
        var current = ""

        for piece in pieces {
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let combined = current.isEmpty ? trimmed : current + "\n\n" + trimmed
            if estimateTokens(combined) <= maxTokens {
                current = combined
            } else {
                if !current.isEmpty {
                    buckets.append(current)
                }
                current = trimmed
            }
        }

        if !current.isEmpty {
            buckets.append(current)
        }

        return buckets
    }

    /// Merge consecutive small chunks of the same type
    private func mergeSmallChunks(
        _ chunks: [ConversationChunk],
        sessionId: String,
        projectPath: String,
        timestamp: Date
    ) -> [ConversationChunk] {
        guard chunks.count > 1 else { return chunks }

        var merged: [ConversationChunk] = []
        var i = 0

        while i < chunks.count {
            var current = chunks[i]

            // Try to merge consecutive same-type small chunks
            while i + 1 < chunks.count,
                  chunks[i + 1].chunkType == current.chunkType,
                  current.tokenEstimate < minTokens || chunks[i + 1].tokenEstimate < minTokens {
                let next = chunks[i + 1]
                let combinedContent = current.content + "\n" + next.content
                let combinedTokens = estimateTokens(combinedContent)

                if combinedTokens <= maxTokens {
                    current = ConversationChunk(
                        sessionId: sessionId,
                        projectPath: projectPath,
                        timestamp: timestamp,
                        chunkIndex: merged.count,
                        content: combinedContent,
                        chunkType: current.chunkType
                    )
                    i += 1
                } else {
                    break
                }
            }

            // Re-index
            let reindexed = ConversationChunk(
                sessionId: sessionId,
                projectPath: projectPath,
                timestamp: timestamp,
                chunkIndex: merged.count,
                content: current.content,
                chunkType: current.chunkType
            )
            merged.append(reindexed)
            i += 1
        }

        return merged
    }

    /// Group consecutive tool summary segments together
    private func groupToolSummaries(_ segments: [(String, ConversationChunk.ChunkType)]) -> [(String, ConversationChunk.ChunkType)] {
        var result: [(String, ConversationChunk.ChunkType)] = []
        var toolBuffer = ""

        for (text, type) in segments {
            if type == .toolSummary {
                if toolBuffer.isEmpty {
                    toolBuffer = text
                } else {
                    let combined = toolBuffer + "\n" + text
                    if estimateTokens(combined) <= maxTokens {
                        toolBuffer = combined
                    } else {
                        result.append((toolBuffer, .toolSummary))
                        toolBuffer = text
                    }
                }
            } else {
                if !toolBuffer.isEmpty {
                    result.append((toolBuffer, .toolSummary))
                    toolBuffer = ""
                }
                result.append((text, type))
            }
        }

        if !toolBuffer.isEmpty {
            result.append((toolBuffer, .toolSummary))
        }

        return result
    }

    /// Extract readable content from a parsed JSON line
    private func extractContent(from json: [String: Any]) -> String {
        // Try "content" as string
        if let content = json["content"] as? String {
            return content
        }

        // Try "content" as array of content blocks (Claude API format)
        if let contentArray = json["content"] as? [[String: Any]] {
            let texts = contentArray.compactMap { block -> String? in
                if block["type"] as? String == "text" {
                    return block["text"] as? String
                }
                return nil
            }
            if !texts.isEmpty {
                return texts.joined(separator: "\n")
            }
        }

        // Try "message" field
        if let message = json["message"] as? String {
            return message
        }

        // Try "text" field
        if let text = json["text"] as? String {
            return text
        }

        // Try "input" for tool calls
        if let input = json["input"] as? [String: Any] {
            let pairs = input.map { "\($0.key): \($0.value)" }
            return pairs.joined(separator: ", ")
        }

        return ""
    }
}
