import Foundation

struct GitHubStats: Sendable {
    var stars: Int = 0
    var forks: Int = 0
    var openIssues: Int = 0
    var watchers: Int = 0
}

struct ProjectGitMetrics: Hashable, Sendable {
    var commits7d: Int = 0
    var commits30d: Int = 0
    var linesAdded7d: Int = 0
    var linesRemoved7d: Int = 0
    var linesAdded30d: Int = 0
    var linesRemoved30d: Int = 0
    var recentCommits: [Commit] = []
}

enum ProjectStatus: String, CaseIterable {
    case active = "Active"
    case inProgress = "In Progress"
    case dormant = "Dormant"
    case paused = "Paused"
    case experimental = "Experimental"
    case archived = "Archived"
    case abandoned = "Abandoned"

    var color: String {
        switch self {
        case .active: return "green"
        case .inProgress: return "yellow"
        case .dormant: return "gray"
        case .paused: return "yellow"
        case .experimental: return "blue"
        case .archived: return "gray"
        case .abandoned: return "gray"
        }
    }

    var emoji: String {
        switch self {
        case .active: return "🟢"
        case .inProgress: return "🟡"
        case .dormant: return "⚪"
        case .paused: return "🟡"
        case .experimental: return "🔵"
        case .archived: return "⚫"
        case .abandoned: return "⚫"
        }
    }

    /// Whether this status should count toward aggregate totals
    var countsTowardTotals: Bool {
        switch self {
        case .archived, .abandoned:
            return false
        default:
            return true
        }
    }

    /// Create from JSON status string
    static func from(jsonStatus: String) -> ProjectStatus {
        switch jsonStatus.lowercased() {
        case "active": return .active
        case "paused": return .paused
        case "experimental": return .experimental
        case "archived": return .archived
        case "abandoned": return .abandoned
        default: return .dormant
        }
    }
}

struct Project: Identifiable, Hashable, Sendable {
    let id: UUID
    let path: URL
    let name: String
    var description: String?
    var githubURL: String?
    var language: String?
    var lineCount: Int
    var fileCount: Int
    var promptCount: Int
    var workLogCount: Int
    var lastCommit: Commit?
    var lastScanned: Date
    var githubStats: GitHubStats?
    var githubStatsError: String?
    var gitMetrics: ProjectGitMetrics?
    var gitRepoInfo: GitRepoInfo?

    // New fields from projectstats.json
    var jsonStatus: String?
    var techStack: [String]
    var languageBreakdown: [String: Int]
    var structure: String?
    var structureNotes: String?
    var sourceDirectories: [String]
    var excludedDirectories: [String]
    var firstCommitDate: Date?
    var totalCommits: Int?
    var branches: [String]
    var currentBranch: String?
    var statsGeneratedAt: Date?
    var statsSource: String?

    var status: ProjectStatus {
        // If we have a JSON status, use it
        if let jsonStatus = jsonStatus {
            return ProjectStatus.from(jsonStatus: jsonStatus)
        }
        // Otherwise fall back to commit-based calculation
        guard let lastCommitDate = lastCommit?.date else { return .dormant }
        let daysSince = Calendar.current.dateComponents([.day], from: lastCommitDate, to: Date()).day ?? 0
        if daysSince <= 7 { return .active }
        if daysSince <= 30 { return .inProgress }
        return .dormant
    }

    /// Whether this project should count toward aggregate totals
    var countsTowardTotals: Bool {
        status.countsTowardTotals
    }

    var formattedLineCount: String {
        if lineCount >= 1000 {
            return String(format: "%.1fk", Double(lineCount) / 1000.0)
        }
        return "\(lineCount)"
    }

    var lastActivityString: String {
        lastCommit?.date.relativeString ?? "Never"
    }

    init(
        id: UUID = UUID(),
        path: URL,
        name: String? = nil,
        description: String? = nil,
        githubURL: String? = nil,
        language: String? = nil,
        lineCount: Int = 0,
        fileCount: Int = 0,
        promptCount: Int = 0,
        workLogCount: Int = 0,
        lastCommit: Commit? = nil,
        lastScanned: Date = Date(),
        githubStats: GitHubStats? = nil,
        githubStatsError: String? = nil,
        gitMetrics: ProjectGitMetrics? = nil,
        gitRepoInfo: GitRepoInfo? = nil,
        jsonStatus: String? = nil,
        techStack: [String] = [],
        languageBreakdown: [String: Int] = [:],
        structure: String? = nil,
        structureNotes: String? = nil,
        sourceDirectories: [String] = [],
        excludedDirectories: [String] = [],
        firstCommitDate: Date? = nil,
        totalCommits: Int? = nil,
        branches: [String] = [],
        currentBranch: String? = nil,
        statsGeneratedAt: Date? = nil,
        statsSource: String? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name ?? path.lastPathComponent
        self.description = description
        self.githubURL = githubURL
        self.language = language
        self.lineCount = lineCount
        self.fileCount = fileCount
        self.promptCount = promptCount
        self.workLogCount = workLogCount
        self.lastCommit = lastCommit
        self.lastScanned = lastScanned
        self.githubStats = githubStats
        self.githubStatsError = githubStatsError
        self.gitMetrics = gitMetrics
        self.gitRepoInfo = gitRepoInfo
        self.jsonStatus = jsonStatus
        self.techStack = techStack
        self.languageBreakdown = languageBreakdown
        self.structure = structure
        self.structureNotes = structureNotes
        self.sourceDirectories = sourceDirectories
        self.excludedDirectories = excludedDirectories
        self.firstCommitDate = firstCommitDate
        self.totalCommits = totalCommits
        self.branches = branches
        self.currentBranch = currentBranch
        self.statsGeneratedAt = statsGeneratedAt
        self.statsSource = statsSource
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}
