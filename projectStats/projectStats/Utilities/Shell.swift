import Foundation

struct Shell {
    @discardableResult
    static func run(_ command: String, at path: URL? = nil) -> String {
        runResult(command, at: path).output
    }

    struct Result {
        let output: String
        let error: String
        let exitCode: Int
    }

    static func runResult(_ command: String, at path: URL? = nil) -> Result {
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
            task.waitUntilExit()
        } catch {
            return Result(output: "", error: error.localizedDescription, exitCode: 1)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let error = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let exitCode = Int(task.terminationStatus)

        return Result(output: output, error: error, exitCode: exitCode)
    }

    static func runAsync(_ command: String, at path: URL? = nil) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = run(command, at: path)
                continuation.resume(returning: result)
            }
        }
    }
}
