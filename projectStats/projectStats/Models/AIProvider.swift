import Foundation
import SwiftData

// MARK: - AI Provider Types

/// Types of AI providers supported by the app
enum AIProviderType: String, CaseIterable, Codable {
    case claudeCode = "claude_code"
    case codex = "codex"
    case anthropicAPI = "anthropic_api"
    case openaiAPI = "openai_api"
    case ollama = "ollama"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .anthropicAPI: return "Anthropic API"
        case .openaiAPI: return "OpenAI API"
        case .ollama: return "Ollama"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .claudeCode: return "terminal"
        case .codex: return "text.cursor"
        case .anthropicAPI: return "brain"
        case .openaiAPI: return "sparkles"
        case .ollama: return "desktopcomputer"
        case .custom: return "slider.horizontal.3"
        }
    }

    var supportsThinkingLevels: Bool {
        switch self {
        case .claudeCode, .anthropicAPI: return true
        case .codex, .openaiAPI, .ollama, .custom: return false
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .claudeCode, .codex: return false  // CLI tools use OAuth
        case .anthropicAPI, .openaiAPI: return true
        case .ollama: return false  // Local
        case .custom: return true
        }
    }

    var isCLITool: Bool {
        switch self {
        case .claudeCode, .codex: return true
        default: return false
        }
    }
}

// MARK: - AI Models

/// All available AI models with their pricing
enum AIModel: String, CaseIterable, Codable {
    // Claude 4 Series
    case claudeSonnet4 = "claude-sonnet-4-20250514"
    case claudeOpus4 = "claude-opus-4-20250514"
    case claudeHaiku4 = "claude-haiku-4-20250514"

    // Claude 4.5/4.6 Series (Current)
    case claudeOpus46 = "claude-opus-4-6"
    case claudeSonnet45 = "claude-sonnet-4-5-20250929"
    case claudeHaiku45 = "claude-haiku-4-5-20251001"

    // Claude 5 Series (Coming Soon)
    case claudeSonnet5 = "claude-sonnet-5-coming-soon"

    // OpenAI Models
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4_1 = "gpt-4.1"
    case o3 = "o3"
    case o4Mini = "o4-mini"

    // Ollama Models (local)
    case llama3_2 = "llama3.2"
    case codellama = "codellama"
    case deepseekCoder = "deepseek-coder"
    case qwen2_5Coder = "qwen2.5-coder"

    var displayName: String {
        switch self {
        case .claudeSonnet4: return "Claude Sonnet 4"
        case .claudeOpus4: return "Claude Opus 4"
        case .claudeHaiku4: return "Claude Haiku 4"
        case .claudeOpus46: return "Claude Opus 4.6"
        case .claudeSonnet45: return "Claude Sonnet 4.5"
        case .claudeHaiku45: return "Claude Haiku 4.5"
        case .claudeSonnet5: return "Claude Sonnet 5"
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini"
        case .gpt4_1: return "GPT-4.1"
        case .o3: return "o3"
        case .o4Mini: return "o4-mini"
        case .llama3_2: return "Llama 3.2"
        case .codellama: return "Code Llama"
        case .deepseekCoder: return "DeepSeek Coder"
        case .qwen2_5Coder: return "Qwen 2.5 Coder"
        }
    }

    var provider: AIProviderType {
        switch self {
        case .claudeSonnet4, .claudeOpus4, .claudeHaiku4,
             .claudeOpus46, .claudeSonnet45, .claudeHaiku45, .claudeSonnet5:
            return .anthropicAPI
        case .gpt4o, .gpt4oMini, .gpt4_1, .o3, .o4Mini:
            return .openaiAPI
        case .llama3_2, .codellama, .deepseekCoder, .qwen2_5Coder:
            return .ollama
        }
    }

    /// Input cost per 1 million tokens (USD)
    var inputCostPer1M: Double {
        switch self {
        // Claude 4 Series
        case .claudeSonnet4: return 3.00
        case .claudeOpus4: return 15.00
        case .claudeHaiku4: return 0.80
        // Claude 4.5/4.6 Series
        case .claudeOpus46: return 15.00
        case .claudeSonnet45: return 3.00
        case .claudeHaiku45: return 0.80
        case .claudeSonnet5: return 3.00
        // OpenAI
        case .gpt4o: return 2.50
        case .gpt4oMini: return 0.15
        case .gpt4_1: return 2.00
        case .o3: return 10.00
        case .o4Mini: return 1.10
        // Local models (free)
        case .llama3_2, .codellama, .deepseekCoder, .qwen2_5Coder:
            return 0.0
        }
    }

    /// Output cost per 1 million tokens (USD)
    var outputCostPer1M: Double {
        switch self {
        // Claude 4 Series
        case .claudeSonnet4: return 15.00
        case .claudeOpus4: return 75.00
        case .claudeHaiku4: return 4.00
        // Claude 4.5/4.6 Series
        case .claudeOpus46: return 75.00
        case .claudeSonnet45: return 15.00
        case .claudeHaiku45: return 4.00
        case .claudeSonnet5: return 15.00
        // OpenAI
        case .gpt4o: return 10.00
        case .gpt4oMini: return 0.60
        case .gpt4_1: return 8.00
        case .o3: return 40.00
        case .o4Mini: return 4.40
        // Local models (free)
        case .llama3_2, .codellama, .deepseekCoder, .qwen2_5Coder:
            return 0.0
        }
    }

    /// Short CLI name for Claude Code's --model flag
    var cliName: String {
        switch self {
        case .claudeSonnet4: return "sonnet"
        case .claudeOpus4: return "opus"
        case .claudeHaiku4: return "haiku"
        // 4.5/4.6 series: full identifiers ARE the correct CLI names
        case .claudeOpus46: return "claude-opus-4-6"
        case .claudeSonnet45: return "claude-sonnet-4-5-20250929"
        case .claudeHaiku45: return "claude-haiku-4-5-20251001"
        default: return rawValue
        }
    }

    var isLocal: Bool {
        provider == .ollama
    }

    var isComingSoon: Bool {
        switch self {
        case .claudeSonnet5: return true
        default: return false
        }
    }

    /// Calculate cost for a session
    func calculateCost(inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = (Double(inputTokens) / 1_000_000) * inputCostPer1M
        let outputCost = (Double(outputTokens) / 1_000_000) * outputCostPer1M
        return inputCost + outputCost
    }

    /// Models available for a specific provider type
    static func models(for provider: AIProviderType) -> [AIModel] {
        switch provider {
        case .claudeCode, .anthropicAPI:
            return [.claudeOpus46, .claudeSonnet45, .claudeHaiku45, .claudeSonnet5,
                    .claudeSonnet4, .claudeOpus4, .claudeHaiku4]
        case .codex:
            return [.claudeOpus46, .claudeSonnet45, .claudeOpus4]  // Codex uses Claude models
        case .openaiAPI:
            return [.gpt4o, .gpt4oMini, .gpt4_1, .o3, .o4Mini]
        case .ollama:
            return [.llama3_2, .codellama, .deepseekCoder, .qwen2_5Coder]
        case .custom:
            return []  // Custom models are user-defined
        }
    }
}

// MARK: - Thinking Levels

/// Thinking levels for extended thinking in Claude
enum ThinkingLevel: String, CaseIterable, Codable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    /// Budget tokens for thinking
    var budgetTokens: Int {
        switch self {
        case .none: return 0
        case .low: return 1024
        case .medium: return 4096
        case .high: return 16384
        }
    }

    var icon: String {
        switch self {
        case .none: return "bolt"
        case .low: return "brain"
        case .medium: return "brain.head.profile"
        case .high: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .none: return "Fast responses"
        case .low: return "Light reasoning"
        case .medium: return "Moderate analysis"
        case .high: return "Deep thinking"
        }
    }
}

// MARK: - AI Provider Configuration (SwiftData)

/// Persistent configuration for an AI provider
@Model
final class AIProviderConfig {
    var id: UUID
    var providerType: String  // AIProviderType raw value
    var displayName: String
    var isEnabled: Bool
    var isDefault: Bool
    var apiKey: String?
    var baseURL: String?
    var defaultModelRaw: String?  // AIModel raw value
    var defaultThinkingLevelRaw: String?  // ThinkingLevel raw value
    var createdAt: Date
    var updatedAt: Date

    // Ollama-specific
    var ollamaHost: String?
    var ollamaPort: Int?

    init(
        providerType: AIProviderType,
        displayName: String? = nil,
        isEnabled: Bool = true,
        isDefault: Bool = false,
        apiKey: String? = nil,
        baseURL: String? = nil,
        defaultModel: AIModel? = nil,
        defaultThinkingLevel: ThinkingLevel? = nil,
        ollamaHost: String? = nil,
        ollamaPort: Int? = nil
    ) {
        self.id = UUID()
        self.providerType = providerType.rawValue
        self.displayName = displayName ?? providerType.displayName
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.defaultModelRaw = defaultModel?.rawValue
        self.defaultThinkingLevelRaw = defaultThinkingLevel?.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.ollamaHost = ollamaHost
        self.ollamaPort = ollamaPort
    }

    var type: AIProviderType {
        AIProviderType(rawValue: providerType) ?? .custom
    }

    var defaultModel: AIModel? {
        get {
            guard let raw = defaultModelRaw else { return nil }
            return AIModel(rawValue: raw)
        }
        set {
            defaultModelRaw = newValue?.rawValue
            updatedAt = Date()
        }
    }

    var defaultThinkingLevel: ThinkingLevel {
        get {
            guard let raw = defaultThinkingLevelRaw else { return .none }
            return ThinkingLevel(rawValue: raw) ?? .none
        }
        set {
            defaultThinkingLevelRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var ollamaURL: String {
        let host = ollamaHost ?? "localhost"
        let port = ollamaPort ?? 11434
        return "http://\(host):\(port)"
    }

    var icon: String {
        type.icon
    }

    var availableModels: [AIModel] {
        AIModel.models(for: type)
    }
}

// MARK: - AI Session V2 (Enhanced tracking)

/// Enhanced AI session tracking with provider info
@Model
final class AISessionV2 {
    var id: UUID
    var providerType: String
    var modelRaw: String
    var thinkingLevelRaw: String?
    var projectPath: String?
    var startTime: Date
    var endTime: Date?
    var inputTokens: Int
    var outputTokens: Int
    var thinkingTokens: Int
    var cacheReadTokens: Int
    var cacheWriteTokens: Int
    var costUSD: Double
    var wasSuccessful: Bool
    var errorMessage: String?

    init(
        providerType: AIProviderType,
        model: AIModel,
        thinkingLevel: ThinkingLevel? = nil,
        projectPath: String? = nil
    ) {
        self.id = UUID()
        self.providerType = providerType.rawValue
        self.modelRaw = model.rawValue
        self.thinkingLevelRaw = thinkingLevel?.rawValue
        self.projectPath = projectPath
        self.startTime = Date()
        self.endTime = nil
        self.inputTokens = 0
        self.outputTokens = 0
        self.thinkingTokens = 0
        self.cacheReadTokens = 0
        self.cacheWriteTokens = 0
        self.costUSD = 0
        self.wasSuccessful = true
        self.errorMessage = nil
    }

    var provider: AIProviderType {
        AIProviderType(rawValue: providerType) ?? .custom
    }

    var model: AIModel? {
        AIModel(rawValue: modelRaw)
    }

    var thinkingLevel: ThinkingLevel? {
        guard let raw = thinkingLevelRaw else { return nil }
        return ThinkingLevel(rawValue: raw)
    }

    var duration: TimeInterval {
        guard let endTime else { return Date().timeIntervalSince(startTime) }
        return endTime.timeIntervalSince(startTime)
    }

    var totalTokens: Int {
        inputTokens + outputTokens + thinkingTokens
    }

    var isActive: Bool {
        endTime == nil
    }

    func end(
        inputTokens: Int,
        outputTokens: Int,
        thinkingTokens: Int = 0,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0,
        wasSuccessful: Bool = true,
        errorMessage: String? = nil
    ) {
        self.endTime = Date()
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.thinkingTokens = thinkingTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.wasSuccessful = wasSuccessful
        self.errorMessage = errorMessage

        // Calculate cost
        if let model = self.model {
            self.costUSD = model.calculateCost(inputTokens: inputTokens, outputTokens: outputTokens + thinkingTokens)
        }
    }

    var projectName: String? {
        guard let projectPath else { return nil }
        return URL(fileURLWithPath: projectPath).lastPathComponent
    }
}
