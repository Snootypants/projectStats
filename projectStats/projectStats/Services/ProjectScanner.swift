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

        for (path, project) in existingByPath where !seenPaths.contains(path) {
            results.append(project)
        }

        results.sort { (p1, p2) -> Bool in
            let date1 = p1.lastCommit?.date ?? .distantPast
            let date2 = p2.lastCommit?.date ?? .distantPast
            return date1 > date2
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
            id: existing?.id ?? UUID(),
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

        if let existing = existing {
            project.githubStats = existing.githubStats
            project.githubStatsError = existing.githubStatsError
        }

        return project
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
