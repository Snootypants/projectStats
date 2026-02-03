import AppKit
import SwiftUI
import SwiftTerm

struct TerminalTabView: View {
    @ObservedObject var viewModel: TerminalTabsViewModel

    var body: some View {
        ZStack {
            ForEach(viewModel.tabs) { tab in
                TerminalSessionView(projectPath: viewModel.projectPath, tab: tab)
                    .opacity(viewModel.activeTabID == tab.id ? 1 : 0)
                    .allowsHitTesting(viewModel.activeTabID == tab.id)
            }
        }
        .background(Color.primary.opacity(0.02))
    }
}

private struct TerminalSessionView: NSViewRepresentable {
    let projectPath: URL
    @ObservedObject var tab: TerminalTabItem

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = MonitoringTerminalView(frame: .zero)
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminalView.configureNativeColors()
        terminalView.onOutput = { [weak tab] text in
            Task { @MainActor in
                tab?.recordOutput(text)
                TerminalOutputMonitor.shared.processTerminalChunk(text)
                TimeTrackingService.shared.recordActivity()
            }
        }

        let shellPath = "/bin/zsh"
        let command = "cd '\(shellEscape(projectPath.path))'; exec \(shellPath) -l"

        // Defer process start to avoid blocking UI, then attach after shell initializes
        Task { @MainActor in
            terminalView.startProcess(
                executable: shellPath,
                args: ["-l", "-c", command]
            )
            // Wait for shell to initialize before attaching (sends pending commands)
            try? await Task.sleep(for: .milliseconds(300))
            tab.attach(terminalView)
        }

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // No-op: attachment is handled in makeNSView after shell initializes
    }

    private func shellEscape(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }
}

private final class MonitoringTerminalView: LocalProcessTerminalView {
    var onOutput: ((String) -> Void)?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        if let text = String(bytes: slice, encoding: .utf8), !text.isEmpty {
            onOutput?(text)
        }
        super.dataReceived(slice: slice)
    }
}
