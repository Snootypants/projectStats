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
        Text(text)
            .font(.body)
            .foregroundStyle(.primary.opacity(0.9))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
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
