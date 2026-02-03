import AppKit
import SwiftUI

struct ClaudeConfigSheet: View {
    let projectPath: URL

    @Environment(\.dismiss) private var dismiss
    @State private var claudeExists = false
    @State private var commandFiles: [URL] = []
    @State private var hookFiles: [URL] = []
    @State private var showNewCommandPrompt = false
    @State private var showNewHookPrompt = false
    @State private var newCommandName = ""
    @State private var newHookName = ""

    private var claudeURL: URL { projectPath.appendingPathComponent(".claude") }
    private var claudeFileURL: URL { claudeURL.appendingPathComponent("CLAUDE.md") }
    private var commandsURL: URL { claudeURL.appendingPathComponent("commands") }
    private var hooksURL: URL { claudeURL.appendingPathComponent("hooks") }
    private var settingsURL: URL { claudeURL.appendingPathComponent("settings.json") }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Claude Configuration")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
            }

            if !claudeExists {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No .claude folder found for this project.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Create .claude Folder") { createClaudeFolder() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("CLAUDE.md")
                        fileRow(url: claudeFileURL)

                        Divider()

                        sectionHeader("commands/")
                        if commandFiles.isEmpty {
                            Text("(empty)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(commandFiles, id: \.self) { file in
                                fileRow(url: file)
                            }
                        }
                        Button("+ Add Command") { showNewCommandPrompt = true }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                        Divider()

                        sectionHeader("hooks/")
                        if hookFiles.isEmpty {
                            Text("(empty)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(hookFiles, id: \.self) { file in
                                fileRow(url: file)
                            }
                        }
                        Button("+ Add Hook") { showNewHookPrompt = true }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                        Divider()

                        sectionHeader("settings.json")
                        fileRow(url: settingsURL)

                        Divider()

                        sectionHeader("MCP Servers")
                        Text("Configure MCP servers inside settings.json.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        sectionHeader("Templates")
                        HStack(spacing: 8) {
                            Button("Swift/iOS") { applyTemplate(.swift) }
                            Button("Next.js") { applyTemplate(.nextjs) }
                            Button("Python") { applyTemplate(.python) }
                            Button("Custom") { applyTemplate(.custom) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 520)
        .onAppear { refresh() }
        .alert("New Command", isPresented: $showNewCommandPrompt) {
            TextField("command.md", text: $newCommandName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { createCommand() }
        }
        .alert("New Hook", isPresented: $showNewHookPrompt) {
            TextField("hook.md", text: $newHookName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { createHook() }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func fileRow(url: URL) -> some View {
        HStack {
            Text(url.lastPathComponent)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button("Edit") { openFile(url) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func refresh() {
        claudeExists = FileManager.default.fileExists(atPath: claudeURL.path)
        guard claudeExists else { return }

        commandFiles = (try? FileManager.default.contentsOfDirectory(at: commandsURL, includingPropertiesForKeys: nil)) ?? []
        hookFiles = (try? FileManager.default.contentsOfDirectory(at: hooksURL, includingPropertiesForKeys: nil)) ?? []
    }

    private func createClaudeFolder() {
        try? FileManager.default.createDirectory(at: claudeURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: commandsURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: hooksURL, withIntermediateDirectories: true)
        refresh()
    }

    private func createCommand() {
        let trimmed = newCommandName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url = commandsURL.appendingPathComponent(trimmed)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
        openFile(url)
        newCommandName = ""
        refresh()
    }

    private func createHook() {
        let trimmed = newHookName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url = hooksURL.appendingPathComponent(trimmed)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
        openFile(url)
        newHookName = ""
        refresh()
    }

    private func openFile(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(url)
    }

    private func applyTemplate(_ template: ClaudeTemplate) {
        let content = template.content
        createClaudeFolderIfNeeded()
        try? content.write(to: claudeFileURL, atomically: true, encoding: .utf8)
        openFile(claudeFileURL)
        refresh()
    }

    private func createClaudeFolderIfNeeded() {
        if !FileManager.default.fileExists(atPath: claudeURL.path) {
            createClaudeFolder()
        }
    }
}

enum ClaudeTemplate {
    case swift
    case nextjs
    case python
    case custom

    var content: String {
        switch self {
        case .swift:
            return """
# Claude Instructions (Swift/iOS)

- Focus on SwiftUI patterns and AppKit interoperability where required.
- Prefer concise, native macOS UI.
- Keep code and filenames aligned with the project structure.
"""
        case .nextjs:
            return """
# Claude Instructions (Next.js)

- Prefer server components by default.
- Keep client components small and isolated.
- Use TypeScript and keep data fetching in app routes.
"""
        case .python:
            return """
# Claude Instructions (Python)

- Prefer standard library unless otherwise noted.
- Keep scripts idempotent and fast.
- Add small, focused docstrings for public functions.
"""
        case .custom:
            return """
# Claude Instructions

- Describe project constraints and preferred patterns here.
"""
        }
    }
}

#Preview {
    ClaudeConfigSheet(projectPath: URL(fileURLWithPath: "/tmp"))
}
