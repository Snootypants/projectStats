import Foundation

struct VibeChatMessage: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let role: MessageRole
    var content: MessageContent  // var so we can update tool results and permission status

    enum MessageRole: Equatable {
        case user
        case assistant
        case system
        case tool
    }

    enum MessageContent: Equatable {
        case text(String)
        case toolCall(name: String, summary: String, input: String, result: String?, isExpanded: Bool)
        case permissionRequest(tool: String, description: String, command: String?, status: PermissionStatus)
        case error(String)
        case sessionStats(cost: String, duration: String, turns: Int, sessionId: String)
    }

    enum PermissionStatus: Equatable {
        case pending
        case allowed
        case denied
        case autoApproved
    }

    // MARK: - Factory Methods

    static func fromUser(_ text: String) -> VibeChatMessage {
        VibeChatMessage(
            id: UUID(),
            timestamp: Date(),
            role: .user,
            content: .text(text)
        )
    }

    static func fromAssistantText(_ text: String) -> VibeChatMessage {
        VibeChatMessage(
            id: UUID(),
            timestamp: Date(),
            role: .assistant,
            content: .text(text)
        )
    }

    static func fromToolUse(_ event: ToolUseEvent) -> VibeChatMessage {
        // Format input as readable string
        let inputStr: String
        if let input = event.input {
            let parts = input.raw.map { "\($0.key): \($0.value.stringValue)" }
            inputStr = parts.joined(separator: "\n")
        } else {
            inputStr = ""
        }

        return VibeChatMessage(
            id: UUID(),
            timestamp: Date(),
            role: .tool,
            content: .toolCall(
                name: event.name,
                summary: event.summary,
                input: inputStr,
                result: nil,
                isExpanded: false
            )
        )
    }

    static func fromResult(_ event: ResultEvent) -> VibeChatMessage {
        VibeChatMessage(
            id: UUID(),
            timestamp: Date(),
            role: .system,
            content: .sessionStats(
                cost: event.formattedCost,
                duration: event.formattedDuration,
                turns: event.numTurns,
                sessionId: event.sessionId
            )
        )
    }

    static func fromError(_ message: String) -> VibeChatMessage {
        VibeChatMessage(
            id: UUID(),
            timestamp: Date(),
            role: .system,
            content: .error(message)
        )
    }

    static func permissionRequest(tool: String, description: String, command: String?) -> VibeChatMessage {
        VibeChatMessage(
            id: UUID(),
            timestamp: Date(),
            role: .system,
            content: .permissionRequest(
                tool: tool,
                description: description,
                command: command,
                status: .pending
            )
        )
    }

    // MARK: - Equatable (needed for SwiftUI diffing)

    static func == (lhs: VibeChatMessage, rhs: VibeChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}
