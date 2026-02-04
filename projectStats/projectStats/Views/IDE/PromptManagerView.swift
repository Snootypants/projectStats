import SwiftData
import SwiftUI

struct PromptManagerView: View {
    let projectPath: URL

    @Query private var allSavedPrompts: [SavedPrompt]
    @State private var selectedPromptID: UUID?
    @State private var showCopiedAlert: Bool = false

    private var savedPrompts: [SavedPrompt] {
        allSavedPrompts
            .filter { $0.projectPath == projectPath.path }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var selectedPrompt: SavedPrompt? {
        guard let id = selectedPromptID else { return nil }
        return savedPrompts.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            if savedPrompts.isEmpty {
                emptyState
            } else {
                promptList
            }

            Divider()

            // Bottom action bar
            actionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Select the most recent prompt by default
            if selectedPromptID == nil, let first = savedPrompts.first {
                selectedPromptID = first.id
            }
        }
    }

    // MARK: - Prompt List

    private var promptList: some View {
        List(savedPrompts, selection: $selectedPromptID) { prompt in
            PromptRow(prompt: prompt, isSelected: selectedPromptID == prompt.id)
                .tag(prompt.id)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
        .listStyle(.inset)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No prompts yet",
            systemImage: "text.bubble",
            description: Text("Send a prompt using the field below the terminal")
        )
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            if let prompt = selectedPrompt {
                Text("\(prompt.text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                copySelectedPrompt()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                    Text(showCopiedAlert ? "Copied!" : "Copy Prompt")
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.borderedProminent)
            .tint(showCopiedAlert ? .green : .accentColor)
            .disabled(selectedPrompt == nil)

            Button {
                openInClaudeCode()
            } label: {
                Label("Open Claude Code", systemImage: "terminal")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Actions

    private func copySelectedPrompt() {
        guard let prompt = selectedPrompt else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.text, forType: .string)

        showCopiedAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedAlert = false
        }
    }

    private func openInClaudeCode() {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(projectPath.path)' && claude"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - Prompt Row

struct PromptRow: View {
    let prompt: SavedPrompt
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prompt.text)
                .lineLimit(3)
                .font(.system(size: 13, design: .monospaced))

            HStack(spacing: 8) {
                Text(prompt.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if prompt.wasExecuted {
                    Label("Sent", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                Text("\(prompt.text.count) chars")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
