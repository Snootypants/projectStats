import Foundation

struct ProjectTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var templateType: String
    var path: String
    var defaultTemperament: String?
    var requiresGit: Bool

    init(
        name: String,
        description: String,
        templateType: String,
        path: String,
        defaultTemperament: String? = nil,
        requiresGit: Bool = true
    ) {
        self.name = name
        self.description = description
        self.templateType = templateType
        self.path = path
        self.defaultTemperament = defaultTemperament
        self.requiresGit = requiresGit
    }
}
