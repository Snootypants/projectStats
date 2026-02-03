import Foundation

final class TelegramProvider: MessagingProvider {
    private let token: String
    private let chatId: String
    private let session: URLSession
    private let offsetKey = "messaging.telegramOffset"

    init(token: String, chatId: String, session: URLSession = .shared) {
        self.token = token
        self.chatId = chatId
        self.session = session
    }

    func send(message: String) async throws {
        let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "chat_id": chatId,
            "text": message,
            "parse_mode": "Markdown"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await session.data(for: request)
    }

    func poll() async throws -> [IncomingMessage] {
        let offset = UserDefaults.standard.integer(forKey: offsetKey)
        let url = URL(string: "https://api.telegram.org/bot\(token)/getUpdates?offset=\(offset)")!
        let (data, _) = try await session.data(from: url)

        struct TelegramResponse: Codable {
            struct Update: Codable {
                struct Message: Codable {
                    struct Chat: Codable {
                        let id: Int64
                    }

                    struct From: Codable {
                        let username: String?
                        let firstName: String?
                        let lastName: String?

                        enum CodingKeys: String, CodingKey {
                            case username
                            case firstName = "first_name"
                            case lastName = "last_name"
                        }
                    }

                    let messageId: Int
                    let text: String?
                    let date: TimeInterval
                    let chat: Chat
                    let from: From?

                    enum CodingKeys: String, CodingKey {
                        case messageId = "message_id"
                        case text
                        case date
                        case chat
                        case from
                    }
                }

                let updateId: Int
                let message: Message?

                enum CodingKeys: String, CodingKey {
                    case updateId = "update_id"
                    case message
                }
            }

            let result: [Update]
        }

        let response = try JSONDecoder().decode(TelegramResponse.self, from: data)
        var messages: [IncomingMessage] = []
        var maxUpdateId = offset

        for update in response.result {
            maxUpdateId = max(maxUpdateId, update.updateId + 1)
            guard let message = update.message,
                  let text = message.text,
                  String(message.chat.id) == chatId else { continue }

            let sender = [message.from?.firstName, message.from?.lastName]
                .compactMap { $0 }
                .joined(separator: " ")

            messages.append(IncomingMessage(
                id: String(update.updateId),
                text: text,
                timestamp: Date(timeIntervalSince1970: message.date),
                sender: sender.isEmpty ? message.from?.username : sender
            ))
        }

        if maxUpdateId != offset {
            UserDefaults.standard.set(maxUpdateId, forKey: offsetKey)
        }

        return messages
    }
}
