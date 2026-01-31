import Foundation

struct ProjectGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var projectPaths: [String]  // Paths of projects in this group
    var createdAt: Date

    init(id: UUID = UUID(), name: String, projectPaths: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.projectPaths = projectPaths
        self.createdAt = createdAt
    }
}

class ProjectGroupStore: ObservableObject {
    static let shared = ProjectGroupStore()

    @Published var groups: [ProjectGroup] = []

    private let saveKey = "projectGroups"

    private init() {
        loadGroups()
    }

    func loadGroups() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([ProjectGroup].self, from: data) else {
            return
        }
        groups = decoded
    }

    func saveGroups() {
        guard let encoded = try? JSONEncoder().encode(groups) else { return }
        UserDefaults.standard.set(encoded, forKey: saveKey)
    }

    func createGroup(name: String, projectPaths: [String]) {
        let group = ProjectGroup(name: name, projectPaths: projectPaths)
        groups.append(group)
        saveGroups()
    }

    func addToGroup(_ groupId: UUID, projectPath: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        if !groups[index].projectPaths.contains(projectPath) {
            groups[index].projectPaths.append(projectPath)
            saveGroups()
        }
    }

    func removeFromGroup(_ groupId: UUID, projectPath: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        groups[index].projectPaths.removeAll { $0 == projectPath }
        saveGroups()
    }

    func deleteGroup(_ groupId: UUID) {
        groups.removeAll { $0.id == groupId }
        saveGroups()
    }

    func renameGroup(_ groupId: UUID, newName: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        groups[index].name = newName
        saveGroups()
    }

    func group(for projectPath: String) -> ProjectGroup? {
        groups.first { $0.projectPaths.contains(projectPath) }
    }

    func isGrouped(_ projectPath: String) -> Bool {
        groups.contains { $0.projectPaths.contains(projectPath) }
    }
}
