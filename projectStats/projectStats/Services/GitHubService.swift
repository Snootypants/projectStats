import Foundation

struct GitHubNotification: Identifiable, Codable {
    struct Subject: Codable {
        let title: String
        let type: String
        let url: String?
    }

    struct Repository: Codable {
        let fullName: String

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
        }
    }

    let id: String
    let repository: Repository
    let subject: Subject
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case repository
        case subject
        case updatedAt = "updated_at"
    }
}

@MainActor
final class GitHubService: ObservableObject {
    static let shared = GitHubService()

    @Published var notifications: [GitHubNotification] = []
    @Published var lastError: String?

    private init() {}

    func fetchNotifications() async {
        guard !SettingsViewModel.shared.githubToken.isEmpty else {
            notifications = []
            return
        }

        var request = URLRequest(url: URL(string: "https://api.github.com/notifications")!)
        request.setValue("Bearer \(SettingsViewModel.shared.githubToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            notifications = try JSONDecoder().decode([GitHubNotification].self, from: data)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
