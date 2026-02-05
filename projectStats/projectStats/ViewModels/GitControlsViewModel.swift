import AppKit
import Foundation
import SwiftUI

struct GitFileChange: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let status: String
    let isStaged: Bool
    let isUntracked: Bool
}

struct GitStatusSummary: Hashable {
    let changes: [GitFileChange]
    let stagedCount: Int
    let unstagedCount: Int
    let untrackedCount: Int

    static let empty = GitStatusSummary(changes: [], stagedCount: 0, unstagedCount: 0, untrackedCount: 0)

    var totalCount: Int { stagedCount + unstagedCount + untrackedCount }
}

@MainActor
final class GitControlsViewModel: ObservableObject {
    @Published var status: GitStatusSummary = .empty
    @Published var branches: [String] = []
    @Published var currentBranch: String = ""
    @Published var aheadCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isGitRepository: Bool = false

    let projectPath: URL

    init(projectPath: URL) {
        self.projectPath = projectPath
        // Check if this is a git repository before running git commands
        self.isGitRepository = GitService.shared.isGitRepository(at: projectPath)
        if isGitRepository {
            Task { await refresh() }
        }
    }

    func refresh() async {
        // Skip git operations for non-git projects
        guard isGitRepository else {
            status = .empty
            branches = []
            currentBranch = ""
            aheadCount = 0
            return
        }

        isLoading = true
        defer { isLoading = false }

        async let statusTask = fetchStatus()
        async let branchTask = fetchBranches()
        async let aheadTask = fetchAheadCount()

        let (statusResult, branchResult, aheadResult) = await (statusTask, branchTask, aheadTask)
        status = statusResult
        branches = branchResult
        aheadCount = aheadResult
        currentBranch = branchResult.first ?? ""
        if errorMessage != nil {
            errorMessage = nil
        }
    }

    func commit(message: String, files: [String], pushAfter: Bool) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Commit message required"
            return
        }

        if files.isEmpty {
            errorMessage = "No files selected"
            return
        }

        _ = await runGit("git add -- \(files.map { "'\($0)'" }.joined(separator: " "))")
        let commitResult = await runGit("git commit -m \"\(trimmed.replacingOccurrences(of: "\"", with: "\\\""))\"")

        if commitResult.exitCode != 0 {
            errorMessage = commitResult.error.isEmpty ? "Commit failed" : commitResult.error
            return
        }

        if pushAfter {
            _ = await push()
        }

        await refresh()
    }

    func push() async -> Shell.Result {
        let result = await runGit("git push")
        if result.exitCode != 0 {
            errorMessage = result.error.isEmpty ? "Push failed" : result.error
        }
        await refresh()
        return result
    }

    func pull() async {
        let result = await runGit("git pull")
        if result.exitCode != 0 {
            errorMessage = result.error.isEmpty ? "Pull failed" : result.error
        }
        await refresh()
    }

    func createBranch(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let result = await runGit("git switch -c \(trimmed)")
        if result.exitCode != 0 {
            errorMessage = result.error.isEmpty ? "Failed to create branch" : result.error
        }
        await refresh()
    }

    func switchBranch(name: String) async {
        let result = await runGit("git switch \(name)")
        if result.exitCode != 0 {
            errorMessage = result.error.isEmpty ? "Failed to switch branch" : result.error
        }
        await refresh()
    }

    func stash() async {
        _ = await runGit("git stash push -u")
        await refresh()
    }

    func stashPop() async {
        _ = await runGit("git stash pop")
        await refresh()
    }

    func createPullRequest() {
        guard let url = GitService.shared.getGitHubURL(at: projectPath), !currentBranch.isEmpty else { return }
        if let prURL = URL(string: "\(url)/compare/\(currentBranch)?expand=1") {
            NSWorkspace.shared.open(prURL)
        }
    }

    private func fetchStatus() async -> GitStatusSummary {
        let result = await runGit("git status --porcelain")
        guard result.exitCode == 0 else { return .empty }
        return parseStatus(result.output)
    }

    private func fetchBranches() async -> [String] {
        let result = await runGit("git branch --list")
        guard result.exitCode == 0 else { return [] }
        let lines = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var branchNames: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("*") {
                let name = trimmed.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
                branchNames.insert(name, at: 0)
            } else {
                branchNames.append(trimmed)
            }
        }
        return branchNames
    }

    private func fetchAheadCount() async -> Int {
        let result = await runGit("git rev-list --count @{u}..HEAD")
        guard result.exitCode == 0 else { return 0 }
        return Int(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func parseStatus(_ output: String) -> GitStatusSummary {
        if output.isEmpty { return .empty }

        var changes: [GitFileChange] = []
        var staged = 0
        var unstaged = 0
        var untracked = 0

        for line in output.components(separatedBy: .newlines) {
            guard line.count >= 2 else { continue }
            let statusIndex = line.index(line.startIndex, offsetBy: 0)
            let worktreeIndex = line.index(line.startIndex, offsetBy: 1)
            let statusChar = line[statusIndex]
            let worktreeChar = line[worktreeIndex]

            let pathStart = line.index(line.startIndex, offsetBy: 3)
            let rawPath = String(line[pathStart...]).trimmingCharacters(in: .whitespaces)
            let path = rawPath.components(separatedBy: " -> ").last ?? rawPath

            let isUntracked = statusChar == "?"
            let isStaged = statusChar != " " && !isUntracked
            let isUnstaged = worktreeChar != " " && !isUntracked

            if isUntracked { untracked += 1 }
            if isStaged { staged += 1 }
            if isUnstaged { unstaged += 1 }

            let statusLabel = isUntracked ? "?" : String(statusChar != " " ? statusChar : worktreeChar)
            changes.append(GitFileChange(path: path, status: statusLabel, isStaged: isStaged, isUntracked: isUntracked))
        }

        return GitStatusSummary(changes: changes, stagedCount: staged, unstagedCount: unstaged, untrackedCount: untracked)
    }

    private func runGit(_ command: String) async -> Shell.Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Shell.runResult(command, at: self.projectPath)
                continuation.resume(returning: result)
            }
        }
    }
}
