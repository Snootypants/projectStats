import Foundation

@MainActor
final class TerminalOutputMonitor: ObservableObject {
    static let shared = TerminalOutputMonitor()

    var activeProjectPath: String?

    private var syncDebounceTask: Task<Void, Never>?

    private let gitTriggerPatterns: [String] = [
        "[main ",
        "[master ",
        "[develop ",
        "[feature/",
        "[bugfix/",
        "[hotfix/",
        "create mode",
        "delete mode",
        "To github.com",
        "To gitlab.com",
        "To bitbucket.org",
        "Branch '",
        "-> main",
        "-> master",
        "$ git commit",
        "$ git push",
        "% git commit",
        "% git push"
    ]

    private let otherTriggerPatterns: [String] = [
        "npm install",
        "yarn add",
        "pip install",
        "cargo add"
    ]

    private init() {}

    func processTerminalOutput(_ line: String) {
        let cleanLine = stripAnsiCodes(line)
        let isGitEvent = gitTriggerPatterns.contains { cleanLine.contains($0) }

        if isGitEvent {
            scheduleSyncDebounced()
        }
    }

    func processTerminalChunk(_ chunk: String) {
        let lines = chunk.components(separatedBy: .newlines)
        for line in lines {
            processTerminalOutput(line)
        }
    }

    private func scheduleSyncDebounced() {
        syncDebounceTask?.cancel()
        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await triggerSync()
        }
    }

    private func triggerSync() async {
        guard let projectPath = activeProjectPath else { return }
        print("[TerminalMonitor] Git event detected, syncing project: \(projectPath)")
        await DashboardViewModel.shared.syncSingleProject(path: projectPath)
    }

    private func stripAnsiCodes(_ string: String) -> String {
        let pattern = "\\x1B\\[[0-9;]*[a-zA-Z]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: "")
    }
}
