import Foundation
import SwiftData

/// Service for managing data migrations and database rebuilds
@MainActor
class DataMigrationService {
    static let shared = DataMigrationService()

    private let currentDataVersion = 3
    private let dataVersionKey = "dataVersion"

    private init() {}

    /// Check if migration is needed and perform it
    func migrateIfNeeded(modelContext: ModelContext) async {
        let storedVersion = UserDefaults.standard.integer(forKey: dataVersionKey)

        if storedVersion < currentDataVersion {
            print("[DataMigration] Migration needed: v\(storedVersion) -> v\(currentDataVersion)")
            await performFullRebuild(modelContext: modelContext)
            UserDefaults.standard.set(currentDataVersion, forKey: dataVersionKey)
            print("[DataMigration] Migration complete")
        }
    }

    /// Force a full rebuild of the database from projectstats.json files
    func performFullRebuild(modelContext: ModelContext) async {
        print("[DataMigration] Starting full database rebuild...")

        // Step 1: Delete all existing records
        await deleteAllRecords(modelContext: modelContext)

        // Step 2: Find all projectstats.json files
        let codeDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code")
        let jsonFiles = findAllProjectStatsJSON(in: codeDirectory)
        print("[DataMigration] Found \(jsonFiles.count) projectstats.json files")

        // Step 3: Create CachedProject records from JSON files
        var projectPaths: [URL] = []
        for jsonURL in jsonFiles {
            let projectDir = jsonURL.deletingLastPathComponent()
            if let project = createCachedProject(from: jsonURL, modelContext: modelContext) {
                modelContext.insert(project)
                projectPaths.append(projectDir)
            }
        }

        // Step 4: Save the projects
        do {
            try modelContext.save()
            print("[DataMigration] Saved \(projectPaths.count) projects")
        } catch {
            print("[DataMigration] Error saving projects: \(error)")
        }

        // Step 5: Rebuild daily activity from git logs
        await rebuildDailyActivity(for: projectPaths, modelContext: modelContext)

        print("[DataMigration] Rebuild complete!")
    }

    /// Delete all CachedProject and CachedDailyActivity records
    private func deleteAllRecords(modelContext: ModelContext) async {
        do {
            // Delete all CachedProject records
            let projectDescriptor = FetchDescriptor<CachedProject>()
            let projects = try modelContext.fetch(projectDescriptor)
            for project in projects {
                modelContext.delete(project)
            }

            // Delete all CachedDailyActivity records
            let activityDescriptor = FetchDescriptor<CachedDailyActivity>()
            let activities = try modelContext.fetch(activityDescriptor)
            for activity in activities {
                modelContext.delete(activity)
            }

            try modelContext.save()
        } catch {
            print("[DataMigration] Error deleting records: \(error)")
        }
    }

    /// Find all projectstats.json files in the code directory
    private func findAllProjectStatsJSON(in directory: URL) -> [URL] {
        var jsonFiles: [URL] = []
        let fileManager = FileManager.default

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

            // Skip excluded directories
            if skipDirs.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            // Check if this is a projectstats.json file
            if name == "projectstats.json" {
                jsonFiles.append(url)
                enumerator.skipDescendants() // Don't descend into this project further
            }
        }

        return jsonFiles
    }

    /// Create a CachedProject from a projectstats.json file
    private func createCachedProject(from jsonURL: URL, modelContext: ModelContext) -> CachedProject? {
        guard let stats = JSONStatsReader.shared.read(from: jsonURL.deletingLastPathComponent()) else {
            return nil
        }

        let projectDir = jsonURL.deletingLastPathComponent()

        // Parse dates
        let firstCommitDate = JSONStatsReader.parseDate(stats.git?.firstCommitDate)
        let statsGeneratedAt = JSONStatsReader.generatedAtDate(from: stats)

        // Get last commit info from JSON
        let lastCommit = JSONStatsReader.lastCommit(from: stats)

        // Get GitHub URL
        let githubURL: String?
        if let gitInfo = stats.git, let remoteUrl = gitInfo.remoteUrl {
            githubURL = convertToWebURL(remoteUrl)
        } else {
            githubURL = nil
        }

        // Count prompts and work folders (not in JSON)
        let promptsDir = projectDir.appendingPathComponent("prompts")
        let promptCount = countFiles(in: promptsDir)

        let workDir = projectDir.appendingPathComponent("work")
        let workLogCount = countFiles(in: workDir)

        let project = CachedProject(
            path: projectDir.path,
            name: stats.name,
            descriptionText: stats.description,
            githubURL: githubURL,
            language: stats.language,
            lineCount: stats.lineCount,
            fileCount: stats.fileCount,
            promptCount: promptCount,
            workLogCount: workLogCount,
            lastCommitHash: lastCommit?.id,
            lastCommitMessage: lastCommit?.message,
            lastCommitAuthor: lastCommit?.author,
            lastCommitDate: lastCommit?.date,
            lastScanned: Date(),
            jsonStatus: stats.status,
            techStack: stats.techStack,
            languageBreakdown: stats.languages,
            structure: stats.structure,
            structureNotes: stats.structureNotes,
            sourceDirectories: stats.sourceDirectories,
            excludedDirectories: stats.excludedDirectories,
            firstCommitDate: firstCommitDate,
            totalCommits: stats.git?.totalCommits,
            branches: stats.git?.branches,
            currentBranch: stats.git?.currentBranch,
            statsGeneratedAt: statsGeneratedAt,
            statsSource: "json"
        )

        return project
    }

    /// Rebuild CachedDailyActivity from git logs for all projects
    private func rebuildDailyActivity(for projectPaths: [URL], modelContext: ModelContext) async {
        let gitService = GitService.shared
        var totalActivities = 0

        for projectPath in projectPaths {
            let activities = gitService.getDailyActivity(at: projectPath, days: 365)

            for (date, stats) in activities {
                let activity = CachedDailyActivity(
                    date: date,
                    projectPath: projectPath.path,
                    linesAdded: stats.linesAdded,
                    linesRemoved: stats.linesRemoved,
                    commits: stats.commits
                )
                modelContext.insert(activity)
                totalActivities += 1
            }
        }

        do {
            try modelContext.save()
            print("[DataMigration] Saved \(totalActivities) daily activity records")
        } catch {
            print("[DataMigration] Error saving activity: \(error)")
        }
    }

    /// Count files in a directory
    private func countFiles(in directory: URL) -> Int {
        guard FileManager.default.fileExists(atPath: directory.path) else { return 0 }

        var count = 0
        if let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if !FileManager.default.isDirectory(at: fileURL) {
                    count += 1
                }
            }
        }
        return count
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
}
