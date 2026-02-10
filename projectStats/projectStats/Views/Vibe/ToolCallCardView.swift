import SwiftUI

struct ToolCallCardView: View {
    let message: VibeChatMessage
    let onToggle: () -> Void

    var body: some View {
        if case .toolCall(let name, let summary, let input, let result, let isExpanded) = message.content {
            VStack(alignment: .leading, spacing: 0) {
                // Header - always visible
                Button(action: onToggle) {
                    HStack(spacing: 8) {
                        Image(systemName: toolIcon(name))
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .frame(width: 16)

                        Text(name)
                            .font(.caption.bold())
                            .foregroundStyle(.primary)

                        Text(summary)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        if result != nil {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                        } else {
                            ProgressView()
                                .controlSize(.mini)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Expanded content
                if isExpanded {
                    Divider()
                        .padding(.horizontal, 12)

                    if !input.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input")
                                .font(.caption2.bold())
                                .foregroundStyle(.tertiary)
                            Text(input)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }

                    if let result, !result.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.caption2.bold())
                                .foregroundStyle(.tertiary)
                            ScrollView {
                                Text(result.prefix(2000))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    private func toolIcon(_ name: String) -> String {
        switch name {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Write": return "doc.text.fill"
        case "Edit": return "pencil"
        case "Grep": return "magnifyingglass"
        case "Glob": return "folder.badge.questionmark"
        case "Task": return "person.2"
        default: return "wrench"
        }
    }
}
