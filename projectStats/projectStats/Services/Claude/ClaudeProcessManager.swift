import Foundation
import Combine

enum PermissionMode: String, CaseIterable {
    case flavor      // YOLO - skip permissions
    case sansFlavor  // Normal - require approval
}

enum SessionState: Equatable {
    case idle
    case running
    case thinking
    case waitingForApproval
    case done
    case error(String)
}

@MainActor
final class ClaudeProcessManager: ObservableObject {
    @Published var sessionState: SessionState = .idle
    @Published var claudeBinaryPath: String?

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var eventHandler: (([ClaudeEvent]) -> Void)?
    private var lineBuffer = ""

    private let decoder = JSONDecoder()

    init() {
        Task { await locateClaude() }
    }

    /// Locate the claude binary
    func locateClaude() async {
        // Try `which claude` first
        let result = Shell.runResult("which claude")
        if result.exitCode == 0, !result.output.isEmpty {
            claudeBinaryPath = result.output
            return
        }

        // Check known locations
        let candidates = [
            "\(NSHomeDirectory())/.npm-global/bin/claude",
            "/usr/local/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                claudeBinaryPath = path
                return
            }
        }
    }

    /// Start a Claude Code session
    func start(
        projectPath: String,
        permissionMode: PermissionMode,
        appendSystemPrompt: String? = nil,
        onEvent: @escaping ([ClaudeEvent]) -> Void
    ) {
        guard let binary = claudeBinaryPath else {
            sessionState = .error("Claude binary not found")
            return
        }

        stop() // Clean up any existing session

        self.eventHandler = onEvent

        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        proc.executableURL = URL(fileURLWithPath: binary)

        var args = ["--output-format", "stream-json"]
        if permissionMode == .flavor {
            args.insert("--dangerously-skip-permissions", at: 0)
        }
        if let systemPrompt = appendSystemPrompt, !systemPrompt.isEmpty {
            args.append(contentsOf: ["--append-system-prompt", systemPrompt])
        }
        args.append("-p")
        proc.arguments = args
        proc.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        // Read stdout line by line
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let text = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.processOutput(text)
                }
            }
        }

        // Handle process exit
        proc.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                self?.sessionState = proc.terminationStatus == 0
                    ? .done
                    : .error("Process exited with code \(proc.terminationStatus)")
                self?.cleanup()
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.stdinPipe = stdin
            self.stdoutPipe = stdout
            self.stderrPipe = stderr
            self.sessionState = .running
        } catch {
            sessionState = .error("Failed to start: \(error.localizedDescription)")
        }
    }

    /// Send a user message via stdin
    func sendMessage(_ text: String) {
        guard let pipe = stdinPipe else { return }

        // For -p mode, just write the text followed by newline
        // Claude Code in -p mode reads from stdin
        if let data = (text + "\n").data(using: .utf8) {
            pipe.fileHandleForWriting.write(data)
        }
    }

    /// Send a permission response
    func sendPermissionResponse(allow: Bool) {
        // In stream-json mode, permission responses go through stdin
        let response = allow ? "allow" : "deny"
        sendMessage(response)
    }

    /// Stop the current session
    func stop() {
        process?.terminate()
        cleanup()
        sessionState = .idle
    }

    // MARK: - Private

    private func processOutput(_ text: String) {
        lineBuffer += text

        // Split by newlines -- NDJSON means one JSON object per line
        while let newlineIndex = lineBuffer.firstIndex(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex..<newlineIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            lineBuffer = String(lineBuffer[lineBuffer.index(after: newlineIndex)...])

            guard !line.isEmpty else { continue }
            parseLine(line)
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }

        do {
            let rawEvent = try decoder.decode(ClaudeStreamEvent.self, from: data)
            let events = ClaudeEvent.from(rawEvent)

            if !events.isEmpty {
                // Update session state based on events
                for event in events {
                    switch event {
                    case .assistantText:
                        sessionState = .thinking
                    case .toolUse:
                        sessionState = .running
                    case .result:
                        sessionState = .done
                    default:
                        break
                    }
                }

                eventHandler?(events)
            }
        } catch {
            // Log parse error but don't crash -- skip malformed lines
            eventHandler?([.error("Parse error: \(error.localizedDescription) -- line: \(line.prefix(100))")])
        }
    }

    private func cleanup() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
        lineBuffer = ""
    }
}
