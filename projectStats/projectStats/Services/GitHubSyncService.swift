import Foundation
import os.log

@MainActor
final class GitHubSyncService {
    static let shared = GitHubSyncService()
    private let githubClient = GitHubClient.shared
    private init() {}

    func fetchGitHubStats(for projects: [Project], logSync: (String) -> Void) async -> [Project] {
        var updated = projects

        githubClient.refreshAuthStatus()
        if !githubClient.isAuthenticated {
            logSync("github: skipped (not authenticated)")
            return updated
        }

        for i in updated.indices {
            let projectName = updated[i].name

            guard let urlString = updated[i].githubURL, !urlString.isEmpty else {
                updated[i].githubStats = nil
                updated[i].githubStatsError = "skipped: no github remote"
                logSync("github: SKIP \(projectName) (no remote)")
                continue
            }

            guard let (owner, repo) = GitHubClient.parseGitHubURL(urlString) else {
                updated[i].githubStats = nil
                updated[i].githubStatsError = "skipped: unparsable github url"
                logSync("github: SKIP \(projectName) (bad url: \(urlString))")
                continue
            }

            do {
                let repoInfo = try await githubClient.getRepo(owner: owner, repo: repo)
                updated[i].githubStats = GitHubStats(
                    stars: repoInfo.stargazersCount,
                    forks: repoInfo.forksCount,
                    openIssues: repoInfo.openIssuesCount
                )
                updated[i].githubStatsError = nil
                logSync("github: OK \(projectName) (\(owner)/\(repo))")
            } catch {
                updated[i].githubStats = nil
                updated[i].githubStatsError = String(describing: error)
                logSync("github: FAIL \(projectName) (\(owner)/\(repo)) \(error)")
                continue
            }
        }

        return updated
    }
}
