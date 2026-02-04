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
            .sorted {
                // Sort by prompt number if sourceFile exists, otherwise by date
                if let sf1 = $0.sourceFile, let sf2 = $1.sourceFile {
                    return extractNumber(from: sf1) < extractNumber(from: sf2)
                }
                // If only one has sourceFile, prioritize it
                if $0.sourceFile != nil && $1.sourceFile == nil { return true }
                if $0.sourceFile == nil && $1.sourceFile != nil { return false }
                // Both have no sourceFile, sort by date
                return $0.createdAt < $1.createdAt
            }
    }

    private var selectedPrompt: SavedPrompt? {
        guard let id = selectedPromptID else { return nil }
        return savedPrompts.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if savedPrompts.isEmpty {
                emptyState
            } else {
                // Horizontal prompt tabs
                promptTabBar

                Divider()

                // Full prompt content
                promptContent

                Divider()

                // Action buttons
                actionBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Select first prompt by default
            if selectedPromptID == nil, let first = savedPrompts.first {
                selectedPromptID = first.id
            }
        }
    }

    // MARK: - Prompt Tab Bar

    private var promptTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(savedPrompts) { prompt in
                    promptTab(for: prompt)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.primary.opacity(0.03))
    }

    private func promptTab(for prompt: SavedPrompt) -> some View {
        let isSelected = selectedPromptID == prompt.id
        let label = promptLabel(for: prompt)

        return Button {
            selectedPromptID = prompt.id
        } label: {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func promptLabel(for prompt: SavedPrompt) -> String {
        if let sourceFile = prompt.sourceFile {
            // Extract number from filename like "1.md", "2c.md", "10.md"
            let name = sourceFile.replacingOccurrences(of: ".md", with: "")
            return name
        } else {
            // For prompts sent via terminal, use index
            if let index = savedPrompts.firstIndex(where: { $0.id == prompt.id }) {
                return "S\(index + 1)"  // S for "Sent"
            }
            return "?"
        }
    }

    // MARK: - Prompt Content

    private var promptContent: some View {
        ScrollView {
            if let prompt = selectedPrompt {
                Text(prompt.text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                Text("Select a prompt")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .disabled(selectedPrompt == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No prompts yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Send a prompt using the field below the terminal")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Helpers

    private func extractNumber(from filename: String) -> Int {
        let name = filename.replacingOccurrences(of: ".md", with: "")
        // Extract leading digits: "2c" -> 2, "10" -> 10
        var numStr = ""
        for char in name {
            if char.isNumber {
                numStr.append(char)
            } else {
                break
            }
        }
        return Int(numStr) ?? 999
    }
}
