import Foundation

enum EmbeddingError: LocalizedError {
    case missingAPIKey
    case networkError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "OpenAI API key not configured. Set it in Settings to enable project memory."
        case .networkError(let msg): return "Network error: \(msg)"
        case .apiError(let msg): return "OpenAI API error: \(msg)"
        }
    }
}

@MainActor
final class EmbeddingService {
    static let shared = EmbeddingService()
    private init() {}

    /// Total tokens used across all embedding calls this session (for cost tracking)
    @Published var totalTokensUsed: Int = 0

    /// Embed a single text
    func embed(text: String) async throws -> [Float] {
        let results = try await embed(texts: [text])
        return results[0]
    }

    /// Embed multiple texts, batching in groups of 100
    func embed(texts: [String]) async throws -> [[Float]] {
        let apiKey = SettingsViewModel.shared.aiApiKey
        guard !apiKey.isEmpty else { throw EmbeddingError.missingAPIKey }

        var allEmbeddings: [[Float]] = []

        // Batch in groups of 100
        let batchSize = 100
        for batchStart in stride(from: 0, to: texts.count, through: batchSize) {
            let batchEnd = min(batchStart + batchSize, texts.count)
            let batch = Array(texts[batchStart..<batchEnd])

            let embeddings = try await sendBatch(texts: batch, apiKey: apiKey)
            allEmbeddings.append(contentsOf: embeddings)
        }

        return allEmbeddings
    }

    private func sendBatch(texts: [String], apiKey: String) async throws -> [[Float]] {
        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": texts
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw EmbeddingError.apiError(message)
            }
            throw EmbeddingError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        struct EmbeddingResponse: Codable {
            struct EmbeddingData: Codable {
                let embedding: [Float]
                let index: Int
            }
            struct Usage: Codable {
                let totalTokens: Int
                enum CodingKeys: String, CodingKey {
                    case totalTokens = "total_tokens"
                }
            }
            let data: [EmbeddingData]
            let usage: Usage
        }

        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        totalTokensUsed += embeddingResponse.usage.totalTokens
        print("[EmbeddingService] Embedded \(texts.count) texts, \(embeddingResponse.usage.totalTokens) tokens (total: \(totalTokensUsed))")

        // Sort by index to maintain order
        let sorted = embeddingResponse.data.sorted { $0.index < $1.index }
        return sorted.map(\.embedding)
    }
}
