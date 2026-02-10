import Foundation

// MARK: - Raw JSON Decodable Types

/// Top-level envelope from Claude Code stream-json
struct ClaudeStreamEvent: Decodable {
    let type: String
    let subtype: String?
    let sessionId: String?
    let message: ClaudeStreamMessage?
    // Result fields
    let totalCostUsd: Double?
    let durationMs: Int?
    let durationApiMs: Int?
    let numTurns: Int?
    let isError: Bool?
    let usage: ClaudeUsage?

    enum CodingKeys: String, CodingKey {
        case type, subtype, message, usage
        case sessionId = "session_id"
        case totalCostUsd = "total_cost_usd"
        case durationMs = "duration_ms"
        case durationApiMs = "duration_api_ms"
        case numTurns = "num_turns"
        case isError = "is_error"
    }
}

struct ClaudeUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

struct ClaudeStreamMessage: Decodable {
    let role: String?
    let content: [ClaudeContentBlock]?
}

struct ClaudeContentBlock: Decodable {
    let type: String
    let text: String?
    // Tool use fields
    let id: String?
    let name: String?
    let input: ClaudeToolInput?
    // Tool result fields
    let toolUseId: String?
    let content: String?

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, content
        case toolUseId = "tool_use_id"
    }
}

/// Flexible tool input that captures common fields
struct ClaudeToolInput: Decodable {
    let command: String?
    let filePath: String?
    let content: String?
    let pattern: String?
    let oldString: String?
    let newString: String?

    // Capture all fields as raw dictionary for display
    let raw: [String: AnyCodableValue]

    enum CodingKeys: String, CodingKey {
        case command
        case filePath = "file_path"
        case content, pattern
        case oldString = "old_string"
        case newString = "new_string"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
        oldString = try container.decodeIfPresent(String.self, forKey: .oldString)
        newString = try container.decodeIfPresent(String.self, forKey: .newString)

        // Also decode everything as raw key-value pairs
        let rawContainer = try decoder.singleValueContainer()
        raw = (try? rawContainer.decode([String: AnyCodableValue].self)) ?? [:]
    }
}

/// Type-erased Codable value for raw JSON display
enum AnyCodableValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let i = try? container.decode(Int.self) { self = .int(i) }
        else if let d = try? container.decode(Double.self) { self = .double(d) }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else { self = .null }
    }

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return "\(i)"
        case .double(let d): return "\(d)"
        case .bool(let b): return "\(b)"
        case .null: return "null"
        }
    }
}

// MARK: - App-Level Event Types

/// Parsed, typed event for use in the app
enum ClaudeEvent {
    case system(sessionId: String)
    case assistantText(String)
    case toolUse(ToolUseEvent)
    case toolResult(toolUseId: String, output: String)
    case userMessage(String)
    case result(ResultEvent)
    case error(String)

    /// Parse a raw stream event into one or more app events
    static func from(_ raw: ClaudeStreamEvent) -> [ClaudeEvent] {
        var events: [ClaudeEvent] = []

        switch raw.type {
        case "system":
            events.append(.system(sessionId: raw.sessionId ?? "unknown"))

        case "assistant":
            if let content = raw.message?.content {
                for block in content {
                    switch block.type {
                    case "text":
                        if let text = block.text, !text.isEmpty {
                            events.append(.assistantText(text))
                        }
                    case "tool_use":
                        if let name = block.name {
                            events.append(.toolUse(ToolUseEvent(
                                toolUseId: block.id ?? "",
                                name: name,
                                input: block.input
                            )))
                        }
                    case "tool_result":
                        events.append(.toolResult(
                            toolUseId: block.toolUseId ?? "",
                            output: block.content ?? ""
                        ))
                    default:
                        break
                    }
                }
            }

        case "user":
            if let content = raw.message?.content {
                let text = content.compactMap(\.text).joined()
                if !text.isEmpty {
                    events.append(.userMessage(text))
                }
            }

        case "result":
            events.append(.result(ResultEvent(
                costUsd: raw.totalCostUsd ?? 0,
                durationMs: raw.durationMs ?? 0,
                durationApiMs: raw.durationApiMs ?? 0,
                numTurns: raw.numTurns ?? 0,
                sessionId: raw.sessionId ?? "",
                isError: raw.isError ?? false,
                inputTokens: raw.usage?.inputTokens ?? 0,
                outputTokens: raw.usage?.outputTokens ?? 0,
                cacheCreationTokens: raw.usage?.cacheCreationInputTokens ?? 0,
                cacheReadTokens: raw.usage?.cacheReadInputTokens ?? 0
            )))

        default:
            break
        }

        return events
    }
}

struct ToolUseEvent {
    let toolUseId: String
    let name: String
    let input: ClaudeToolInput?

    /// One-line summary for collapsed display
    var summary: String {
        switch name {
        case "Bash":
            return input?.command ?? "command"
        case "Read":
            return input?.filePath ?? "file"
        case "Write":
            return input?.filePath ?? "file"
        case "Edit":
            return input?.filePath ?? "file"
        case "Grep":
            return input?.pattern ?? "search"
        case "Glob":
            return input?.pattern ?? "pattern"
        default:
            return name
        }
    }
}

struct ResultEvent {
    let costUsd: Double
    let durationMs: Int
    let durationApiMs: Int
    let numTurns: Int
    let sessionId: String
    let isError: Bool
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    var formattedCost: String {
        if costUsd >= 1.0 {
            return String(format: "$%.2f", costUsd)
        }
        return String(format: "$%.4f", costUsd)
    }

    var formattedDuration: String {
        let seconds = durationMs / 1000
        if seconds >= 60 {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
        return "\(seconds)s"
    }

    var formattedTokens: String {
        let total = totalTokens
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        } else if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000)
        }
        return "\(total)"
    }
}
