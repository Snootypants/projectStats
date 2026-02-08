import Foundation

final class BranchService {
    static let shared = BranchService()
    private init() {}

    struct BranchResult {
        let originalPath: URL
        let branchPath: URL
        let branchName: String
    }

    /// Creates a local branch by copying the project folder
    /// Returns the path to the new branch folder
    func createLocalBranch(from projectPath: URL, branchName: String) async throws -> BranchResult {
        let sanitizedBranchName = sanitizeBranchName(branchName)
        let projectName = projectPath.lastPathComponent
        let branchFolderName = "\(projectName)-\(sanitizedBranchName)"

        // Create branch folder next to original
        let parentDir = projectPath.deletingLastPathComponent()
        let branchPath = parentDir.appendingPathComponent(branchFolderName)

        // Check if already exists
        if FileManager.default.fileExists(atPath: branchPath.path) {
            throw BranchError.alreadyExists(branchFolderName)
        }

        // Copy the folder (excluding some large dirs for speed)
        try await copyProject(from: projectPath, to: branchPath)

        // Create git branch in the copy
        try await createGitBranch(at: branchPath, name: sanitizedBranchName)

        return BranchResult(
            originalPath: projectPath,
            branchPath: branchPath,
            branchName: sanitizedBranchName
        )
    }

    private func copyProject(from source: URL, to destination: URL) async throws {
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let r = Shell.runResult(
                    "rsync -a" +
                    " --exclude node_modules" +
                    " --exclude .build" +
                    " --exclude build" +
                    " --exclude DerivedData" +
                    " --exclude .swiftpm/xcode" +
                    " '\(source.path)/' '\(destination.path)'"
                )
                continuation.resume(returning: r)
            }
        }
        guard result.exitCode == 0 else { throw BranchError.copyFailed }
    }

    private func createGitBranch(at path: URL, name: String) async throws {
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let r = Shell.runResult("git -C '\(path.path)' checkout -b '\(name)'")
                continuation.resume(returning: r)
            }
        }
        guard result.exitCode == 0 else { throw BranchError.gitBranchFailed }
    }

    func sanitizeBranchName(_ name: String) -> String {
        // Git branch name rules: no spaces, no special chars except - and _
        var sanitized = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")

        // Remove invalid characters
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        sanitized = sanitized.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()

        // Ensure doesn't start with dash
        while sanitized.hasPrefix("-") {
            sanitized = String(sanitized.dropFirst())
        }

        return sanitized.isEmpty ? "branch" : sanitized
    }

    /// Lists all local branch folders for a project
    func listLocalBranches(for projectPath: URL) -> [URL] {
        let projectName = projectPath.lastPathComponent
        let parentDir = projectPath.deletingLastPathComponent()

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: parentDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        return contents.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("\(projectName)-") && name != projectName
        }
    }

    /// Deletes a local branch folder
    func deleteLocalBranch(at path: URL) throws {
        try FileManager.default.removeItem(at: path)
    }

    enum BranchError: LocalizedError {
        case alreadyExists(String)
        case copyFailed
        case gitBranchFailed

        var errorDescription: String? {
            switch self {
            case .alreadyExists(let name): return "Branch folder '\(name)' already exists"
            case .copyFailed: return "Failed to copy project folder"
            case .gitBranchFailed: return "Failed to create git branch"
            }
        }
    }
}
