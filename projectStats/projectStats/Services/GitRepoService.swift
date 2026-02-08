import Foundation

actor GitRepoService {
    static let shared = GitRepoService()

    private struct CacheEntry {
        let info: GitRepoInfo
        let timestamp: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 30

    func inspect(path: String) async -> GitRepoInfo {
        let rootResult = await runGit(
            args: ["-C", path, "rev-parse", "--show-toplevel"],
            workingDir: path
        )

        guard rootResult.code == 0, !rootResult.stdout.isEmpty else {
            return GitRepoInfo(
                repoRoot: path,
                branch: nil,
                remoteURL: nil,
                githubOwner: nil,
                githubRepo: nil,
                lastCommitHash: nil,
                lastCommitDateISO: nil,
                lastCommitSubject: nil,
                isGitRepo: false,
                errorMessage: rootResult.stderr.isEmpty ? "Not a Git repo" : rootResult.stderr
            )
        }

        let repoRoot = rootResult.stdout
        if let cached = cachedInfo(for: repoRoot) {
            return cached
        }

        let branchResult = await runGit(
            args: ["-C", repoRoot, "rev-parse", "--abbrev-ref", "HEAD"],
            workingDir: repoRoot
        )
        let branch = sanitizeBranch(branchResult)

        let remoteResult = await runGit(
            args: ["-C", repoRoot, "config", "--get", "remote.origin.url"],
            workingDir: repoRoot
        )
        let remoteURL = remoteResult.code == 0 ? remoteResult.stdout : nil
        let github = parseGitHubRemote(remoteURL)

        let logResult = await runGit(
            args: ["-C", repoRoot, "log", "-1", "--format=%H|%cI|%s"],
            workingDir: repoRoot
        )
        let (hash, dateISO, subject) = parseLastCommit(logResult)

        let info = GitRepoInfo(
            repoRoot: repoRoot,
            branch: branch,
            remoteURL: remoteURL?.isEmpty == true ? nil : remoteURL,
            githubOwner: github?.owner,
            githubRepo: github?.repo,
            lastCommitHash: hash,
            lastCommitDateISO: dateISO,
            lastCommitSubject: subject,
            isGitRepo: true,
            errorMessage: nil
        )

        cache[repoRoot] = CacheEntry(info: info, timestamp: Date())
        return info
    }

    private func runGit(args: [String], workingDir: String) async -> (stdout: String, stderr: String, code: Int) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let escapedArgs = args.map { $0.contains(" ") ? "'\($0)'" : $0 }
                let command = "git " + escapedArgs.joined(separator: " ")
                let result = Shell.runResult(command)
                continuation.resume(returning: (result.output, result.error, result.exitCode))
            }
        }
    }

    private func cachedInfo(for repoRoot: String) -> GitRepoInfo? {
        if let entry = cache[repoRoot],
           Date().timeIntervalSince(entry.timestamp) < cacheTTL {
            return entry.info
        }
        return nil
    }

    private func sanitizeBranch(_ result: (stdout: String, stderr: String, code: Int)) -> String? {
        guard result.code == 0 else { return nil }
        if result.stdout.isEmpty || result.stdout == "HEAD" { return nil }
        return result.stdout
    }

    private func parseGitHubRemote(_ remoteURL: String?) -> (owner: String, repo: String)? {
        guard let remoteURL = remoteURL, !remoteURL.isEmpty else { return nil }

        var path: String?
        if remoteURL.hasPrefix("git@github.com:") {
            path = remoteURL.replacingOccurrences(of: "git@github.com:", with: "")
        } else if remoteURL.hasPrefix("https://github.com/") {
            path = remoteURL.replacingOccurrences(of: "https://github.com/", with: "")
        } else {
            return nil
        }

        guard let cleaned = path?
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/")) else { return nil }

        let parts = cleaned.split(separator: "/")
        guard parts.count >= 2 else { return nil }

        return (String(parts[0]), String(parts[1]))
    }

    private func parseLastCommit(_ result: (stdout: String, stderr: String, code: Int)) -> (String?, String?, String?) {
        guard result.code == 0, !result.stdout.isEmpty else { return (nil, nil, nil) }

        let parts = result.stdout.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return (nil, nil, nil) }

        let hash = String(parts[0])
        let dateISO = String(parts[1])
        let subject = parts[2...].joined(separator: "|")
        return (hash, dateISO, subject)
    }
}
