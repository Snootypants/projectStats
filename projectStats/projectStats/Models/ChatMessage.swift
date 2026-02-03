import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var service: String
    var direction: String
    var text: String
    var timestamp: Date
    var projectPath: String?
    var handled: Bool

    init(
        id: UUID = UUID(),
        service: String,
        direction: String,
        text: String,
        timestamp: Date = Date(),
        projectPath: String? = nil,
        handled: Bool = false
    ) {
        self.id = id
        self.service = service
        self.direction = direction
        self.text = text
        self.timestamp = timestamp
        self.projectPath = projectPath
        self.handled = handled
    }
}
