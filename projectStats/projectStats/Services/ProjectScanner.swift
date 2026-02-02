import Foundation

class ProjectScanner: ObservableObject {
    static let shared = ProjectScanner()

    @Published var projects: [Project] = []
    @Published var isScanning = false

    private let fileManager = FileManager.default
    private let gitService = GitService.shared
    private let gitRepoService = GitRepoService.shared
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

    private func isProject(_ url: URL) -> Bool {
        let hasGit = fileManager.fileExists(atPath: url.appendingPathComponent(".git").path)
        let hasPackageJson = fileManager.fileExists(atPath: url.appendingPathComponent("package.json").path)
        let hasCargoToml = fileManager.fileExists(atPath: url.appendingPathComponent("Cargo.toml").path)
        let hasPyprojectToml = fileManager.fileExists(atPath: url.appendingPathComponent("pyproject.toml").path)
        let hasGoMod = fileManager.fileExists(atPath: url.appendingPathComponent("go.mod").path)
        let hasPodfile = fileManager.fileExists(atPath: url.appendingPathComponent("Podfile").path)
        let hasGemfile = fileManager.fileExists(atPath: url.appendingPathComponent("Gemfile").path)

        // Check for .xcodeproj
        let hasXcodeproj = fileManager.directoryContents(at: url).contains { $0.pathExtension == "xcodeproj" }

        // Check for Package.swift (Swift Package)
        let hasPackageSwift = fileManager.fileExists(atPath: url.appendingPathComponent("Package.swift").path)

        return hasGit || hasPackageJson || hasXcodeproj || hasCargoToml || hasPyprojectToml ||
               hasGoMod || hasPodfile || hasGemfile || hasPackageSwift
    }

    private func scanProject(at url: URL) async -> Project? {
        async let repoInfoTask = gitRepoService.inspect(path: url.path)

        let name = url.lastPathComponent
        let description = ReadmeParser.extractDescription(from: url)
        let language = LineCounter.detectLanguage(in: url)
        let (lines, files) = LineCounter.countLines(in: url)
        let lastCommit = gitService.getLastCommit(at: url)
        let gitMetrics = gitService.getProjectGitMetrics(at: url)

        // Count prompts folder
        let promptsDir = url.appendingPathComponent("prompts")
        let promptCount = countFiles(in: promptsDir)

        // Count work folder
        let workDir = url.appendingPathComponent("work")
        let workLogCount = countFiles(in: workDir)

        let repoInfo = await repoInfoTask
        let githubURL = repoInfo.webRemoteURL

        return Project(
            path: url,
            name: name,
            description: description,
            githubURL: githubURL,
            language: language,
            lineCount: lines,
            fileCount: files,
            promptCount: promptCount,
            workLogCount: workLogCount,
            lastCommit: lastCommit,
            lastScanned: Date(),
            gitMetrics: gitMetrics,
            gitRepoInfo: repoInfo
        )
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

    func refreshProject(_ project: Project) async -> Project? {
        return await scanProject(at: project.path)
    }
}

private actor RepoDiscoveryService {
    private let fileManager = FileManager.default
    private let gitService = GitService.shared
    private let gitRepoService = GitRepoService.shared
    private let jsonStatsReader = JSONStatsReader.shared
    private let skipDirectories: Set<String> = [
        "node_modules",
        "DerivedData",
        ".build",
        ".swiftpm",
        "Pods",
        ".venv",
        "dist",
        "build",
        ".next",
        ".turbo",
        ".git"
    ]

    func discoverProjects(root: URL, maxDepth: Int, existingProjects: [Project]) async -> [Project] {
        let candidates = discoverCandidateRoots(root: root, maxDepth: maxDepth)
        let repoRoots = await validateRepoRoots(candidates)

        let existingByPath = Dictionary(uniqueKeysWithValues: existingProjects.map { ($0.path.path, $0) })
        var results: [Project] = []
        var seenPaths = Set<String>()

        for repoRoot in repoRoots {
            let rootURL = URL(fileURLWithPath: repoRoot)
            let existing = existingByPath[repoRoot]

            if let project = await buildProject(at: rootURL, existing: existing) {
                results.append(project)
                seenPaths.insert(repoRoot)
            }
        }

        // Note: We no longer preserve stale projects that weren't found in the scan.
        // Only JSON-sourced projects are included.

        results.sort { (p1, p2) -> Bool in
            let date1 = p1.lastCommit?.date ?? .distantPast
            let date2 = p2.lastCommit?.date ?? .distantPast
            if date1 != date2 {
                return date1 > date2
            }
            // Secondary sort by name for projects with the same date
            return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
        }

        return results
    }

    private func discoverCandidateRoots(root: URL, maxDepth: Int) -> [URL] {
        var candidates: [URL] = []
        let rootComponentsCount = root.standardizedFileURL.pathComponents.count
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return candidates
        }

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(resourceKeys))
            guard values?.isDirectory == true else { continue }

            let depth = url.standardizedFileURL.pathComponents.count - rootComponentsCount
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            let name = url.lastPathComponent
            if name == ".git" {
                candidates.append(url.deletingLastPathComponent())
                enumerator.skipDescendants()
                continue
            }

            if skipDirectories.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            if depth == maxDepth {
                enumerator.skipDescendants()
            }
        }

        return candidates
    }

    private func validateRepoRoots(_ candidates: [URL]) async -> [String] {
        var roots = Set<String>()

        for candidate in candidates {
            let result = await runGit(
                args: ["-C", candidate.path, "rev-parse", "--show-toplevel"],
                workingDir: candidate.path
            )
            guard result.code == 0, !result.stdout.isEmpty else { continue }

            let resolved = URL(fileURLWithPath: result.stdout).standardizedFileURL.path
            roots.insert(resolved)
        }

        return Array(roots)
    }

    private func buildProject(at url: URL, existing: Project?) async -> Project? {
        let projectId = existing?.id ?? UUID()

        // Check for projectstats.json first (primary data source)
        if let jsonStats = jsonStatsReader.read(from: url) {
            // Check if we already have cached data with the same generatedAt timestamp
            if let existingGeneratedAt = existing?.statsGeneratedAt,
               let jsonGeneratedAt = JSONStatsReader.generatedAtDate(from: jsonStats),
               existingGeneratedAt == jsonGeneratedAt {
                // Cache is current, return existing project with preserved runtime data
                var project = existing!
                project.githubStats = existing?.githubStats
                project.githubStatsError = existing?.githubStatsError
                return project
            }

            // Build project from JSON data
            return await buildProjectFromJSON(jsonStats, at: url, id: projectId, existing: existing)
        }

        // No projectstats.json — skip this repo entirely
        // It was intentionally excluded from the audit
        return nil
    }

    /// Build a Project from projectstats.json data
    private func buildProjectFromJSON(_ stats: ProjectStatsJSON, at url: URL, id: UUID, existing: Project?) async -> Project {
        // Get git repo info for additional runtime data (we still need this for some features)
        let repoInfo = await gitRepoService.inspect(path: url.path)

        // Use JSON git info for github URL, fall back to repo inspection
        let githubURL: String?
        if let gitInfo = stats.git, let remoteUrl = gitInfo.remoteUrl {
            // Convert git remote URL to web URL if needed
            githubURL = convertToWebURL(remoteUrl)
        } else {
            githubURL = repoInfo.webRemoteURL
        }

        // Parse dates from JSON
        let firstCommitDate = JSONStatsReader.parseDate(stats.git?.firstCommitDate)
        let statsGeneratedAt = JSONStatsReader.generatedAtDate(from: stats)

        // Build last commit from JSON if available, otherwise use git service
        let lastCommit: Commit?
        if let jsonCommit = JSONStatsReader.lastCommit(from: stats) {
            lastCommit = jsonCommit
        } else {
            lastCommit = gitService.getLastCommit(at: url)
        }

        // Get git metrics for activity tracking (still need this for dashboard)
        let gitMetrics = gitService.getProjectGitMetrics(at: url)

        // Count prompts and work folders (not in JSON)
        let promptsDir = url.appendingPathComponent("prompts")
        let promptCount = countFiles(in: promptsDir)

        let workDir = url.appendingPathComponent("work")
        let workLogCount = countFiles(in: workDir)

        var project = Project(
            id: id,
            path: url,
            name: stats.name,
            description: stats.description,
            githubURL: githubURL,
            language: stats.language,
            lineCount: stats.lineCount,
            fileCount: stats.fileCount,
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

    /// Build a Project using the original scanner-based approach (fallback)
    private func buildProjectFromScanner(at url: URL, id: UUID, existing: Project?) async -> Project {
        let name = url.lastPathComponent
        let repoInfo = await gitRepoService.inspect(path: url.path)
        let githubURL = repoInfo.webRemoteURL

        let description = ReadmeParser.extractDescription(from: url)
        let language = LineCounter.detectLanguage(in: url)
        let (lines, files) = LineCounter.countLines(in: url)
        let lastCommit = gitService.getLastCommit(at: url)
        let gitMetrics = gitService.getProjectGitMetrics(at: url)

        let promptsDir = url.appendingPathComponent("prompts")
        let promptCount = countFiles(in: promptsDir)

        let workDir = url.appendingPathComponent("work")
        let workLogCount = countFiles(in: workDir)

        var project = Project(
            id: id,
            path: url,
            name: name,
            description: description,
            githubURL: githubURL,
            language: language,
            lineCount: lines,
            fileCount: files,
            promptCount: promptCount,
            workLogCount: workLogCount,
            lastCommit: lastCommit,
            lastScanned: Date(),
            gitMetrics: gitMetrics,
            gitRepoInfo: repoInfo,
            statsSource: "scanner"
        )

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
            url = url.replacingOccurrences(of: ":", with: "/", options: [], range: url.range(of: ":")!)
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

    private func runGit(args: [String], workingDir: String) async -> (stdout: String, stderr: String, code: Int) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = URL(fileURLWithPath: workingDir)

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    continuation.resume(returning: ("", error.localizedDescription, 1))
                    return
                }

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                continuation.resume(returning: (stdout, stderr, Int(process.terminationStatus)))
            }
        }
    }
}
