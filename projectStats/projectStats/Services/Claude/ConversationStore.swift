import Foundation
import SwiftData

@MainActor
final class ConversationStore {
    static let shared = ConversationStore()
    private init() {}

    /// Save a completed session's raw JSONL and summary to disk, index in SwiftData
    func saveSession(
        projectPath: String,
        sessionId: String,
        messages: [VibeChatMessage],
        rawLines: [String],
        toolBreakdown: [String: Int],
        costUsd: Double,
        durationMs: Int,
        numTurns: Int,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0,
        durationApiMs: Int = 0,
        isError: Bool = false
    ) {
        let projectURL = URL(fileURLWithPath: projectPath)

        // Create .claude/conversations/ directory
        let conversationsDir = projectURL.appendingPathComponent(".claude/conversations")
        try? FileManager.default.createDirectory(at: conversationsDir, withIntermediateDirectories: true)

        // Ensure .gitignore includes .claude/conversations/
        ensureGitignore(projectURL: projectURL)

        // Generate filenames
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = formatter.string(from: Date())
        let shortId = String(sessionId.prefix(8))
        let baseName = "\(timestamp)_\(shortId)"

        // Save raw JSONL
        let jsonlPath = conversationsDir.appendingPathComponent("\(baseName).jsonl")
        let jsonlContent = rawLines.joined(separator: "\n")
        try? jsonlContent.write(to: jsonlPath, atomically: true, encoding: .utf8)

        // Save human-readable summary
        let summaryPath = conversationsDir.appendingPathComponent("\(baseName).md")
        let summary = buildSummary(messages: messages, sessionId: sessionId, costUsd: costUsd, durationMs: durationMs, numTurns: numTurns)
        try? summary.write(to: summaryPath, atomically: true, encoding: .utf8)

        // Extract files touched from Write/Edit tool calls
        let filesTouched = extractFilesTouched(messages: messages)

        // Index in SwiftData
        let session = ConversationSession(
            projectPath: projectPath,
            sessionId: sessionId,
            durationMs: durationMs,
            costUsd: costUsd,
            numTurns: numTurns,
            toolCallCounts: toolBreakdown,
            filesTouched: filesTouched,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            durationApiMs: durationApiMs,
            isError: isError
        )
        session.endedAt = Date()

        let context = AppModelContainer.shared.mainContext
        context.insert(session)
        context.safeSave()

        // Trigger memory pipeline in background
        Task {
            await MemoryPipeline.shared.indexSession(
                projectPath: projectPath,
                sessionId: sessionId,
                rawLines: rawLines,
                summary: summary
            )
        }
    }

    // MARK: - Private

    private func ensureGitignore(projectURL: URL) {
        let gitignorePath = projectURL.appendingPathComponent(".gitignore")
        let entry = ".claude/conversations/"

        if FileManager.default.fileExists(atPath: gitignorePath.path) {
            if let content = try? String(contentsOf: gitignorePath, encoding: .utf8) {
                if !content.contains(entry) {
                    let updated = content + "\n\(entry)\n"
                    try? updated.write(to: gitignorePath, atomically: true, encoding: .utf8)
                }
            }
        } else {
            try? "\(entry)\n".write(to: gitignorePath, atomically: true, encoding: .utf8)
        }
    }

    private func buildSummary(messages: [VibeChatMessage], sessionId: String, costUsd: Double, durationMs: Int, numTurns: Int) -> String {
        var lines: [String] = []
        lines.append("# Vibe Session \(sessionId.prefix(8))")
        lines.append("")
        lines.append("- Cost: $\(String(format: "%.4f", costUsd))")
        lines.append("- Duration: \(durationMs / 1000)s")
        lines.append("- Turns: \(numTurns)")
        lines.append("")

        for msg in messages {
            switch msg.content {
            case .text(let text):
                let prefix = msg.role == .user ? "**User:**" : "**Claude:**"
                lines.append("\(prefix) \(text)")
                lines.append("")
            case .toolCall(let name, let summary, _, _, _, _):
                lines.append("> Tool: \(name) — \(summary)")
            case .error(let text):
                lines.append("> Error: \(text)")
            default:
                break
            }
        }

        return lines.joined(separator: "\n")
    }

    private func extractFilesTouched(messages: [VibeChatMessage]) -> [String] {
        var files = Set<String>()
        for msg in messages {
            if case .toolCall(let name, let summary, _, _, _, _) = msg.content {
                if name == "Write" || name == "Edit" {
                    files.insert(summary)
                }
            }
        }
        return Array(files)
    }
}
