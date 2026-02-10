import Foundation
import Combine
import os.log

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
    @Published var hasCheckedForClaude: Bool = false

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var eventHandler: (([ClaudeEvent]) -> Void)?
    private var rawLineHandler: ((String) -> Void)?
    private var lineBuffer = ""
    private var processGeneration: Int = 0 // Guards against stale termination handlers

    private let decoder = JSONDecoder()

    init() {
        Task { await locateClaude() }
    }

    deinit {
        // Ensure process is terminated if this object is deallocated
        if let proc = process, proc.isRunning {
            stdinPipe?.fileHandleForWriting.closeFile()
            proc.terminate()
        }
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
    }

    /// Locate the claude binary
    func locateClaude() async {
        defer { hasCheckedForClaude = true }

        // Try `which claude` first via login shell so PATH is populated
        let result = Shell.runResult("/bin/zsh -lc 'which claude'")
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.exitCode == 0, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            claudeBinaryPath = path
            Log.claude.info("Found claude at: \(path)")
            return
        }

        // Check known locations
        let candidates = [
            "\(NSHomeDirectory())/.npm-global/bin/claude",
            "/usr/local/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude",
            "/opt/homebrew/bin/claude"
        ]

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                claudeBinaryPath = candidate
                Log.claude.info("Found claude at: \(candidate)")
                return
            }
        }

        Log.claude.warning("Claude binary not found")
    }

    /// Start a Claude Code session with streaming JSON I/O
    func start(
        projectPath: String,
        permissionMode: PermissionMode,
        appendSystemPrompt: String? = nil,
        onRawLine: ((String) -> Void)? = nil,
        onEvent: @escaping ([ClaudeEvent]) -> Void
    ) {
        guard let binary = claudeBinaryPath else {
            let msg = "Claude binary not found"
            Log.claude.error("\(msg)")
            sessionState = .error(msg)
            onEvent([.error(msg)])
            return
        }

        stop() // Clean up any existing session

        processGeneration += 1
        let currentGeneration = processGeneration

        self.eventHandler = onEvent
        self.rawLineHandler = onRawLine

        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        proc.executableURL = URL(fileURLWithPath: binary)

        // Build arguments: -p for print mode, stream-json for both input and output
        var args: [String] = []
        if permissionMode == .flavor {
            args.append("--dangerously-skip-permissions")
        }
        args.append(contentsOf: [
            "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose"
        ])
        if let systemPrompt = appendSystemPrompt, !systemPrompt.isEmpty {
            args.append(contentsOf: ["--append-system-prompt", systemPrompt])
        }
        proc.arguments = args
        proc.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        // Inherit user's PATH so claude can find node/npm
        var env = ProcessInfo.processInfo.environment
        let userPaths = [
            "\(NSHomeDirectory())/.npm-global/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/*/bin"
        ]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (userPaths + [existingPath]).joined(separator: ":")
        proc.environment = env

        Log.claude.info("Starting: \(binary) \(args.joined(separator: " "))")
        Log.claude.info("CWD: \(projectPath)")

        // Read stdout line by line (NDJSON)
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let text = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.processOutput(text)
                }
            }
        }

        // Read stderr for errors
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let text = String(data: data, encoding: .utf8) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Log.claude.error("STDERR: \(trimmed)")
                    Task { @MainActor [weak self] in
                        self?.eventHandler?([.error("stderr: \(trimmed)")])
                    }
                }
            }
        }

        // Handle process exit — only act if this is still the current process
        proc.terminationHandler = { [weak self] proc in
            Log.claude.info("Process exited with code \(proc.terminationStatus)")
            Task { @MainActor [weak self] in
                guard let self, self.processGeneration == currentGeneration else {
                    Log.claude.debug("Ignoring stale termination handler (generation mismatch)")
                    return
                }
                if proc.terminationStatus == 0 {
                    self.sessionState = .done
                } else {
                    let msg = "Process exited with code \(proc.terminationStatus)"
                    self.sessionState = .error(msg)
                    self.eventHandler?([.error(msg)])
                }
                self.cleanup()
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.stdinPipe = stdin
            self.stdoutPipe = stdout
            self.stderrPipe = stderr
            self.sessionState = .running
            Log.claude.info("Process launched successfully (PID: \(proc.processIdentifier))")
        } catch {
            let msg = "Failed to start: \(error.localizedDescription)"
            Log.claude.error("\(msg)")
            sessionState = .error(msg)
            onEvent([.error(msg)])
        }
    }

    /// Send a user message via stdin as stream-json format
    func sendMessage(_ text: String) {
        guard let pipe = stdinPipe else {
            Log.claude.warning("Cannot send message — no stdin pipe")
            return
        }

        // Stream-json input format: JSON with type, message.role, message.content
        let messageJSON: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": [
                    ["type": "text", "text": text]
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: messageJSON),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Log.claude.error("Failed to serialize message JSON")
            return
        }

        let line = jsonString + "\n"
        Log.claude.debug("Sending: \(line.prefix(200))")

        if let data = line.data(using: .utf8) {
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
        if let proc = process, proc.isRunning {
            // Close stdin to signal EOF, then terminate
            stdinPipe?.fileHandleForWriting.closeFile()
            proc.terminate()
            Log.claude.info("Stopped process")
        }
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
        rawLineHandler?(line)
        guard let data = line.data(using: .utf8) else { return }

        do {
            let rawEvent = try decoder.decode(ClaudeStreamEvent.self, from: data)
            let events = ClaudeEvent.from(rawEvent)

            if !events.isEmpty {
                // Update session state based on events
                for event in events {
                    switch event {
                    case .system:
                        Log.claude.info("Got system init event")
                        sessionState = .running
                    case .assistantText(_, _, _):
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
            // Log parse error but don't surface to UI -- unknown event types (e.g. "type":"user" echoes) are expected
            Log.claude.debug("Skipping unrecognized line: \(line.prefix(200))")
        }
    }

    private func cleanup() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
        lineBuffer = ""
        eventHandler = nil
        rawLineHandler = nil
    }
}
