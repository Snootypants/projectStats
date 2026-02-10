import SwiftUI
import SwiftData

struct SessionHistoryView: View {
    let projectPath: String
    let onView: (ConversationSession) -> Void
    let onContinue: (ConversationSession) -> Void

    @State private var sessions: [ConversationSession] = []

    var body: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Sessions")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(sessions, id: \.id) { session in
                    sessionRow(session)
                }
            }
            .frame(width: 360)
            .onAppear { loadSessions() }
        } else {
            EmptyView()
                .onAppear { loadSessions() }
        }
    }

    private func sessionRow(_ session: ConversationSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.endedAt ?? session.startedAt, style: .date)
                    .font(.caption.bold())
                HStack(spacing: 8) {
                    Label("\(session.durationMs / 1000)s", systemImage: "clock")
                    Label(String(format: "$%.4f", session.costUsd), systemImage: "dollarsign.circle")
                    Label("\(session.numTurns) turns", systemImage: "arrow.triangle.2.circlepath")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                // Token details
                if session.totalTokens > 0 {
                    HStack(spacing: 8) {
                        Label(formatTokenCount(session.totalTokens) + " tok", systemImage: "brain")
                        if session.tokensPerSecond > 0 {
                            Label(String(format: "%.0f tok/s", session.tokensPerSecond), systemImage: "speedometer")
                        }
                        if session.isError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                if let summary = firstUserMessage(for: session) {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button("View") { onView(session) }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                Button("Continue") { onContinue(session) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private func loadSessions() {
        let context = AppModelContainer.shared.mainContext
        let path = projectPath
        var descriptor = FetchDescriptor<ConversationSession>(
            predicate: #Predicate { $0.projectPath == path },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        sessions = (try? context.fetch(descriptor)) ?? []
    }

    private func firstUserMessage(for session: ConversationSession) -> String? {
        let projectURL = URL(fileURLWithPath: session.projectPath)
        let conversationsDir = projectURL.appendingPathComponent(".claude/conversations")

        // Find matching .md file by session ID prefix
        let shortId = String(session.sessionId.prefix(8))
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: conversationsDir, includingPropertiesForKeys: nil
        ) else { return nil }

        guard let mdFile = files.first(where: { $0.lastPathComponent.contains(shortId) && $0.pathExtension == "md" }),
              let content = try? String(contentsOf: mdFile, encoding: .utf8) else { return nil }

        // Find first "**User:**" line
        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("**User:**") {
                return String(line.dropFirst("**User:** ".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
