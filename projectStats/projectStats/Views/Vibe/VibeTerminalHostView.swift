import AppKit
import SwiftUI
import SwiftTerm

/// Hidden NSViewRepresentable that hosts a real terminal process for VIBE tabs.
/// The terminal view is invisible (zero frame) but the shell process runs,
/// enabling command sending and output capture via TerminalTabItem.
struct VibeTerminalHostView: NSViewRepresentable {
    let projectPath: URL
    @ObservedObject var tab: TerminalTabItem

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        if let existing = tab.existingTerminalView {
            return existing
        }

        let terminalView = VibeOutputTerminalView(frame: .zero)
        terminalView.onOutput = { [weak tab, projectPath] text in
            Task { @MainActor in
                tab?.recordOutput(text)
                TerminalOutputMonitor.shared.activeProjectPath = projectPath.path
                TerminalOutputMonitor.shared.processTerminalChunk(text)
                TimeTrackingService.shared.recordActivity()
            }
        }

        let shellPath = "/bin/zsh"
        let command = "cd '\(shellEscape(projectPath.path))'; exec \(shellPath) -l"

        Task { @MainActor in
            terminalView.startProcess(
                executable: shellPath,
                args: ["-l", "-c", command]
            )
            try? await Task.sleep(for: .milliseconds(300))
            tab.attach(terminalView)
        }

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    private func shellEscape(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }
}

private final class VibeOutputTerminalView: LocalProcessTerminalView {
    var onOutput: ((String) -> Void)?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        if let text = String(bytes: slice, encoding: .utf8), !text.isEmpty {
            onOutput?(text)
        }
        super.dataReceived(slice: slice)
    }
}
