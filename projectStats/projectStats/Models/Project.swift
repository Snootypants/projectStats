import Foundation

struct GitHubStats {
    var stars: Int = 0
    var forks: Int = 0
    var openIssues: Int = 0
    var watchers: Int = 0
}

enum ProjectStatus: String, CaseIterable {
    case active = "Active"
    case inProgress = "In Progress"
    case dormant = "Dormant"

    var color: String {
        switch self {
        case .active: return "green"
        case .inProgress: return "yellow"
        case .dormant: return "gray"
        }
    }

    var emoji: String {
        switch self {
        case .active: return "🟢"
        case .inProgress: return "🟡"
        case .dormant: return "⚪"
        }
    }
}

struct Project: Identifiable, Hashable {
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

    var status: ProjectStatus {
        guard let lastCommitDate = lastCommit?.date else { return .dormant }
        let daysSince = Calendar.current.dateComponents([.day], from: lastCommitDate, to: Date()).day ?? 0
        if daysSince <= 7 { return .active }
        if daysSince <= 30 { return .inProgress }
        return .dormant
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
        githubStatsError: String? = nil
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
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}
