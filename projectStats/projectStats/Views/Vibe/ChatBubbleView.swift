import SwiftUI

struct ChatBubbleView: View {
    let message: VibeChatMessage

    var body: some View {
        switch message.content {
        case .text(let text):
            if message.role == .user {
                userBubble(text)
            } else {
                assistantBubble(text)
            }
        case .error(let text):
            errorBubble(text)
        case .sessionStats(let cost, let duration, let turns, let sessionId):
            statsCard(cost: cost, duration: duration, turns: turns, sessionId: sessionId)
        default:
            EmptyView() // tool calls and permissions handled by their own views
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 80)
            Text(text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(14)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func assistantBubble(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
            ForEach(Array(splitMarkdownSegments(text).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let str):
                    if let attributed = try? AttributedString(
                        markdown: str,
                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    ) {
                        Text(attributed)
                            .font(.body)
                            .foregroundStyle(.primary.opacity(0.9))
                            .textSelection(.enabled)
                    } else {
                        Text(str)
                            .font(.body)
                            .foregroundStyle(.primary.opacity(0.9))
                            .textSelection(.enabled)
                    }
                case .codeBlock(let code, let lang):
                    VStack(alignment: .leading, spacing: 0) {
                        if !lang.isEmpty {
                            Text(lang)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 6)
                        }
                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.9))
                            .textSelection(.enabled)
                            .padding(10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - Markdown Segment Splitting

    private enum MarkdownSegment {
        case text(String)
        case codeBlock(code: String, language: String)
    }

    private func splitMarkdownSegments(_ text: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        var remaining = text
        let codeBlockPattern = "```"

        while let openRange = remaining.range(of: codeBlockPattern) {
            // Text before the code block
            let before = String(remaining[remaining.startIndex..<openRange.lowerBound])
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.text(before))
            }

            // Find language hint (rest of the opening ``` line)
            let afterOpen = remaining[openRange.upperBound...]
            let langEnd = afterOpen.firstIndex(of: "\n") ?? afterOpen.endIndex
            let language = String(afterOpen[afterOpen.startIndex..<langEnd]).trimmingCharacters(in: .whitespaces)

            // Find closing ```
            let codeStart = langEnd < afterOpen.endIndex ? afterOpen.index(after: langEnd) : langEnd
            let codeArea = remaining[codeStart...]

            if let closeRange = codeArea.range(of: codeBlockPattern) {
                let code = String(codeArea[codeArea.startIndex..<closeRange.lowerBound])
                    .trimmingCharacters(in: .newlines)
                segments.append(.codeBlock(code: code, language: language))
                remaining = String(codeArea[closeRange.upperBound...])
            } else {
                // Unclosed code block — treat rest as code
                let code = String(codeArea).trimmingCharacters(in: .newlines)
                segments.append(.codeBlock(code: code, language: language))
                remaining = ""
            }
        }

        // Remaining text after all code blocks
        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(.text(remaining))
        }

        // If no segments found, return as plain text
        if segments.isEmpty {
            segments.append(.text(text))
        }

        return segments
    }

    private func errorBubble(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(text)
                .font(.caption)
                .foregroundStyle(.red.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func statsCard(cost: String, duration: String, turns: Int, sessionId: String) -> some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 20) {
                Label(cost, systemImage: "dollarsign.circle")
                Label(duration, systemImage: "clock")
                Label("\(turns) turns", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("Session: \(sessionId.prefix(8))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Divider()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
