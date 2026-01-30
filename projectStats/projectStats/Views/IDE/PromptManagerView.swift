import SwiftUI

struct PromptFile: Identifiable {
    let id = UUID()
    let number: Int
    let path: URL
    var content: String

    var name: String { "\(number).md" }
}

struct PromptManagerView: View {
    let projectPath: URL
    @State private var prompts: [PromptFile] = []
    @State private var selectedPrompt: PromptFile?
    @State private var newPromptText: String = ""
    @State private var isCreatingNew: Bool = false
    @State private var showCopiedAlert: Bool = false

    private var promptsPath: URL {
        projectPath.appendingPathComponent("prompts")
    }

    private var nextPromptNumber: Int {
        (prompts.map { $0.number }.max() ?? 0) + 1
    }

    private var tccCommand: String {
        let promptNum = selectedPrompt?.number ?? nextPromptNumber
        return "read /prompts/\(promptNum).md and execute. Push all your commits after you wrap up."
    }

    var body: some View {
        VStack(spacing: 0) {
            // Prompt tabs
            promptTabBar

            Divider()

            // Content area
            if isCreatingNew {
                newPromptEditor
            } else if let prompt = selectedPrompt {
                existingPromptViewer(prompt)
            } else {
                emptyState
            }

            Divider()

            // Bottom action bar
            actionBar
        }
        .onAppear { loadPrompts() }
    }

    // MARK: - Prompt Tab Bar

    private var promptTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(prompts) { prompt in
                    PromptTab(
                        prompt: prompt,
                        isSelected: selectedPrompt?.id == prompt.id,
                        onSelect: {
                            isCreatingNew = false
                            selectedPrompt = prompt
                        }
                    )
                }

                // New prompt tab
                Button {
                    isCreatingNew = true
                    selectedPrompt = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCreatingNew ? Color.accentColor.opacity(0.2) : Color.clear)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 40)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - New Prompt Editor

    private var newPromptEditor: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Prompt: \(nextPromptNumber).md")
                    .font(.headline)
                Spacer()
            }
            .padding()

            TextEditor(text: $newPromptText)
                .font(.system(size: 13, design: .monospaced))
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)

            HStack {
                Button("Clear") {
                    newPromptText = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save as \(nextPromptNumber).md") {
                    saveNewPrompt()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
    }

    // MARK: - Existing Prompt Viewer

    private func existingPromptViewer(_ prompt: PromptFile) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Prompt \(prompt.number)")
                    .font(.headline)
                Spacer()

                Text("\(prompt.content.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            ScrollView {
                Text(prompt.content)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No prompts yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Click 'New' to create your first prompt")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        VStack(spacing: 12) {
            // tCC Command Display
            HStack {
                Text(tccCommand)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    copyTCCCommand()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                        Text(showCopiedAlert ? "Copied!" : "Copy tCC Command")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .tint(showCopiedAlert ? .green : .accentColor)
            }

            // Quick actions
            HStack {
                Button {
                    openInClaudeCode()
                } label: {
                    Label("Open in Claude Code", systemImage: "terminal")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    openPromptsFolder()
                } label: {
                    Label("Open Prompts Folder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Actions

    private func loadPrompts() {
        let fm = FileManager.default

        // Create prompts folder if it doesn't exist
        if !fm.fileExists(atPath: promptsPath.path) {
            try? fm.createDirectory(at: promptsPath, withIntermediateDirectories: true)
        }

        guard let contents = try? fm.contentsOfDirectory(at: promptsPath, includingPropertiesForKeys: nil) else {
            prompts = []
            return
        }

        prompts = contents
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> PromptFile? in
                let name = url.deletingPathExtension().lastPathComponent
                guard let number = Int(name) else { return nil }
                let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                return PromptFile(number: number, path: url, content: content)
            }
            .sorted { $0.number < $1.number }

        // Select the latest prompt by default
        if selectedPrompt == nil && !isCreatingNew {
            selectedPrompt = prompts.last
        }
    }

    private func saveNewPrompt() {
        let fileName = "\(nextPromptNumber).md"
        let filePath = promptsPath.appendingPathComponent(fileName)

        do {
            // Create prompts directory if needed
            try FileManager.default.createDirectory(at: promptsPath, withIntermediateDirectories: true)

            // Write the file
            try newPromptText.write(to: filePath, atomically: true, encoding: .utf8)

            // Reload and select the new prompt
            loadPrompts()
            selectedPrompt = prompts.last
            isCreatingNew = false
            newPromptText = ""
        } catch {
            print("Failed to save prompt: \(error)")
        }
    }

    private func copyTCCCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(tccCommand, forType: .string)

        showCopiedAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedAlert = false
        }
    }

    private func openInClaudeCode() {
        // Open terminal at project path and run claude
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

    private func openPromptsFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: promptsPath.path)
    }
}

struct PromptTab: View {
    let prompt: PromptFile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text("\(prompt.number).md")
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
