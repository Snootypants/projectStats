import AppKit
import SwiftUI

struct TerminalPanelView: View {
    @ObservedObject var viewModel: TerminalTabsViewModel
    @State private var showHistory = false
    @StateObject private var outputMonitor = TerminalOutputMonitor.shared
    @State private var promptText: String = ""
    @State private var swarmEnabled = false
    @FocusState private var isPromptFocused: Bool

    // State migrated from TerminalTabBar
    @State private var showCustomCommandSheet = false
    @State private var customCommand: String = ""
    @State private var showRenamePrompt = false
    @State private var renameTarget: TerminalTabItem?
    @State private var renameText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let detected = outputMonitor.lastDetectedError {
                ErrorBannerView(error: detected) {
                    outputMonitor.lastDetectedError = nil
                }
                Divider()
            }

            if let activeTab = viewModel.activeTab, activeTab.kind == .devServer {
                DevServerToolbar(tab: activeTab)
                Divider()
            }

            // Horizontal terminal tab row
            terminalTabRow

            Divider()

            // Terminal content
            TerminalTabView(viewModel: viewModel)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .clipped()

            Divider()

            // Send Prompt field
            sendPromptField
        }
        .background(Color.primary.opacity(0.02))
        .background {
            terminalShortcuts
        }
        .alert("Rename Tab", isPresented: $showRenamePrompt) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let target = renameTarget {
                    viewModel.renameTab(target, title: renameText)
                }
            }
        }
        .sheet(isPresented: $showCustomCommandSheet) {
            VStack(spacing: 16) {
                Text("Custom Command")
                    .font(.headline)
                TextField("Command", text: $customCommand)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showCustomCommandSheet = false
                        customCommand = ""
                    }
                    Button("Run") {
                        let trimmed = customCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            viewModel.addDevServerTab(command: trimmed)
                        }
                        showCustomCommandSheet = false
                        customCommand = ""
                    }
                }
            }
            .padding(20)
            .frame(width: 360)
        }
    }

    // MARK: - Horizontal Terminal Tab Row

    private var terminalTabRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(viewModel.tabs) { tab in
                    terminalTab(tab)
                }

                // + button with menu
                Menu {
                    Button("Shell") { viewModel.addShellTab() }
                    Divider()
                    Button("npm run dev") { viewModel.addDevServerTab(command: "npm run dev") }
                    Button("npm start") { viewModel.addDevServerTab(command: "npm start") }
                    Button("yarn dev") { viewModel.addDevServerTab(command: "yarn dev") }
                    Button("npx prisma studio") { viewModel.addDevServerTab(command: "npx prisma studio") }
                    Button("python manage.py runserver") { viewModel.addDevServerTab(command: "python manage.py runserver") }
                    Divider()
                    Button("Custom Command...") { showCustomCommandSheet = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 32)
        .background(Color.primary.opacity(0.03))
    }

    private func terminalTab(_ tab: TerminalTabItem) -> some View {
        let isActive = viewModel.activeTabID == tab.id

        return HStack(spacing: 6) {
            // Status dot
            Circle()
                .fill(statusColor(for: tab.status))
                .frame(width: 6, height: 6)

            // Tab label
            Text(tabLabel(for: tab))
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .lineLimit(1)

            // Port number for dev servers
            if tab.kind == .devServer, let port = tab.port {
                Text(":\(port)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                // Info icon with tooltip
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .help("localhost:\(port) — Click tab to copy URL")
            }

            // Close button (not for shell)
            if tab.kind != .shell {
                Button {
                    viewModel.closeTab(tab)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onTapGesture {
            if tab.kind == .devServer, let port = tab.port, viewModel.activeTabID == tab.id {
                // Already selected — copy URL
                let url = "http://localhost:\(port)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            } else {
                viewModel.selectTab(tab)
            }
        }
        .contextMenu {
            Button("Rename") {
                renameTarget = tab
                renameText = tab.title
                showRenamePrompt = true
            }
            Button("Duplicate") { viewModel.duplicateTab(tab) }
            Divider()
            Button("Clear Output") { tab.clearOutput() }
            Button("Kill Process") { tab.sendControlC() }
            if tab.kind != .shell {
                Button("Close") { viewModel.closeTab(tab) }
            }
        }
    }

    private func tabLabel(for tab: TerminalTabItem) -> String {
        switch tab.kind {
        case .shell: return "Shell"
        case .claude, .ccYolo, .codex, .devServer, .ghost: return tab.title
        }
    }

    private func statusColor(for status: TerminalTabStatus) -> Color {
        switch status {
        case .working: return .orange
        case .idle: return .green
        case .error: return .red
        case .needsAttention: return .yellow
        }
    }

    private var sendPromptField: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))

            if SettingsViewModel.shared.agentTeamsEnabled {
                Toggle(isOn: $swarmEnabled) {
                    HStack(spacing: 3) {
                        Image(systemName: swarmEnabled ? "person.3.fill" : "person.3")
                            .font(.system(size: 11))
                        Text("Swarm")
                            .font(.system(size: 11, weight: swarmEnabled ? .bold : .regular))
                    }
                    .foregroundStyle(swarmEnabled ? .orange : .secondary)
                }
                .toggleStyle(.checkbox)
                .help("Enable swarm mode - tells Claude to use agent teams")
            }

            TextField("Send prompt to Claude...", text: $promptText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isPromptFocused)
                .onSubmit {
                    sendPrompt()
                }

            Button {
                sendPrompt()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(promptText.isEmpty ? Color.secondary : Color.blue)
            }
            .buttonStyle(.plain)
            .disabled(promptText.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
    }

    private func sendPrompt() {
        guard !promptText.isEmpty else { return }

        var textToSend = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        if swarmEnabled {
            textToSend += "\n\nIMPORTANT: Use swarm mode for this task. Launch multiple sub-agents to work in parallel using the Task tool. Break the work into independent scopes and delegate each to a separate agent for maximum speed."
        }
        promptText = ""

        // First, send to terminal immediately (sendCommand adds carriage return to execute)
        if let activeTab = viewModel.activeTab {
            activeTab.sendCommand(textToSend)
            Log.terminal.info("[Prompts] Sent to terminal: \(textToSend.prefix(50))...")

            // Then save to database asynchronously
            Task { @MainActor in
                do {
                    let context = AppModelContainer.shared.mainContext
                    let saved = SavedPrompt(
                        text: textToSend,
                        projectPath: TerminalOutputMonitor.shared.activeProjectPath,
                        wasExecuted: true
                    )
                    context.insert(saved)
                    context.safeSave()
                    Log.terminal.debug("[Prompts] Saved prompt: \(textToSend.prefix(50))...")
                }
            }
        } else {
            Log.terminal.warning("[Prompts] No active terminal tab!")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .semibold))
                Text(viewModel.activeTab?.title ?? "Terminal")
                    .font(.system(size: 12, weight: .semibold))
            }

            Spacer()

            if SettingsViewModel.shared.showClaudeButton {
                Button("Claude") {
                    viewModel.addClaudeTab()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if SettingsViewModel.shared.showCcyoloButton {
                Button("ccYOLO") {
                    viewModel.addCcYoloTab()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if SettingsViewModel.shared.showCodexButton {
                Button("Codex") {
                    viewModel.addCodexTab()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                showHistory.toggle()
            } label: {
                Image(systemName: "clock")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showHistory, arrowEdge: .top) {
                TerminalHistoryPopover(commands: viewModel.activeTab?.commandHistory ?? [])
                    .frame(width: 280)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private var terminalShortcuts: some View {
        Group {
            Button("") { viewModel.selectTab(at: 0) }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { viewModel.selectTab(at: 1) }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { viewModel.selectTab(at: 2) }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { viewModel.selectTab(at: 3) }
                .keyboardShortcut("4", modifiers: .command)
            Button("") { viewModel.selectTab(at: 4) }
                .keyboardShortcut("5", modifiers: .command)
            Button("") { viewModel.selectTab(at: 5) }
                .keyboardShortcut("6", modifiers: .command)
            Button("") { viewModel.selectTab(at: 6) }
                .keyboardShortcut("7", modifiers: .command)
            Button("") { viewModel.selectTab(at: 7) }
                .keyboardShortcut("8", modifiers: .command)
            Button("") { viewModel.selectTab(at: 8) }
                .keyboardShortcut("9", modifiers: .command)

            Button("") { viewModel.addDevServerTab(command: "npm run dev") }
                .keyboardShortcut("t", modifiers: .command)
            Button("") { viewModel.closeActiveTab() }
                .keyboardShortcut("w", modifiers: .command)
            Button("") { viewModel.clearActiveTab() }
                .keyboardShortcut("k", modifiers: .command)
            Button("") { viewModel.copyActiveDevServerURL() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }
}

private struct ErrorBannerView: View {
    let error: DetectedError
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("Error Detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(error.snippet)
                    .font(.caption2)
                    .lineLimit(2)
            }
            Spacer()
            Button("Dismiss") { onDismiss() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.1))
    }
}

private struct TerminalHistoryPopover: View {
    let commands: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Commands")
                .font(.system(size: 12, weight: .semibold))

            if commands.isEmpty {
                Text("No commands recorded yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(commands, id: \.self) { command in
                    Text(command)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
    }
}
