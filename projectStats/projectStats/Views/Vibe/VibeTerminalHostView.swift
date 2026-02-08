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

        let terminalView = VibeOutputTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 384))
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
            terminalView.lockTerminalSize()
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
    private var sizedLocked = false

    override func dataReceived(slice: ArraySlice<UInt8>) {
        if let text = String(bytes: slice, encoding: .utf8), !text.isEmpty {
            onOutput?(text)
        }
        super.dataReceived(slice: slice)
    }

    /// Lock terminal to 80x24 so output buffers correctly even though the view is hidden
    func lockTerminalSize() {
        getTerminal().resize(cols: 80, rows: 24)
        sizedLocked = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if sizedLocked {
            getTerminal().resize(cols: 80, rows: 24)
        }
    }
}
