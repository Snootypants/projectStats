import Foundation
import AppKit

@MainActor
final class TerminalOutputMonitor: ObservableObject {
    static let shared = TerminalOutputMonitor()

    @Published var lastDetectedError: DetectedError?
    @Published var isClaudeRunning: Bool = false
    @Published var activeSession: AISessionV2?
    var activeProjectPath: String?

    // Current session tracking
    private var currentProvider: AIProviderType = .claudeCode
    private var currentModel: AIModel = .claudeSonnet4
    private var currentThinkingLevel: ThinkingLevel = .none

    private var syncDebounceTask: Task<Void, Never>?
    private let errorDetector = ErrorDetector()

    // Claude Code detection patterns
    private let claudeStartPatterns: [String] = [
        "╭─",           // Claude Code prompt box start
        "⏺ ",           // Claude action indicator
        "Claude: ",     // Direct output
    ]

    private let claudeEndPatterns: [String] = [
        "✻ Cooked for",     // Session complete
        "✻ Crunched for",   // Alternative phrasing
    ]

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

        // Detect Claude session start
        if claudeStartPatterns.contains(where: { cleanLine.contains($0) }) {
            if !isClaudeRunning {
                isClaudeRunning = true
                if let projectPath = activeProjectPath {
                    TimeTrackingService.shared.startAITracking(project: projectPath, aiType: "claude_code")
                    // Start AISessionV2 tracking
                    startSession(
                        provider: currentProvider,
                        model: currentModel,
                        thinkingLevel: currentThinkingLevel,
                        projectPath: projectPath
                    )
                }
            }
        }

        // Detect Claude session end
        if let duration = parseClaudeFinished(cleanLine) {
            if isClaudeRunning {
                isClaudeRunning = false
                TimeTrackingService.shared.stopAITracking()

                // End AISessionV2 tracking (estimate tokens from duration)
                let estimatedTokens = Int(duration * 50) // Rough estimate: ~50 tokens/second
                endSession(inputTokens: estimatedTokens / 2, outputTokens: estimatedTokens / 2)

                // Trigger notification if tab not active
                if SettingsViewModel.shared.notifyClaudeFinished {
                    checkAndNotifyClaudeFinished()
                }

                // Track prompt execution completion
                PromptExecutionTracker.shared.completeExecution(
                    projectPath: activeProjectPath ?? "",
                    durationSeconds: duration
                )

                // Refresh Claude usage stats (with delay for JSONL write)
                Task {
                    await ClaudeUsageService.shared.onClaudeFinished(projectPath: activeProjectPath)
                }
            }
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

    // MARK: - Claude Detection

    private func parseClaudeFinished(_ line: String) -> TimeInterval? {
        // Parse "✻ Cooked for 4m 2s" or "✻ Crunched for 30s"
        let patterns = [
            "✻ Cooked for ([0-9]+)m ([0-9]+)s",
            "✻ Cooked for ([0-9]+)s",
            "✻ Crunched for ([0-9]+)m ([0-9]+)s",
            "✻ Crunched for ([0-9]+)s"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                // Parse duration
                if match.numberOfRanges == 3 {
                    let minutesRange = Range(match.range(at: 1), in: line)!
                    let secondsRange = Range(match.range(at: 2), in: line)!
                    let minutes = Int(line[minutesRange]) ?? 0
                    let seconds = Int(line[secondsRange]) ?? 0
                    return TimeInterval(minutes * 60 + seconds)
                } else if match.numberOfRanges == 2 {
                    let secondsRange = Range(match.range(at: 1), in: line)!
                    let seconds = Int(line[secondsRange]) ?? 0
                    return TimeInterval(seconds)
                }
            }
        }
        return nil
    }

    private func checkAndNotifyClaudeFinished() {
        print("[Monitor] Claude session ended, checking notification conditions")

        // Check if the app is not frontmost OR the project tab is not active
        let isAppActive = NSApp.isActive
        let activeContent = TabManagerViewModel.shared.activeTab?.content
        var isTabActive = false

        if case .projectWorkspace(let path) = activeContent {
            isTabActive = path == activeProjectPath
        }

        print("[Monitor] App active: \(isAppActive), Tab active: \(isTabActive)")

        if !isAppActive || !isTabActive {
            let projectName = URL(fileURLWithPath: activeProjectPath ?? "").lastPathComponent
            print("[Monitor] Sending notification for project: \(projectName)")
            NotificationService.shared.sendNotification(
                title: "Claude finished",
                message: "Ready for review in \(projectName)"
            )
        } else {
            print("[Monitor] Notification skipped - app and tab are active")
        }
    }

    // MARK: - Session Tracking

    /// Start a new AI session with provider info
    func startSession(provider: AIProviderType, model: AIModel, thinkingLevel: ThinkingLevel = .none, projectPath: String?) {
        currentProvider = provider
        currentModel = model
        currentThinkingLevel = thinkingLevel

        let session = AISessionV2(
            providerType: provider,
            model: model,
            thinkingLevel: thinkingLevel,
            projectPath: projectPath
        )

        activeSession = session

        // Insert into SwiftData
        let context = AppModelContainer.shared.mainContext
        context.insert(session)

        print("[TerminalMonitor] Started \(provider.displayName) session with \(model.displayName)")
    }

    /// End the current session with token usage
    func endSession(inputTokens: Int, outputTokens: Int, thinkingTokens: Int = 0,
                    cacheReadTokens: Int = 0, cacheWriteTokens: Int = 0,
                    wasSuccessful: Bool = true, errorMessage: String? = nil) {
        guard let session = activeSession else { return }

        session.end(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            thinkingTokens: thinkingTokens,
            cacheReadTokens: cacheReadTokens,
            cacheWriteTokens: cacheWriteTokens,
            wasSuccessful: wasSuccessful,
            errorMessage: errorMessage
        )

        // Save to SwiftData
        do {
            try AppModelContainer.shared.mainContext.save()
            print("[TerminalMonitor] Ended session: \(session.totalTokens) tokens, $\(String(format: "%.4f", session.costUSD))")
        } catch {
            print("[TerminalMonitor] Failed to save session: \(error)")
        }

        activeSession = nil
    }

    /// Update session settings from terminal tab
    func updateSessionSettings(provider: AIProviderType, model: AIModel, thinkingLevel: ThinkingLevel) {
        currentProvider = provider
        currentModel = model
        currentThinkingLevel = thinkingLevel
    }

    /// Parse token usage from terminal output and end session
    func parseAndEndSession(_ output: String) {
        // Try to parse token usage from output
        if let usage = ThinkingLevelService.shared.parseThinkingUsage(output) {
            endSession(
                inputTokens: usage.input,
                outputTokens: usage.output,
                thinkingTokens: usage.thinking
            )
        } else {
            // No token info available, just end the session
            endSession(inputTokens: 0, outputTokens: 0)
        }
    }
}
