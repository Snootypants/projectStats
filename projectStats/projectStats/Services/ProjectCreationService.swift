import AppKit
import Foundation
import SwiftData

enum ProjectType: String, CaseIterable, Identifiable {
    case blank = "Blank"
    case swift = "Swift"
    case nextjs = "Next.js"
    case python = "Python"
    case xcode = "Xcode"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .blank: return "folder"
        case .swift: return "swift"
        case .nextjs: return "globe"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .xcode: return "hammer"
        }
    }
}

enum ProjectCreationError: LocalizedError {
    case emptyName
    case invalidName
    case folderExists
    case creationFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Project name cannot be empty."
        case .invalidName: return "Project name contains invalid characters."
        case .folderExists: return "A folder with this name already exists."
        case .creationFailed(let msg): return msg
        }
    }
}

final class ProjectCreationService {
    static let shared = ProjectCreationService()
    private init() {}

    /// Validate a project name
    func validateName(_ name: String) -> ProjectCreationError? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .emptyName }
        let invalidChars = CharacterSet.alphanumerics
            .union(.init(charactersIn: "-_ "))
            .inverted
        if trimmed.unicodeScalars.contains(where: { invalidChars.contains($0) }) {
            return .invalidName
        }
        return nil
    }

    /// Create a new project folder and return its URL
    func createProject(
        name: String,
        type: ProjectType,
        baseDirectory: URL,
        context: ModelContext
    ) async throws -> URL {
        if let error = validateName(name) { throw error }

        let folderName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectURL = baseDirectory.appendingPathComponent(folderName)

        if FileManager.default.fileExists(atPath: projectURL.path) {
            throw ProjectCreationError.folderExists
        }

        // Create directory
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        // Git init
        Shell.run("cd '\(projectURL.path)' && git init")

        // Type-specific scaffolding (expanded in Scope E)
        try scaffoldProject(type: type, at: projectURL)

        // Create DB entry
        let cached = CachedProject(
            path: projectURL.path,
            name: folderName,
            language: languageForType(type),
            lineCount: 0,
            fileCount: 0,
            promptCount: 0,
            workLogCount: 0,
            lastScanned: Date()
        )
        context.insert(cached)
        try? context.save()

        return projectURL
    }

    private func scaffoldProject(type: ProjectType, at url: URL) throws {
        switch type {
        case .blank:
            try createGitignore(at: url, content: gitignoreGeneral)
        case .swift:
            Shell.run("cd '\(url.path)' && swift package init --type executable")
        case .python:
            try createPythonScaffold(at: url)
        case .nextjs:
            // Handled by terminal command in Scope E
            break
        case .xcode:
            // Handled by Xcode launch in Scope E
            break
        }
    }

    private func createPythonScaffold(at url: URL) throws {
        let main = """
        def main():
            print("Hello, World!")


        if __name__ == "__main__":
            main()
        """
        try main.write(to: url.appendingPathComponent("main.py"), atomically: true, encoding: .utf8)
        try "".write(to: url.appendingPathComponent("requirements.txt"), atomically: true, encoding: .utf8)
        try createGitignore(at: url, content: gitignorePython)
    }

    private func createGitignore(at url: URL, content: String) throws {
        try content.write(to: url.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
    }

    private func languageForType(_ type: ProjectType) -> String? {
        switch type {
        case .blank: return nil
        case .swift: return "Swift"
        case .nextjs: return "TypeScript"
        case .python: return "Python"
        case .xcode: return "Swift"
        }
    }

    private var gitignoreGeneral: String {
        """
        .DS_Store
        .build/
        *.swp
        *~
        """
    }

    private var gitignorePython: String {
        """
        .DS_Store
        __pycache__/
        *.pyc
        venv/
        .env
        dist/
        *.egg-info/
        """
    }
}
