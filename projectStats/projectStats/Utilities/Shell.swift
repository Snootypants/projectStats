import Foundation
import os.log

struct Shell {
    static let defaultTimeout: TimeInterval = 30

    @discardableResult
    static func run(_ command: String, at path: URL? = nil, timeout: TimeInterval = defaultTimeout) -> String {
        runResult(command, at: path, timeout: timeout).output
    }

    struct Result {
        let output: String
        let error: String
        let exitCode: Int
        let timedOut: Bool

        init(output: String, error: String, exitCode: Int, timedOut: Bool = false) {
            self.output = output
            self.error = error
            self.exitCode = exitCode
            self.timedOut = timedOut
        }
    }

    static func runResult(_ command: String, at path: URL? = nil, timeout: TimeInterval = defaultTimeout) -> Result {
        let task = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]

        if let path = path {
            task.currentDirectoryURL = path
        }

        do {
            try task.run()
        } catch {
            return Result(output: "", error: error.localizedDescription, exitCode: 1)
        }

        let group = DispatchGroup()
        group.enter()
        task.terminationHandler = { _ in group.leave() }

        let waitResult = group.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            Log.shell.warning("Shell command timed out after \(timeout)s: \(command.prefix(80))")
            task.terminate()
            task.waitUntilExit()
            return Result(output: "", error: "Timed out after \(Int(timeout))s", exitCode: -1, timedOut: true)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let error = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let exitCode = Int(task.terminationStatus)

        return Result(output: output, error: error, exitCode: exitCode)
    }

    static func runAsync(_ command: String, at path: URL? = nil, timeout: TimeInterval = defaultTimeout) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = run(command, at: path, timeout: timeout)
                continuation.resume(returning: result)
            }
        }
    }

    /// Check if git is available on this system
    static var isGitAvailable: Bool {
        let result = runResult("which git", timeout: 5)
        return result.exitCode == 0 && !result.output.isEmpty
    }
}
