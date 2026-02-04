import Foundation
import SwiftData

@Model
class CachedProject {
    var path: String
    var name: String
    var descriptionText: String?
    var githubURL: String?
    var language: String?
    var lineCount: Int
    var fileCount: Int
    var promptCount: Int
    var workLogCount: Int
    var lastCommitHash: String?
    var lastCommitMessage: String?
    var lastCommitAuthor: String?
    var lastCommitDate: Date?
    var lastScanned: Date

    // New fields from projectstats.json
    var jsonStatus: String?              // "active", "paused", "archived", "abandoned", "experimental"
    var techStackData: Data?             // JSON-encoded [String]
    var languageBreakdownData: Data?     // JSON-encoded [String: Int]
    var structure: String?               // "standard", "monorepo", "multi-version", "fullstack", "workspace"
    var structureNotes: String?
    var sourceDirectoriesData: Data?     // JSON-encoded [String]
    var excludedDirectoriesData: Data?   // JSON-encoded [String]
    var firstCommitDate: Date?
    var totalCommits: Int?
    var branchesData: Data?              // JSON-encoded [String]
    var currentBranch: String?
    var statsGeneratedAt: Date?
    var statsSource: String?             // "json" or "scanner"
    var isArchived: Bool = false         // User-set archive status
    var archivedAt: Date?

    // Computed properties for array access
    var techStack: [String] {
        get {
            guard let data = techStackData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            techStackData = try? JSONEncoder().encode(newValue)
        }
    }

    var languageBreakdown: [String: Int] {
        get {
            guard let data = languageBreakdownData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            languageBreakdownData = try? JSONEncoder().encode(newValue)
        }
    }

    var sourceDirectories: [String] {
        get {
            guard let data = sourceDirectoriesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            sourceDirectoriesData = try? JSONEncoder().encode(newValue)
        }
    }

    var excludedDirectories: [String] {
        get {
            guard let data = excludedDirectoriesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            excludedDirectoriesData = try? JSONEncoder().encode(newValue)
        }
    }

    var branches: [String] {
        get {
            guard let data = branchesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            branchesData = try? JSONEncoder().encode(newValue)
        }
    }

    var status: ProjectStatus {
        // If we have a JSON status, use it
        if let jsonStatus = jsonStatus {
            return ProjectStatus.from(jsonStatus: jsonStatus)
        }
        // Otherwise fall back to commit-based calculation
        guard let lastCommit = lastCommitDate else { return .dormant }
        let daysSince = Calendar.current.dateComponents([.day], from: lastCommit, to: Date()).day ?? 0
        if daysSince <= 7 { return .active }
        if daysSince <= 30 { return .inProgress }
        return .dormant
    }

    var countsTowardTotals: Bool {
        if let jsonStatus = jsonStatus {
            return jsonStatus != "archived" && jsonStatus != "abandoned"
        }
        return true
    }

    init(
        path: String,
        name: String,
        descriptionText: String? = nil,
        githubURL: String? = nil,
        language: String? = nil,
        lineCount: Int = 0,
        fileCount: Int = 0,
        promptCount: Int = 0,
        workLogCount: Int = 0,
        lastCommitHash: String? = nil,
        lastCommitMessage: String? = nil,
        lastCommitAuthor: String? = nil,
        lastCommitDate: Date? = nil,
        lastScanned: Date = Date(),
        jsonStatus: String? = nil,
        techStack: [String]? = nil,
        languageBreakdown: [String: Int]? = nil,
        structure: String? = nil,
        structureNotes: String? = nil,
        sourceDirectories: [String]? = nil,
        excludedDirectories: [String]? = nil,
        firstCommitDate: Date? = nil,
        totalCommits: Int? = nil,
        branches: [String]? = nil,
        currentBranch: String? = nil,
        statsGeneratedAt: Date? = nil,
        statsSource: String? = nil
    ) {
        self.path = path
        self.name = name
        self.descriptionText = descriptionText
        self.githubURL = githubURL
        self.language = language
        self.lineCount = lineCount
        self.fileCount = fileCount
        self.promptCount = promptCount
        self.workLogCount = workLogCount
        self.lastCommitHash = lastCommitHash
        self.lastCommitMessage = lastCommitMessage
        self.lastCommitAuthor = lastCommitAuthor
        self.lastCommitDate = lastCommitDate
        self.lastScanned = lastScanned
        self.jsonStatus = jsonStatus
        self.structure = structure
        self.structureNotes = structureNotes
        self.firstCommitDate = firstCommitDate
        self.totalCommits = totalCommits
        self.currentBranch = currentBranch
        self.statsGeneratedAt = statsGeneratedAt
        self.statsSource = statsSource

        // Encode arrays
        if let techStack = techStack {
            self.techStackData = try? JSONEncoder().encode(techStack)
        }
        if let languageBreakdown = languageBreakdown {
            self.languageBreakdownData = try? JSONEncoder().encode(languageBreakdown)
        }
        if let sourceDirectories = sourceDirectories {
            self.sourceDirectoriesData = try? JSONEncoder().encode(sourceDirectories)
        }
        if let excludedDirectories = excludedDirectories {
            self.excludedDirectoriesData = try? JSONEncoder().encode(excludedDirectories)
        }
        if let branches = branches {
            self.branchesData = try? JSONEncoder().encode(branches)
        }
    }

    func toProject() -> Project {
        // Only require lastCommitDate to build a commit - use sensible defaults for missing fields
        var commit: Commit? = nil
        if let date = lastCommitDate {
            commit = Commit(
                id: lastCommitHash ?? "unknown",
                message: lastCommitMessage ?? "",
                author: lastCommitAuthor ?? "Unknown",
                date: date
            )
        }

        return Project(
            path: URL(fileURLWithPath: path),
            name: name,
            description: descriptionText,
            githubURL: githubURL,
            language: language,
            lineCount: lineCount,
            fileCount: fileCount,
            promptCount: promptCount,
            workLogCount: workLogCount,
            lastCommit: commit,
            lastScanned: lastScanned,
            jsonStatus: jsonStatus,
            techStack: techStack,
            languageBreakdown: languageBreakdown,
            structure: structure,
            structureNotes: structureNotes,
            sourceDirectories: sourceDirectories,
            excludedDirectories: excludedDirectories,
            firstCommitDate: firstCommitDate,
            totalCommits: totalCommits,
            branches: branches,
            currentBranch: currentBranch,
            statsGeneratedAt: statsGeneratedAt,
            statsSource: statsSource
        )
    }

    func update(from project: Project) {
        self.name = project.name
        self.descriptionText = project.description
        self.githubURL = project.githubURL
        self.language = project.language
        self.lineCount = project.lineCount
        self.fileCount = project.fileCount
        self.promptCount = project.promptCount
        self.workLogCount = project.workLogCount
        self.lastCommitHash = project.lastCommit?.id
        self.lastCommitMessage = project.lastCommit?.message
        self.lastCommitAuthor = project.lastCommit?.author
        self.lastCommitDate = project.lastCommit?.date
        self.lastScanned = project.lastScanned
        self.jsonStatus = project.jsonStatus
        self.techStack = project.techStack
        self.languageBreakdown = project.languageBreakdown
        self.structure = project.structure
        self.structureNotes = project.structureNotes
        self.sourceDirectories = project.sourceDirectories
        self.excludedDirectories = project.excludedDirectories
        self.firstCommitDate = project.firstCommitDate
        self.totalCommits = project.totalCommits
        self.branches = project.branches
        self.currentBranch = project.currentBranch
        self.statsGeneratedAt = project.statsGeneratedAt
        self.statsSource = project.statsSource
    }
}

@Model
class CachedDailyActivity {
    var date: Date
    var projectPath: String
    var linesAdded: Int
    var linesRemoved: Int
    var commits: Int

    init(date: Date, projectPath: String, linesAdded: Int = 0, linesRemoved: Int = 0, commits: Int = 0) {
        self.date = date.startOfDay
        self.projectPath = projectPath
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.commits = commits
    }
}

@Model
class CachedPrompt {
    var projectPath: String           // Parent project path (foreign key to CachedProject)
    var promptNumber: Int             // e.g. 1, 2, 3 — parsed from filename "1.md"
    var filename: String              // e.g. "1.md", "2c.md"
    var content: String               // Full markdown content
    var contentHash: String           // SHA256 of content, for change detection
    var fileModified: Date            // File modification date from filesystem
    var cachedAt: Date                // When this was last synced

    init(
        projectPath: String,
        promptNumber: Int,
        filename: String,
        content: String,
        contentHash: String,
        fileModified: Date,
        cachedAt: Date = Date()
    ) {
        self.projectPath = projectPath
        self.promptNumber = promptNumber
        self.filename = filename
        self.content = content
        self.contentHash = contentHash
        self.fileModified = fileModified
        self.cachedAt = cachedAt
    }
}

@Model
class CachedWorkLog {
    var projectPath: String           // Parent project path
    var filename: String              // e.g. "2026-01-30_0122_menubar-and-github-api.md"
    var content: String               // Full markdown content
    var contentHash: String           // SHA256 for change detection
    var fileModified: Date            // File modification date from filesystem
    var cachedAt: Date                // When this was last synced
    var isStatsFile: Bool             // true if from /work/stats/, false if from /work/
    var sourceFile: String?           // Original filename for imported files

    // Parsed fields (from stats files only — nil for regular work logs)
    var started: Date?
    var ended: Date?
    var linesAdded: Int?
    var linesDeleted: Int?
    var commitHash: String?
    var summary: String?              // The description text after the YAML-like header

    init(
        projectPath: String,
        filename: String,
        content: String,
        contentHash: String = "",
        fileModified: Date = Date(),
        cachedAt: Date = Date(),
        isStatsFile: Bool = false,
        started: Date? = nil,
        ended: Date? = nil,
        linesAdded: Int? = nil,
        linesDeleted: Int? = nil,
        commitHash: String? = nil,
        summary: String? = nil,
        sourceFile: String? = nil
    ) {
        self.projectPath = projectPath
        self.filename = filename
        self.content = content
        self.contentHash = contentHash
        self.fileModified = fileModified
        self.cachedAt = cachedAt
        self.isStatsFile = isStatsFile
        self.started = started
        self.ended = ended
        self.linesAdded = linesAdded
        self.linesDeleted = linesDeleted
        self.commitHash = commitHash
        self.summary = summary
        self.sourceFile = sourceFile
    }
}

@Model
class CachedCommit {
    var projectPath: String
    var commitHash: String?
    var shortHash: String
    var message: String
    var author: String
    var authorEmail: String?
    var date: Date
    var linesAdded: Int
    var linesDeleted: Int
    var filesChanged: Int

    init(
        projectPath: String,
        commitHash: String? = nil,
        shortHash: String,
        message: String,
        author: String,
        authorEmail: String? = nil,
        date: Date,
        linesAdded: Int = 0,
        linesDeleted: Int = 0,
        filesChanged: Int = 0
    ) {
        self.projectPath = projectPath
        self.commitHash = commitHash
        self.shortHash = shortHash
        self.message = message
        self.author = author
        self.authorEmail = authorEmail
        self.date = date
        self.linesAdded = linesAdded
        self.linesDeleted = linesDeleted
        self.filesChanged = filesChanged
    }
}
