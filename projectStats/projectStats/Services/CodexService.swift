import Foundation

/// Service for interacting with the OpenAI Codex CLI tool
@MainActor
final class CodexService: ObservableObject {
    static let shared = CodexService()

    @Published var isInstalled = false
    @Published var version: String?
    @Published var lastError: String?

    private init() {
        Task {
            await checkInstallation()
        }
    }

    // MARK: - Installation Check

    /// Check if Codex CLI is installed
    func checkInstallation() async {
        let result = Shell.run("which codex")
        isInstalled = !result.isEmpty && result.contains("codex")

        if isInstalled {
            version = await getVersion()
        }
    }

    /// Get Codex version
    func getVersion() async -> String? {
        guard isInstalled else { return nil }

        let result = Shell.run("codex --version")
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Command Generation

    /// Generate the command to launch Codex
    func generateLaunchCommand(
        model: AIModel? = nil,
        fullAuto: Bool = false,
        projectPath: String? = nil
    ) -> String {
        var command = "codex"

        // Add model if specified
        if let model = model {
            command += " --model \(model.rawValue)"
        }

        // Add full-auto flag for autonomous mode
        if fullAuto {
            command += " --full-auto"
        }

        return command
    }

    /// Generate command for a specific prompt
    func generatePromptCommand(
        prompt: String,
        model: AIModel? = nil,
        fullAuto: Bool = false
    ) -> String {
        var command = generateLaunchCommand(model: model, fullAuto: fullAuto)

        // Escape the prompt for shell
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        command += " \"\(escapedPrompt)\""

        return command
    }

    // MARK: - Session Parsing

    /// Parse session output for token usage
    /// Returns (inputTokens, outputTokens, duration)
    func parseSessionOutput(_ output: String) -> (inputTokens: Int, outputTokens: Int, duration: TimeInterval)? {
        // Codex outputs stats in a format like:
        // "Used X input tokens, Y output tokens in Z seconds"
        // or similar format - adjust based on actual Codex output

        var inputTokens = 0
        var outputTokens = 0
        var duration: TimeInterval = 0

        // Pattern: tokens used: input=X, output=Y
        let tokenPattern = "tokens.*input\\s*[:=]\\s*(\\d+).*output\\s*[:=]\\s*(\\d+)"
        if let regex = try? NSRegularExpression(pattern: tokenPattern, options: .caseInsensitive) {
            let range = NSRange(output.startIndex..., in: output)
            if let match = regex.firstMatch(in: output, options: [], range: range) {
                if let inputRange = Range(match.range(at: 1), in: output) {
                    inputTokens = Int(output[inputRange]) ?? 0
                }
                if let outputRange = Range(match.range(at: 2), in: output) {
                    outputTokens = Int(output[outputRange]) ?? 0
                }
            }
        }

        // Pattern: completed in X.X seconds
        let durationPattern = "completed in\\s+([\\d.]+)\\s*(?:seconds|s)"
        if let regex = try? NSRegularExpression(pattern: durationPattern, options: .caseInsensitive) {
            let range = NSRange(output.startIndex..., in: output)
            if let match = regex.firstMatch(in: output, options: [], range: range) {
                if let durationRange = Range(match.range(at: 1), in: output) {
                    duration = Double(output[durationRange]) ?? 0
                }
            }
        }

        // Also check for Claude-style output since Codex may use similar format
        // Pattern: "Cooked for X.XXs"
        let cookedPattern = "(?:Cooked|Crunched) for\\s+([\\d.]+)s"
        if let regex = try? NSRegularExpression(pattern: cookedPattern, options: .caseInsensitive) {
            let range = NSRange(output.startIndex..., in: output)
            if let match = regex.firstMatch(in: output, options: [], range: range) {
                if let durationRange = Range(match.range(at: 1), in: output) {
                    duration = Double(output[durationRange]) ?? 0
                }
            }
        }

        if inputTokens > 0 || outputTokens > 0 || duration > 0 {
            return (inputTokens, outputTokens, duration)
        }

        return nil
    }

    /// Detect if Codex session has ended
    func detectSessionEnd(_ output: String) -> Bool {
        let endPatterns = [
            "Session complete",
            "Goodbye",
            "Task completed",
            "finished successfully",
            "exiting"
        ]

        let lowered = output.lowercased()
        return endPatterns.contains { lowered.contains($0.lowercased()) }
    }

    // MARK: - Installation

    /// Get installation instructions
    var installationInstructions: String {
        """
        To install Codex CLI:

        1. Using npm (recommended):
           npm install -g @openai/codex

        2. Or using Homebrew:
           brew install codex

        After installation, run 'codex --version' to verify.
        """
    }

    /// Attempt to install Codex via npm
    func attemptInstall() async -> Bool {
        let result = Shell.run("npm install -g @openai/codex 2>&1")

        if result.contains("added") || result.contains("updated") {
            await checkInstallation()
            return isInstalled
        }

        lastError = result
        return false
    }
}
