import Foundation
import SwiftData

/// Registry for managing AI providers
@MainActor
final class AIProviderRegistry: ObservableObject {
    static let shared = AIProviderRegistry()

    @Published private(set) var providers: [AIProviderConfig] = []
    @Published private(set) var defaultProvider: AIProviderConfig?

    private init() {}

    // MARK: - Loading

    /// Load all providers from SwiftData
    func loadProviders(context: ModelContext) {
        let descriptor = FetchDescriptor<AIProviderConfig>(
            sortBy: [SortDescriptor(\.createdAt)]
        )

        do {
            providers = try context.fetch(descriptor)
            defaultProvider = providers.first { $0.isDefault }

            // Create defaults if none exist
            if providers.isEmpty {
                createDefaultProviders(context: context)
            }
        } catch {
            print("[AIProviderRegistry] Failed to load providers: \(error)")
            createDefaultProviders(context: context)
        }
    }

    /// Create default provider configurations
    func createDefaultProviders(context: ModelContext) {
        // Claude Code (CLI)
        let claudeCode = AIProviderConfig(
            providerType: .claudeCode,
            isEnabled: true,
            isDefault: true,
            defaultModel: .claudeSonnet4,
            defaultThinkingLevel: .none
        )

        // Codex (CLI)
        let codex = AIProviderConfig(
            providerType: .codex,
            isEnabled: true,
            isDefault: false,
            defaultModel: .claudeSonnet4
        )

        // Anthropic API
        let anthropicAPI = AIProviderConfig(
            providerType: .anthropicAPI,
            isEnabled: false,
            isDefault: false,
            defaultModel: .claudeSonnet4,
            defaultThinkingLevel: .none
        )

        // OpenAI API
        let openaiAPI = AIProviderConfig(
            providerType: .openaiAPI,
            isEnabled: false,
            isDefault: false,
            defaultModel: .gpt4o
        )

        // Ollama (local)
        let ollama = AIProviderConfig(
            providerType: .ollama,
            isEnabled: false,
            isDefault: false,
            defaultModel: .llama3_2,
            ollamaHost: "localhost",
            ollamaPort: 11434
        )

        let defaults = [claudeCode, codex, anthropicAPI, openaiAPI, ollama]

        for provider in defaults {
            context.insert(provider)
        }

        do {
            try context.save()
            providers = defaults
            defaultProvider = claudeCode
            print("[AIProviderRegistry] Created default providers")
        } catch {
            print("[AIProviderRegistry] Failed to save default providers: \(error)")
        }
    }

    // MARK: - CRUD Operations

    /// Add a new provider
    func addProvider(_ provider: AIProviderConfig, context: ModelContext) {
        context.insert(provider)

        do {
            try context.save()
            providers.append(provider)
            print("[AIProviderRegistry] Added provider: \(provider.displayName)")
        } catch {
            print("[AIProviderRegistry] Failed to add provider: \(error)")
        }
    }

    /// Update an existing provider
    func updateProvider(_ provider: AIProviderConfig, context: ModelContext) {
        provider.updatedAt = Date()

        do {
            try context.save()
            // Refresh providers list
            loadProviders(context: context)
            print("[AIProviderRegistry] Updated provider: \(provider.displayName)")
        } catch {
            print("[AIProviderRegistry] Failed to update provider: \(error)")
        }
    }

    /// Delete a provider
    func deleteProvider(_ provider: AIProviderConfig, context: ModelContext) {
        // Don't delete built-in providers, just disable them
        let builtInTypes: [AIProviderType] = [.claudeCode, .codex, .anthropicAPI, .openaiAPI, .ollama]
        if builtInTypes.contains(provider.type) {
            provider.isEnabled = false
            updateProvider(provider, context: context)
            return
        }

        context.delete(provider)

        do {
            try context.save()
            providers.removeAll { $0.id == provider.id }
            if provider.isDefault, let first = enabledProviders.first {
                setDefaultProvider(first, context: context)
            }
            print("[AIProviderRegistry] Deleted provider: \(provider.displayName)")
        } catch {
            print("[AIProviderRegistry] Failed to delete provider: \(error)")
        }
    }

    /// Set the default provider
    func setDefaultProvider(_ provider: AIProviderConfig, context: ModelContext) {
        // Clear existing default
        for p in providers where p.isDefault {
            p.isDefault = false
        }

        provider.isDefault = true
        provider.updatedAt = Date()
        defaultProvider = provider

        do {
            try context.save()
            print("[AIProviderRegistry] Set default provider: \(provider.displayName)")
        } catch {
            print("[AIProviderRegistry] Failed to set default provider: \(error)")
        }
    }

    // MARK: - Queries

    /// Get provider by type
    func provider(for type: AIProviderType) -> AIProviderConfig? {
        providers.first { $0.type == type }
    }

    /// Get all enabled providers
    var enabledProviders: [AIProviderConfig] {
        providers.filter { $0.isEnabled }
    }

    /// Get CLI providers (Claude Code, Codex)
    var cliProviders: [AIProviderConfig] {
        providers.filter { $0.type.isCLITool && $0.isEnabled }
    }

    /// Get API providers (Anthropic, OpenAI)
    var apiProviders: [AIProviderConfig] {
        providers.filter { !$0.type.isCLITool && $0.isEnabled }
    }

    /// Get available models for a provider
    func availableModels(for provider: AIProviderConfig) -> [AIModel] {
        AIModel.models(for: provider.type)
    }

    /// Get available models for a provider type
    func availableModels(for type: AIProviderType) -> [AIModel] {
        AIModel.models(for: type)
    }

    // MARK: - Validation

    /// Check if a provider is properly configured
    func isConfigured(_ provider: AIProviderConfig) -> Bool {
        switch provider.type {
        case .claudeCode, .codex:
            // CLI tools just need to be installed
            return true
        case .anthropicAPI, .openaiAPI, .custom:
            // Need API key
            return !(provider.apiKey?.isEmpty ?? true)
        case .ollama:
            // Need host/port (defaults are fine)
            return true
        }
    }

    /// Test connection to a provider
    func testConnection(for provider: AIProviderConfig) async -> (success: Bool, message: String) {
        switch provider.type {
        case .claudeCode:
            return await testClaudeCodeConnection()
        case .codex:
            return await testCodexConnection()
        case .ollama:
            return await testOllamaConnection(provider)
        case .anthropicAPI:
            return await testAnthropicConnection(provider)
        case .openaiAPI:
            return await testOpenAIConnection(provider)
        case .custom:
            return (false, "Custom provider testing not implemented")
        }
    }

    private func testClaudeCodeConnection() async -> (Bool, String) {
        let result = Shell.run("which claude")
        if result.contains("claude") {
            let version = Shell.run("claude --version").trimmingCharacters(in: .whitespacesAndNewlines)
            return (true, "Claude Code installed: \(version)")
        }
        return (false, "Claude Code not found. Install with: npm install -g @anthropic-ai/claude-code")
    }

    private func testCodexConnection() async -> (Bool, String) {
        let result = Shell.run("which codex")
        if result.contains("codex") {
            let version = Shell.run("codex --version").trimmingCharacters(in: .whitespacesAndNewlines)
            return (true, "Codex installed: \(version)")
        }
        return (false, "Codex not found. Install with: npm install -g @openai/codex")
    }

    private func testOllamaConnection(_ provider: AIProviderConfig) async -> (Bool, String) {
        let url = URL(string: "\(provider.ollamaURL)/api/tags")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return (true, "Ollama is running at \(provider.ollamaURL)")
            }
            return (false, "Ollama returned unexpected status")
        } catch {
            return (false, "Cannot connect to Ollama: \(error.localizedDescription)")
        }
    }

    private func testAnthropicConnection(_ provider: AIProviderConfig) async -> (Bool, String) {
        guard let apiKey = provider.apiKey, !apiKey.isEmpty else {
            return (false, "API key not configured")
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10

        let payload: [String: Any] = [
            "model": "claude-haiku-4-20250514",
            "max_tokens": 10,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, "Anthropic API connected successfully")
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid API key")
                }
            }
            return (false, "Unexpected response from Anthropic")
        } catch {
            return (false, "Cannot connect to Anthropic: \(error.localizedDescription)")
        }
    }

    private func testOpenAIConnection(_ provider: AIProviderConfig) async -> (Bool, String) {
        guard let apiKey = provider.apiKey, !apiKey.isEmpty else {
            return (false, "API key not configured")
        }

        let baseURL = provider.baseURL?.isEmpty == false ? provider.baseURL! : "https://api.openai.com/v1"
        guard let url = URL(string: "\(baseURL)/models") else {
            return (false, "Invalid base URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, "OpenAI API connected successfully")
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid API key")
                }
            }
            return (false, "Unexpected response from OpenAI")
        } catch {
            return (false, "Cannot connect to OpenAI: \(error.localizedDescription)")
        }
    }
}
