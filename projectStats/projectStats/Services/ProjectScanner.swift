import Foundation

class ProjectScanner: ObservableObject {
    static let shared = ProjectScanner()

    @Published var projects: [Project] = []
    @Published var isScanning = false

    private let repoDiscovery = RepoDiscoveryService()

    private init() {}

    func scan(directory: URL, maxDepth: Int = 10, existingProjects: [Project] = []) async -> [Project] {
        await MainActor.run { isScanning = true }
        defer {
            Task { @MainActor in isScanning = false }
        }

        let result = await repoDiscovery.discoverProjects(
            root: directory,
            maxDepth: maxDepth,
            existingProjects: existingProjects
        )
        await MainActor.run {
            self.projects = result
        }

        return result
    }

}

private actor RepoDiscoveryService {
    private let fileManager = FileManager.default
    private let gitService = GitService.shared
    private let gitRepoService = GitRepoService.shared
    private let jsonStatsReader = JSONStatsReader.shared

    /// Discover projects by finding projectstats.json files (JSON-first discovery)
    func discoverProjects(root: URL, maxDepth: Int, existingProjects: [Project]) async -> [Project] {
        // Find all projectstats.json files (JSON-first discovery)
        let jsonFiles = findAllProjectStatsJSON(in: root)

        let existingByPath = Dictionary(uniqueKeysWithValues: existingProjects.map { ($0.path.path, $0) })
        var results: [Project] = []

        for jsonURL in jsonFiles {
            let projectDir = jsonURL.deletingLastPathComponent()
            let projectPath = projectDir.standardizedFileURL.path
            let existing = existingByPath[projectPath]
            let projectId = existing?.id ?? UUID()

            guard let jsonStats = jsonStatsReader.read(from: projectDir) else {
                continue
            }

            // Check if cache is current
            if let existingGeneratedAt = existing?.statsGeneratedAt,
               let jsonGeneratedAt = JSONStatsReader.generatedAtDate(from: jsonStats),
               existingGeneratedAt == jsonGeneratedAt {
                var project = existing!
                project.githubStats = existing?.githubStats
                project.githubStatsError = existing?.githubStatsError
                results.append(project)
                continue
            }

            // Build project from JSON, enriched with git data
            let project = await buildProjectFromJSON(jsonStats, at: projectDir, id: projectId, existing: existing)
            results.append(project)
        }

        results.sort { (p1, p2) -> Bool in
            let date1 = p1.lastCommit?.date ?? .distantPast
            let date2 = p2.lastCommit?.date ?? .distantPast
            if date1 != date2 {
                return date1 > date2
            }
            return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
        }

        return results
    }

    /// Find all projectstats.json files in a directory
    private func findAllProjectStatsJSON(in directory: URL) -> [URL] {
        var jsonFiles: [URL] = []

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return jsonFiles
        }

        let skipDirs: Set<String> = [
            "node_modules", "DerivedData", ".build", ".swiftpm", "Pods",
            ".venv", "dist", "build", ".next", ".turbo", ".git", "vendor"
        ]

        for case let url as URL in enumerator {
            let name = url.lastPathComponent

            if skipDirs.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            if name == "projectstats.json" {
                jsonFiles.append(url)
                enumerator.skipDescendants()
            }
        }

        return jsonFiles
    }

    /// Build a Project from projectstats.json data
    private func buildProjectFromJSON(_ stats: ProjectStatsJSON, at url: URL, id: UUID, existing: Project?) async -> Project {
        // Get git repo info for additional runtime data (we still need this for some features)
        let repoInfo = await gitRepoService.inspect(path: url.path)

        // Use JSON git info for github URL, fall back to repo inspection
        let githubURL: String?
        if let gitInfo = stats.git, let remoteUrl = gitInfo.remoteUrl {
            githubURL = convertToWebURL(remoteUrl)
        } else {
            githubURL = repoInfo.webRemoteURL
        }

        // Parse dates from JSON
        let firstCommitDate = JSONStatsReader.parseDate(stats.git?.firstCommitDate)
        let statsGeneratedAt = JSONStatsReader.generatedAtDate(from: stats)

        // Build last commit - prefer live git data if available, fall back to JSON
        let jsonCommit = JSONStatsReader.lastCommit(from: stats)
        let gitCommit = gitService.getLastCommit(at: url)

        let lastCommit: Commit?
        if let gitCommit = gitCommit {
            if let jsonCommit = jsonCommit {
                lastCommit = gitCommit.date >= jsonCommit.date ? gitCommit : jsonCommit
            } else {
                lastCommit = gitCommit
            }
        } else {
            lastCommit = jsonCommit
        }

        // Get git metrics for activity tracking (still need this for dashboard)
        let gitMetrics = gitService.getProjectGitMetrics(at: url)

        // Count prompts and work folders (not in JSON)
        let promptsDir = url.appendingPathComponent("prompts")
        let promptCount = countFiles(in: promptsDir)

        let workDir = url.appendingPathComponent("work")
        let workLogCount = countFiles(in: workDir)

        // Always compute fresh line count from disk (avoid stale JSON cache)
        let (freshLines, freshFiles) = LineCounter.countLines(in: url)

        var project = Project(
            id: id,
            path: url,
            name: stats.name,
            description: stats.description,
            githubURL: githubURL,
            language: stats.language,
            lineCount: freshLines,
            fileCount: freshFiles,
            promptCount: promptCount,
            workLogCount: workLogCount,
            lastCommit: lastCommit,
            lastScanned: Date(),
            gitMetrics: gitMetrics,
            gitRepoInfo: repoInfo,
            jsonStatus: stats.status,
            techStack: stats.techStack,
            languageBreakdown: stats.languages,
            structure: stats.structure,
            structureNotes: stats.structureNotes,
            sourceDirectories: stats.sourceDirectories,
            excludedDirectories: stats.excludedDirectories,
            firstCommitDate: firstCommitDate,
            totalCommits: stats.git?.totalCommits,
            branches: stats.git?.branches ?? [],
            currentBranch: stats.git?.currentBranch,
            statsGeneratedAt: statsGeneratedAt,
            statsSource: "json"
        )

        // Preserve GitHub stats from previous scan
        if let existing = existing {
            project.githubStats = existing.githubStats
            project.githubStatsError = existing.githubStatsError
        }

        return project
    }

    /// Convert a git remote URL to a web URL
    private func convertToWebURL(_ remoteUrl: String) -> String {
        var url = remoteUrl

        // Handle SSH URLs: git@github.com:owner/repo.git -> https://github.com/owner/repo
        if url.hasPrefix("git@") {
            url = url.replacingOccurrences(of: "git@", with: "https://")
            if let colonRange = url.range(of: ":") {
                url = url.replacingCharacters(in: colonRange, with: "/")
            }
        }

        // Remove .git suffix
        if url.hasSuffix(".git") {
            url = String(url.dropLast(4))
        }

        return url
    }

    private func countFiles(in directory: URL) -> Int {
        guard fileManager.fileExists(atPath: directory.path) else { return 0 }

        var count = 0
        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if !fileManager.isDirectory(at: fileURL) {
                    count += 1
                }
            }
        }
        return count
    }
}
