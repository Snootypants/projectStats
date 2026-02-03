import Foundation

@MainActor
final class TerminalOutputMonitor: ObservableObject {
    static let shared = TerminalOutputMonitor()

    @Published var lastDetectedError: DetectedError?
    var activeProjectPath: String?

    private var syncDebounceTask: Task<Void, Never>?
    private let errorDetector = ErrorDetector()

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

        // Detect git push and trigger notifications + achievements
        if cleanLine.contains("To github.com") || cleanLine.contains("To gitlab.com") || cleanLine.contains("To bitbucket.org") {
            if SettingsViewModel.shared.notifyGitPushCompleted {
                NotificationService.shared.sendNotification(title: "Git push completed", message: cleanLine)
            }

            // Trigger achievement checks on git push
            if let projectPath = activeProjectPath {
                Task { @MainActor in
                    AchievementService.shared.onGitPushDetected(projectPath: projectPath)
                }
            }
        }

        // Also check achievements on git commit detection
        if cleanLine.contains("[main ") || cleanLine.contains("[master ") ||
           cleanLine.contains("[develop ") || cleanLine.contains("[feature/") ||
           cleanLine.contains("[bugfix/") || cleanLine.contains("[hotfix/") {
            if let projectPath = activeProjectPath {
                Task { @MainActor in
                    // Commit detected - check first blood and time-based achievements
                    AchievementService.shared.checkFirstCommitOfDay(projectPath: projectPath)
                    AchievementService.shared.checkTimeBasedAchievements(projectPath: projectPath)
                }
            }
        }

        if let detected = errorDetector.detectError(in: cleanLine) {
            lastDetectedError = detected
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
