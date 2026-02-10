import Foundation

// MARK: - DORMANT — Not wired to any UI or ViewModel.
// Scaffolded early but superseded by AIProviderRegistry + per-provider logic.
// Do NOT maintain or update until activated.
// To activate: remove this marker, wire to a ViewModel, add tests.

enum AIProvider: String, CaseIterable, Codable {
    case anthropic
    case openai
    case kimi
    case local

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .kimi: return "Kimi"
        case .local: return "Local"
        }
    }
}

@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()

    @Published var lastError: String?

    private init() {}

    func send(prompt: String, system: String? = nil) async -> String? {
        do {
            switch SettingsViewModel.shared.aiProvider {
            case .anthropic:
                return try await sendAnthropic(prompt: prompt, system: system)
            case .openai:
                return try await sendOpenAI(prompt: prompt, system: system)
            case .kimi:
                return try await sendOpenAICompatible(prompt: prompt, system: system, baseURL: SettingsViewModel.shared.aiBaseURL)
            case .local:
                return try await sendOllama(prompt: prompt, system: system)
            }
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func embed(text: String) async -> [Float] {
        // Placeholder embedding until external API is wired.
        // Deterministic hash-based vector to keep search functional.
        var vector = Array(repeating: Float(0), count: 64)
        for (idx, scalar) in text.unicodeScalars.enumerated() {
            let bucket = idx % vector.count
            vector[bucket] += Float(scalar.value % 101) / 100.0
        }
        return vector
    }

    private func sendAnthropic(prompt: String, system: String?) async throws -> String {
        guard !SettingsViewModel.shared.aiApiKey.isEmpty else { throw AIError.missingKey }
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SettingsViewModel.shared.aiApiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var payload: [String: Any] = [
            "model": SettingsViewModel.shared.aiModel,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        if let system, !system.isEmpty {
            payload["system"] = system
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await URLSession.shared.data(for: request)

        struct AnthropicResponse: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return response.content.first?.text ?? ""
    }

    private func sendOpenAI(prompt: String, system: String?) async throws -> String {
        guard !SettingsViewModel.shared.aiApiKey.isEmpty else { throw AIError.missingKey }
        return try await sendOpenAICompatible(prompt: prompt, system: system, baseURL: "https://api.openai.com/v1")
    }

    private func sendOpenAICompatible(prompt: String, system: String?, baseURL: String) async throws -> String {
        guard !SettingsViewModel.shared.aiApiKey.isEmpty else { throw AIError.missingKey }
        let base = baseURL.isEmpty ? "https://api.openai.com/v1" : baseURL
        let url = URL(string: "\(base)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SettingsViewModel.shared.aiApiKey)", forHTTPHeaderField: "Authorization")

        var messages: [[String: String]] = []
        if let system, !system.isEmpty {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": prompt])

        let payload: [String: Any] = [
            "model": SettingsViewModel.shared.aiModel,
            "messages": messages,
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }

    private func sendOllama(prompt: String, system: String?) async throws -> String {
        let url = URL(string: "http://localhost:11434/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [[String: String]] = []
        if let system, !system.isEmpty {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": prompt])

        let payload: [String: Any] = [
            "model": SettingsViewModel.shared.aiModel,
            "messages": messages,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        struct OllamaResponse: Codable {
            struct Message: Codable { let content: String }
            let message: Message
        }
        let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return response.message.content
    }
}

enum AIError: Error {
    case missingKey
}
