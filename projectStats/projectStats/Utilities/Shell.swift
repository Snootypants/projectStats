import Foundation

struct Shell {
    @discardableResult
    static func run(_ command: String, at path: URL? = nil) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]

        if let path = path {
            task.currentDirectoryURL = path
        }

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
