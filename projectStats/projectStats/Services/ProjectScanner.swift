import Foundation

class ProjectScanner: ObservableObject {
    static let shared = ProjectScanner()

    @Published var projects: [Project] = []
    @Published var isScanning = false

    private let fileManager = FileManager.default
    private let gitService = GitService.shared
    private let gitRepoService = GitRepoService.shared

    private init() {}

    func scan(directory: URL) async -> [Project] {
        await MainActor.run { isScanning = true }
        defer {
            Task { @MainActor in isScanning = false }
        }

        var discoveredProjects: [Project] = []

        let contents = fileManager.directoryContents(at: directory)

        for url in contents {
            guard fileManager.isDirectory(at: url) else { continue }

            // Skip hidden directories
            if url.lastPathComponent.hasPrefix(".") { continue }

            // Check if this is a project
            if isProject(url) {
                if let project = await scanProject(at: url) {
                    discoveredProjects.append(project)
                }
            } else {
                // Recursively check subdirectories (for organization folders like ~/Code/work/)
                let subContents = fileManager.directoryContents(at: url)
                for subURL in subContents {
                    guard fileManager.isDirectory(at: subURL) else { continue }
                    if subURL.lastPathComponent.hasPrefix(".") { continue }

                    if isProject(subURL) {
                        if let project = await scanProject(at: subURL) {
                            discoveredProjects.append(project)
                        }
                    }
                }
            }
        }

        // Sort by last activity
        discoveredProjects.sort { (p1, p2) -> Bool in
            let date1 = p1.lastCommit?.date ?? .distantPast
            let date2 = p2.lastCommit?.date ?? .distantPast
            return date1 > date2
        }

        await MainActor.run {
            self.projects = discoveredProjects
        }

        return discoveredProjects
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
