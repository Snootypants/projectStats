import Foundation

/// Represents the structure of a projectstats.json file
struct ProjectStatsJSON: Codable {
    let name: String
    let description: String
    let status: String
    let language: String
    let languages: [String: Int]
    let lineCount: Int
    let fileCount: Int
    let structure: String
    let structureNotes: String?
    let sourceDirectories: [String]
    let excludedDirectories: [String]
    let techStack: [String]
    let git: GitInfo?
    let generatedAt: String
    let generatedBy: String

    struct GitInfo: Codable {
        let remoteUrl: String?
        let currentBranch: String?
        let defaultBranch: String?
        let firstCommitDate: String?
        let lastCommitDate: String?
        let lastCommitMessage: String?
        let totalCommits: Int?
        let branches: [String]?
    }
}

/// Service for reading projectstats.json files from project directories
struct JSONStatsReader {
    static let shared = JSONStatsReader()

    private let fileManager = FileManager.default
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    /// ISO 8601 date formatter for parsing date strings
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Read projectstats.json from a project directory
    /// - Parameter directory: The root directory of the project
    /// - Returns: Parsed ProjectStatsJSON if the file exists and is valid, nil otherwise
    func read(from directory: URL) -> ProjectStatsJSON? {
        let jsonPath = directory.appendingPathComponent("projectstats.json")

        guard fileManager.fileExists(atPath: jsonPath.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: jsonPath)
            let stats = try decoder.decode(ProjectStatsJSON.self, from: data)
            return stats
        } catch {
            print("[JSONStatsReader] Warning: Failed to parse projectstats.json at \(jsonPath.path): \(error)")
            return nil
        }
    }

    /// Parse an ISO 8601 date string into a Date object
    /// - Parameter dateString: ISO 8601 formatted date string
    /// - Returns: Parsed Date or nil if parsing fails
    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        // Try with fractional seconds first
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        if let date = isoFormatterNoFractional.date(from: dateString) {
            return date
        }

        return nil
    }

    /// Get the generatedAt timestamp as a Date
    /// - Parameter stats: The parsed ProjectStatsJSON
    /// - Returns: The generatedAt date or nil if parsing fails
    static func generatedAtDate(from stats: ProjectStatsJSON) -> Date? {
        return parseDate(stats.generatedAt)
    }

    /// Convert ProjectStatsJSON git info to a Commit object for lastCommit
    /// - Parameter stats: The parsed ProjectStatsJSON
    /// - Returns: A Commit object if git info contains last commit data
    static func lastCommit(from stats: ProjectStatsJSON) -> Commit? {
        guard let git = stats.git,
              let message = git.lastCommitMessage,
              let dateString = git.lastCommitDate,
              let date = parseDate(dateString) else {
            return nil
        }

        // We don't have the commit hash or author from the JSON, use placeholders
        return Commit(
            id: "json-import",
            message: message,
            author: "Unknown",
            date: date
        )
    }
}
