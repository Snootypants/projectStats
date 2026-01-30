import Foundation

class GitService {
    static let shared = GitService()

    private init() {}

    func isGitRepository(at path: URL) -> Bool {
        let gitPath = path.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitPath.path)
    }

    func getRemoteURL(at path: URL) -> String? {
        let result = Shell.run("git config --get remote.origin.url", at: path)
        return result.isEmpty ? nil : result
    }

    func getGitHubURL(at path: URL) -> String? {
        guard let remoteURL = getRemoteURL(at: path) else { return nil }

        // Convert SSH to HTTPS
        // git@github.com:user/repo.git -> https://github.com/user/repo
        if remoteURL.hasPrefix("git@github.com:") {
            let repoPath = remoteURL
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: ".git", with: "")
            return "https://github.com/\(repoPath)"
        }

        // Already HTTPS
        if remoteURL.hasPrefix("https://github.com") {
            return remoteURL.replacingOccurrences(of: ".git", with: "")
        }

        // Other git hosts - just clean up .git
        return remoteURL.replacingOccurrences(of: ".git", with: "")
    }

    func getLastCommit(at path: URL) -> Commit? {
        let result = Shell.run("git log -1 --format=\"%H|%s|%an|%ai\"", at: path)
        guard !result.isEmpty else { return nil }
        return Commit.fromGitLog(result)
    }

    func getCommitCount(at path: URL, since: Date? = nil) -> Int {
        var command = "git rev-list --count HEAD"
        if let since = since {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            command = "git rev-list --count --since=\"\(formatter.string(from: since))\" HEAD"
        }

        let result = Shell.run(command, at: path)
        return Int(result) ?? 0
    }

    func getCommitHistory(at path: URL, limit: Int = 50) -> [Commit] {
        let result = Shell.run("git log -n \(limit) --format=\"%H|%s|%an|%ai\"", at: path)
        guard !result.isEmpty else { return [] }

        return result.components(separatedBy: .newlines).compactMap { Commit.fromGitLog($0) }
    }

    func getLinesChanged(at path: URL, since: Date? = nil) -> (added: Int, removed: Int) {
        var command = "git log --numstat --format=\"\""

        if let since = since {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            command += " --since=\"\(formatter.string(from: since))\""
        }

        let result = Shell.run(command, at: path)
        guard !result.isEmpty else { return (0, 0) }

        var totalAdded = 0
        var totalRemoved = 0

        for line in result.components(separatedBy: .newlines) {
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }

            // Skip binary files (marked with -)
            guard let added = Int(parts[0]), let removed = Int(parts[1]) else { continue }

            totalAdded += added
            totalRemoved += removed
        }

        return (totalAdded, totalRemoved)
    }

    func getDailyActivity(at path: URL, days: Int = 365) -> [Date: ActivityStats] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let sinceDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let command = "git log --since=\"\(formatter.string(from: sinceDate))\" --format=\"%ai\" --numstat"
        let result = Shell.run(command, at: path)
        guard !result.isEmpty else { return [:] }

        var activities: [Date: ActivityStats] = [:]
        var currentDate: Date?

        for line in result.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Check if it's a date line
            if let date = Date.fromGitDate(trimmed) {
                currentDate = date.startOfDay
                if activities[currentDate!] == nil {
                    activities[currentDate!] = ActivityStats(date: currentDate!, projectPaths: [path.path])
                }
                activities[currentDate!]?.commits += 1
                continue
            }

            // It's a numstat line
            guard let date = currentDate else { continue }
            let parts = trimmed.split(separator: "\t")
            guard parts.count >= 2 else { continue }

            if let added = Int(parts[0]), let removed = Int(parts[1]) {
                activities[date]?.linesAdded += added
                activities[date]?.linesRemoved += removed
            }
        }

        return activities
    }

    func getCurrentBranch(at path: URL) -> String? {
        let result = Shell.run("git branch --show-current", at: path)
        return result.isEmpty ? nil : result
    }

    func hasUncommittedChanges(at path: URL) -> Bool {
        let result = Shell.run("git status --porcelain", at: path)
        return !result.isEmpty
    }

    func getFileChanges(at path: URL) -> (staged: Int, unstaged: Int, untracked: Int) {
        let result = Shell.run("git status --porcelain", at: path)
        guard !result.isEmpty else { return (0, 0, 0) }

        var staged = 0
        var unstaged = 0
        var untracked = 0

        for line in result.components(separatedBy: .newlines) {
            guard line.count >= 2 else { continue }
            let index = line.index(line.startIndex, offsetBy: 0)
            let worktree = line.index(line.startIndex, offsetBy: 1)

            if line[index] == "?" {
                untracked += 1
            } else {
                if line[index] != " " { staged += 1 }
                if line[worktree] != " " { unstaged += 1 }
            }
        }

        return (staged, unstaged, untracked)
    }
}
