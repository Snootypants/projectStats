import Foundation
import SwiftTerm

/// Delegate handler for LocalProcess — bridges process I/O to closures.
/// Not MainActor-isolated so it can conform to LocalProcessDelegate.
final class VibeProcessHandler: LocalProcessDelegate {
    var onData: ((String) -> Void)?
    var onTerminate: ((Int32?) -> Void)?

    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        onTerminate?(exitCode)
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        if let text = String(bytes: slice, encoding: .utf8), !text.isEmpty {
            onData?(text)
        }
    }

    func getWindowSize() -> winsize {
        winsize(ws_row: 40, ws_col: 120, ws_xpixel: 16, ws_ypixel: 16)
    }
}

/// Manages a headless shell process using LocalProcess directly.
/// Replaces the broken hidden-NSView approach (VibeTerminalHostView).
@MainActor
final class VibeProcessBridge: ObservableObject {
    @Published var isRunning = false

    private var process: LocalProcess?
    private var handler: VibeProcessHandler?
    private var onOutput: ((String) -> Void)?

    func start(directory: String, onOutput: @escaping (String) -> Void) {
        guard process == nil else { return }
        self.onOutput = onOutput

        let handler = VibeProcessHandler()
        handler.onData = { [weak self] text in
            Task { @MainActor in
                self?.onOutput?(text)
            }
        }
        handler.onTerminate = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
            }
        }
        self.handler = handler

        let proc = LocalProcess(delegate: handler, dispatchQueue: .main)
        let shellPath = "/bin/zsh"
        let escaped = directory.replacingOccurrences(of: "'", with: "'\\''")
        let command = "cd '\(escaped)'; exec \(shellPath) -l"
        proc.startProcess(executable: shellPath, args: ["-l", "-c", command])

        self.process = proc
        isRunning = true
    }

    func send(_ text: String) {
        guard let process else { return }
        let bytes = Array((text + "\r").utf8)
        process.send(data: bytes[...])
    }

    func sendRaw(_ bytes: [UInt8]) {
        process?.send(data: bytes[...])
    }

    func stop() {
        process?.send(data: [0x03])  // Ctrl+C
        process?.terminate()
        process = nil
        handler = nil
        isRunning = false
    }
}
