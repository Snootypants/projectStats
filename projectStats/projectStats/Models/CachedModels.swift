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

    var status: ProjectStatus {
        guard let lastCommit = lastCommitDate else { return .dormant }
        let daysSince = Calendar.current.dateComponents([.day], from: lastCommit, to: Date()).day ?? 0
        if daysSince <= 7 { return .active }
        if daysSince <= 30 { return .inProgress }
        return .dormant
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
        lastScanned: Date = Date()
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
    }

    func toProject() -> Project {
        var commit: Commit? = nil
        if let hash = lastCommitHash, let message = lastCommitMessage, let author = lastCommitAuthor, let date = lastCommitDate {
            commit = Commit(id: hash, message: message, author: author, date: date)
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
            lastScanned: lastScanned
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
