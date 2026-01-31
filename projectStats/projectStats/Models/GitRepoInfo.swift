import Foundation

struct GitRepoInfo: Hashable, Sendable {
    let repoRoot: String
    let branch: String?
    let remoteURL: String?
    let githubOwner: String?
    let githubRepo: String?
    let lastCommitHash: String?
    let lastCommitDateISO: String?
    let lastCommitSubject: String?
    let isGitRepo: Bool
    let errorMessage: String?

    var displayName: String {
        if let owner = githubOwner, let repo = githubRepo {
            return "\(owner)/\(repo)"
        }
        return URL(fileURLWithPath: repoRoot).lastPathComponent
    }

    var githubURL: String? {
        guard let owner = githubOwner, let repo = githubRepo else { return nil }
        return "https://github.com/\(owner)/\(repo)"
    }

    var webRemoteURL: String? {
        guard let remoteURL = remoteURL, !remoteURL.isEmpty else { return nil }

        if remoteURL.hasPrefix("git@github.com:") {
            let repoPath = remoteURL
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: ".git", with: "")
            return "https://github.com/\(repoPath)"
        }

        if remoteURL.hasPrefix("https://github.com") {
            return remoteURL.replacingOccurrences(of: ".git", with: "")
        }

        return remoteURL.replacingOccurrences(of: ".git", with: "")
    }
}
