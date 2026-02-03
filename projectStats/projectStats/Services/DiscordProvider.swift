import Foundation

final class DiscordProvider: MessagingProvider {
    private let webhookURL: String
    private let session: URLSession

    init(webhookURL: String, session: URLSession = .shared) {
        self.webhookURL = webhookURL
        self.session = session
    }

    func send(message: String) async throws {
        guard let url = URL(string: webhookURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["content": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await session.data(for: request)
    }

    func poll() async throws -> [IncomingMessage] {
        return []
    }
}
