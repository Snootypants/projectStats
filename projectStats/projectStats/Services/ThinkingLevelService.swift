import Foundation

/// Service for managing thinking levels and generating Claude commands with thinking budgets
@MainActor
final class ThinkingLevelService: ObservableObject {
    static let shared = ThinkingLevelService()

    @Published var defaultModel: AIModel = .claudeSonnet4_5
    @Published var defaultThinkingLevel: ThinkingLevel = .none
    @Published var showModelInToolbar: Bool = true

    private init() {
        loadSettings()
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        if let modelRaw = UserDefaults.standard.string(forKey: "ai.defaultModel"),
           let model = AIModel(rawValue: modelRaw) {
            defaultModel = model
        }

        if let thinkingRaw = UserDefaults.standard.string(forKey: "ai.defaultThinkingLevel"),
           let thinking = ThinkingLevel(rawValue: thinkingRaw) {
            defaultThinkingLevel = thinking
        }

        showModelInToolbar = UserDefaults.standard.bool(forKey: "ai.showModelInToolbar")
    }

    func saveSettings() {
        UserDefaults.standard.set(defaultModel.rawValue, forKey: "ai.defaultModel")
        UserDefaults.standard.set(defaultThinkingLevel.rawValue, forKey: "ai.defaultThinkingLevel")
        UserDefaults.standard.set(showModelInToolbar, forKey: "ai.showModelInToolbar")
    }

    // MARK: - Command Generation

    /// Generate Claude command with thinking budget
    func generateClaudeCommand(
        model: AIModel? = nil,
        thinkingLevel: ThinkingLevel? = nil,
        dangerouslySkipPermissions: Bool = false
    ) -> String {
        let selectedModel = model ?? defaultModel
        let selectedThinking = thinkingLevel ?? defaultThinkingLevel

        var command = "claude"

        // Add model flag
        command += " --model \(selectedModel.rawValue)"

        // Add thinking budget if not none
        if selectedThinking != .none {
            command += " --thinking-budget \(selectedThinking.budgetTokens)"
        }

        // Add dangerous mode if requested
        if dangerouslySkipPermissions {
            command += " --dangerously-skip-permissions"
        }

        return command
    }

    /// Generate Claude command for a specific prompt
    func generatePromptCommand(
        prompt: String,
        model: AIModel? = nil,
        thinkingLevel: ThinkingLevel? = nil,
        dangerouslySkipPermissions: Bool = false
    ) -> String {
        var command = generateClaudeCommand(
            model: model,
            thinkingLevel: thinkingLevel,
            dangerouslySkipPermissions: dangerouslySkipPermissions
        )

        // Escape the prompt for shell
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        command += " \"\(escapedPrompt)\""

        return command
    }

    // MARK: - Output Parsing

    /// Parse thinking token usage from Claude output
    /// Returns (thinkingTokens, inputTokens, outputTokens)
    func parseThinkingUsage(_ output: String) -> (thinking: Int, input: Int, output: Int)? {
        // Claude outputs thinking usage in formats like:
        // "Thinking: 1234 tokens"
        // "Input: 5678 tokens, Output: 910 tokens, Thinking: 1112 tokens"

        var thinkingTokens = 0
        var inputTokens = 0
        var outputTokens = 0

        // Pattern for thinking tokens
        let thinkingPattern = "thinking[:\\s]+(\\d+)\\s*tokens?"
        if let regex = try? NSRegularExpression(pattern: thinkingPattern, options: .caseInsensitive) {
            let range = NSRange(output.startIndex..., in: output)
            if let match = regex.firstMatch(in: output, options: [], range: range) {
                if let tokenRange = Range(match.range(at: 1), in: output) {
                    thinkingTokens = Int(output[tokenRange]) ?? 0
                }
            }
        }

        // Pattern for input tokens
        let inputPattern = "input[:\\s]+(\\d+)\\s*tokens?"
        if let regex = try? NSRegularExpression(pattern: inputPattern, options: .caseInsensitive) {
            let range = NSRange(output.startIndex..., in: output)
            if let match = regex.firstMatch(in: output, options: [], range: range) {
                if let tokenRange = Range(match.range(at: 1), in: output) {
                    inputTokens = Int(output[tokenRange]) ?? 0
                }
            }
        }

        // Pattern for output tokens
        let outputPattern = "output[:\\s]+(\\d+)\\s*tokens?"
        if let regex = try? NSRegularExpression(pattern: outputPattern, options: .caseInsensitive) {
            let range = NSRange(output.startIndex..., in: output)
            if let match = regex.firstMatch(in: output, options: [], range: range) {
                if let tokenRange = Range(match.range(at: 1), in: output) {
                    outputTokens = Int(output[tokenRange]) ?? 0
                }
            }
        }

        // Also check for ccusage-style output
        // Format: "Token usage: 12345 input, 6789 output (1234 thinking)"
        let combinedPattern = "token usage:\\s*(\\d+)\\s*input[,\\s]+(\\d+)\\s*output(?:\\s*\\((\\d+)\\s*thinking\\))?"
        if let regex = try? NSRegularExpression(pattern: combinedPattern, options: .caseInsensitive) {
            let range = NSRange(output.startIndex..., in: output)
            if let match = regex.firstMatch(in: output, options: [], range: range) {
                if let inRange = Range(match.range(at: 1), in: output) {
                    inputTokens = Int(output[inRange]) ?? inputTokens
                }
                if let outRange = Range(match.range(at: 2), in: output) {
                    outputTokens = Int(output[outRange]) ?? outputTokens
                }
                if match.numberOfRanges > 3, let thinkRange = Range(match.range(at: 3), in: output) {
                    thinkingTokens = Int(output[thinkRange]) ?? thinkingTokens
                }
            }
        }

        if thinkingTokens > 0 || inputTokens > 0 || outputTokens > 0 {
            return (thinkingTokens, inputTokens, outputTokens)
        }

        return nil
    }

    /// Detect if Claude is in thinking mode (extended output)
    func detectThinkingMode(_ output: String) -> Bool {
        let thinkingIndicators = [
            "Thinking...",
            "thinking about",
            "<thinking>",
            "Let me think",
            "I need to consider"
        ]

        let lowered = output.lowercased()
        return thinkingIndicators.contains { lowered.contains($0.lowercased()) }
    }

    // MARK: - Cost Estimation

    /// Estimate cost for a thinking session
    func estimateCost(
        model: AIModel,
        thinkingLevel: ThinkingLevel,
        estimatedInputTokens: Int = 10000,
        estimatedOutputTokens: Int = 2000
    ) -> Double {
        let totalInputTokens = estimatedInputTokens
        let totalOutputTokens = estimatedOutputTokens + thinkingLevel.budgetTokens

        return model.calculateCost(inputTokens: totalInputTokens, outputTokens: totalOutputTokens)
    }

    /// Format cost as string
    func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return "<$0.01"
        }
        return "$\(String(format: "%.2f", cost))"
    }
}
