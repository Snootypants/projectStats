import SwiftData
import Foundation

@Model
class AppSetting {
    @Attribute(.unique) var key: String
    var value: String
    var updatedAt: Date

    init(key: String, value: String) {
        self.key = key
        self.value = value
        self.updatedAt = Date()
    }
}
