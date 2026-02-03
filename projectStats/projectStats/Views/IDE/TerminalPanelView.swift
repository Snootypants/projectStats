import SwiftUI

struct TerminalPanelView: View {
    @ObservedObject var viewModel: TerminalTabsViewModel
    @State private var showHistory = false
    @StateObject private var outputMonitor = TerminalOutputMonitor.shared

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

            HStack(spacing: 0) {
                TerminalTabView(viewModel: viewModel)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                TerminalTabBar(viewModel: viewModel)
            }
        }
        .background(Color.primary.opacity(0.02))
        .background {
            terminalShortcuts
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
