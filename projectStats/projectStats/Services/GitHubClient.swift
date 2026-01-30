import Foundation

struct GitHubRepo: Codable {
    let name: String
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let language: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case description
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case language
        case updatedAt = "updated_at"
    }
}

struct GitHubCommit: Codable {
    let sha: String
    let commit: CommitDetail
    let stats: CommitStats?

    struct CommitDetail: Codable {
        let message: String
        let author: CommitAuthor
    }

    struct CommitAuthor: Codable {
        let name: String
        let date: String
    }

    struct CommitStats: Codable {
        let additions: Int
        let deletions: Int
        let total: Int
    }
}

struct ContributionDay: Codable {
    let date: String
    let contributionCount: Int
}

struct ContributionWeek: Codable {
    let contributionDays: [ContributionDay]
}

struct ContributionCalendar: Codable {
    let totalContributions: Int
    let weeks: [ContributionWeek]
}

class GitHubClient: ObservableObject {
    static let shared = GitHubClient()

    @Published var isAuthenticated = false

    private var token: String? {
        SettingsViewModel.shared.githubToken.isEmpty ? nil : SettingsViewModel.shared.githubToken
    }

    private let baseURL = "https://api.github.com"
    private let session = URLSession.shared

    private init() {
        isAuthenticated = token != nil
    }

    func refreshAuthStatus() {
        isAuthenticated = token != nil && !token!.isEmpty
    }

    // MARK: - REST API Methods

    func getRepo(owner: String, repo: String) async throws -> GitHubRepo {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)")!
        let data = try await makeRequest(url: url)
        return try JSONDecoder().decode(GitHubRepo.self, from: data)
    }

    func getCommits(owner: String, repo: String, since: Date? = nil, perPage: Int = 30) async throws -> [GitHubCommit] {
        var urlString = "\(baseURL)/repos/\(owner)/\(repo)/commits?per_page=\(perPage)"

        if let since = since {
            let formatter = ISO8601DateFormatter()
            urlString += "&since=\(formatter.string(from: since))"
        }

        let url = URL(string: urlString)!
        let data = try await makeRequest(url: url)
        return try JSONDecoder().decode([GitHubCommit].self, from: data)
    }

    func getCommitStats(owner: String, repo: String, sha: String) async throws -> GitHubCommit {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/commits/\(sha)")!
        let data = try await makeRequest(url: url)
        return try JSONDecoder().decode(GitHubCommit.self, from: data)
    }

    // MARK: - GraphQL for Contribution Calendar

    func getContributionCalendar(username: String) async throws -> ContributionCalendar {
        let query = """
        query {
            user(login: "\(username)") {
                contributionsCollection {
                    contributionCalendar {
                        totalContributions
                        weeks {
                            contributionDays {
                                date
                                contributionCount
                            }
                        }
                    }
                }
            }
        }
        """

        let url = URL(string: "https://api.github.com/graphql")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GitHubError.requestFailed
        }

        // Parse GraphQL response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataObj = json?["data"] as? [String: Any]
        let user = dataObj?["user"] as? [String: Any]
        let collection = user?["contributionsCollection"] as? [String: Any]
        let calendarData = collection?["contributionCalendar"] as? [String: Any]

        guard let calendarData = calendarData else {
            throw GitHubError.parseError
        }

        let calendarJSON = try JSONSerialization.data(withJSONObject: calendarData)
        return try JSONDecoder().decode(ContributionCalendar.self, from: calendarJSON)
    }

    // MARK: - Helper to parse owner/repo from GitHub URL

    static func parseGitHubURL(_ urlString: String) -> (owner: String, repo: String)? {
        // Handle: https://github.com/owner/repo or git@github.com:owner/repo.git
        let cleaned = urlString
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "http://github.com/", with: "")
            .replacingOccurrences(of: "git@github.com:", with: "")
            .replacingOccurrences(of: ".git", with: "")

        let parts = cleaned.split(separator: "/")
        guard parts.count >= 2 else { return nil }

        return (String(parts[0]), String(parts[1]))
    }

    // MARK: - Private

    private func makeRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.requestFailed
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw GitHubError.unauthorized
        case 403:
            throw GitHubError.rateLimited
        case 404:
            throw GitHubError.notFound
        default:
            throw GitHubError.requestFailed
        }
    }
}

enum GitHubError: Error, LocalizedError {
    case unauthorized
    case rateLimited
    case notFound
    case requestFailed
    case parseError

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Invalid GitHub token"
        case .rateLimited: return "GitHub API rate limit exceeded"
        case .notFound: return "Repository not found"
        case .requestFailed: return "GitHub API request failed"
        case .parseError: return "Failed to parse GitHub response"
        }
    }
}
