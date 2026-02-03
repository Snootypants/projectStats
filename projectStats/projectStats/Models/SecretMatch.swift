import Foundation

struct SecretMatch: Identifiable, Hashable {
    var id: UUID = UUID()
    var type: String
    var filePath: String
    var line: Int?
    var snippet: String?
}
