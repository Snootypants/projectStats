import AppKit
import SwiftUI
import SwiftTerm

struct TerminalPanelView: View {
    let projectPath: URL
    @StateObject private var controller = TerminalController()

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            SwiftTermContainer(projectPath: projectPath, controller: controller)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .background(Color.primary.opacity(0.02))
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                terminalActions
                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .semibold))
                Text("Terminal")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private var terminalActions: some View {
        HStack(spacing: 10) {
            Button("codex") {
                controller.sendCommand("claude")
            }

            Button("ccYOLO") {
                controller.sendCommand("claude code --dangerously-skip-permissions")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .font(.system(size: 12, weight: .semibold))
        .padding(.vertical, 2)
    }
}

private final class TerminalController: ObservableObject {
    weak var terminalView: LocalProcessTerminalView?
    private var followTimer: Timer?

    func sendCommand(_ command: String) {
        guard let terminalView else { return }
        terminalView.getTerminal().sendResponse(text: command + "\n")
    }

    func attach(_ terminalView: LocalProcessTerminalView) {
        self.terminalView = terminalView
        startFollowTimer()
    }

    private func startFollowTimer() {
        followTimer?.invalidate()
        followTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let terminalView = self.terminalView else { return }

            let atBottom = !terminalView.canScroll || terminalView.scrollPosition >= 0.99
            if atBottom && terminalView.scrollPosition < 0.999 {
                terminalView.scroll(toPosition: 1)
            }
        }
    }

    deinit {
        followTimer?.invalidate()
    }
}

private struct SwiftTermContainer: NSViewRepresentable {
    let projectPath: URL
    @ObservedObject var controller: TerminalController

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminalView.configureNativeColors()

        let shellPath = "/bin/zsh"
        let command = "cd '\(shellEscape(projectPath.path))'; exec \(shellPath) -l"
        terminalView.startProcess(
            executable: shellPath,
            args: ["-l", "-c", command]
        )

        controller.attach(terminalView)
        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Recreated when project changes via .id(projectPath) in the parent view.
        if controller.terminalView !== nsView {
            controller.attach(nsView)
        }
    }

    private func shellEscape(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }
}
