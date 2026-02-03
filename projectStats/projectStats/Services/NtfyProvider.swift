import Foundation

final class NtfyProvider: MessagingProvider {
    private let topic: String
    private let session: URLSession

    init(topic: String, session: URLSession = .shared) {
        self.topic = topic
        self.session = session
    }

    func send(message: String) async throws {
        guard let url = URL(string: "https://ntfy.sh/\(topic)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = message.data(using: .utf8)
        _ = try await session.data(for: request)
    }

    func poll() async throws -> [IncomingMessage] {
        return []
    }
}
