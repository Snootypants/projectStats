import SwiftUI

struct TerminalPanelView: View {
    @ObservedObject var viewModel: TerminalTabsViewModel
    @State private var showHistory = false
    @StateObject private var outputMonitor = TerminalOutputMonitor.shared
    @State private var promptText: String = ""
    @FocusState private var isPromptFocused: Bool

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

            // Terminal content area with equal margins and clipping
            HStack(spacing: 0) {
                TerminalTabView(viewModel: viewModel)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .clipped()

                TerminalTabBar(viewModel: viewModel)
            }
            .clipped()

            Divider()

            // Send Prompt field
            sendPromptField
        }
        .background(Color.primary.opacity(0.02))
        .background {
            terminalShortcuts
        }
    }

    private var sendPromptField: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))

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

        let textToSend = promptText
        promptText = ""

        // Save to database
        Task { @MainActor in
            do {
                let context = AppModelContainer.shared.mainContext
                let saved = SavedPrompt(
                    text: textToSend,
                    projectPath: TerminalOutputMonitor.shared.activeProjectPath
                )
                context.insert(saved)
                try context.save()
                print("[Prompts] ✅ Saved prompt: \(textToSend.prefix(50))...")
            } catch {
                print("[Prompts] ❌ Failed to save: \(error)")
            }
        }

        // Send to terminal (sendCommand adds newline)
        if let activeTab = viewModel.activeTab {
            activeTab.sendCommand(textToSend)
            print("[Prompts] ✅ Sent to terminal: \(textToSend.prefix(50))...")
        } else {
            print("[Prompts] ❌ No active terminal tab!")
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

            Button("Claude") {
                viewModel.addClaudeTab()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("ccYOLO") {
                viewModel.addCcYoloTab()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

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
