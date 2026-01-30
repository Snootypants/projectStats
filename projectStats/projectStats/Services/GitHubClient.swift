import Foundation

struct GitHubRepoInfo: Codable {
    let name: String
    let fullName: String
    let description: String?
    let htmlUrl: String
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let language: String?
    let pushedAt: String?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case description
        case htmlUrl = "html_url"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case language
        case pushedAt = "pushed_at"
    }
}

class GitHubClient {
    static let shared = GitHubClient()

    var token: String? {
        get { UserDefaults.standard.string(forKey: "githubToken") }
        set { UserDefaults.standard.set(newValue, forKey: "githubToken") }
    }

    private init() {}

    private var headers: [String: String] {
        var headers = ["Accept": "application/vnd.github.v3+json"]
        if let token = token, !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    func getRepoInfo(owner: String, repo: String) async throws -> GitHubRepoInfo {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)")!
        var request = URLRequest(url: url)

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GitHubError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRepoInfo.self, from: data)
    }

    func parseGitHubURL(_ urlString: String) -> (owner: String, repo: String)? {
        // Handle both https://github.com/owner/repo and github.com/owner/repo
        let cleaned = urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "github.com/", with: "")
            .replacingOccurrences(of: ".git", with: "")

        let parts = cleaned.split(separator: "/")
        guard parts.count >= 2 else { return nil }

        return (String(parts[0]), String(parts[1]))
    }

    func fetchRepoInfo(for project: Project) async -> GitHubRepoInfo? {
        guard let githubURL = project.githubURL,
              let (owner, repo) = parseGitHubURL(githubURL) else {
            return nil
        }

        return try? await getRepoInfo(owner: owner, repo: repo)
    }
}

enum GitHubError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
}
