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

    /// For Xcode projects: launch Xcode and let user pick folder after
    func launchXcodeForProjectCreation() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Xcode.app"))
    }

    /// For Xcode: user picks existing Xcode project folder, we add docs + DB entry
    func adoptXcodeProject(at url: URL, context: ModelContext) throws {
        try createDefaultDocs(at: url, projectName: url.lastPathComponent)
        let cached = CachedProject(
            path: url.path,
            name: url.lastPathComponent,
            language: "Swift",
            lineCount: 0,
            fileCount: 0,
            promptCount: 0,
            workLogCount: 0,
            lastScanned: Date()
        )
        context.insert(cached)
        try? context.save()
    }

    /// Terminal command for Next.js (to be sent to workspace terminal)
    func nextjsCommand(projectName: String) -> String {
        "npx create-next-app@latest \(projectName) --typescript --tailwind --eslint --app --src-dir --import-alias \"@/*\""
    }

    // MARK: - Scaffolding

    private func scaffoldProject(type: ProjectType, at url: URL) throws {
        switch type {
        case .blank:
            try createGitignore(at: url, content: gitignoreGeneral)
        case .swift:
            Shell.run("cd '\(url.path)' && swift package init --type executable")
        case .python:
            try createPythonScaffold(at: url)
        case .nextjs:
            try createGitignore(at: url, content: gitignoreGeneral)
            // Actual scaffolding happens via terminal command
        case .xcode:
            // Handled separately via launchXcodeForProjectCreation
            break
        }
        // All types get default docs
        try createDefaultDocs(at: url, projectName: url.lastPathComponent)
    }

    // MARK: - Default Docs

    func createDefaultDocs(at projectURL: URL, projectName: String) throws {
        let docsDir = projectURL.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)

        let docs: [(String, String)] = [
            ("ARCHITECTURE.md", architectureTemplate(projectName: projectName)),
            ("FILE_STRUCTURE.md", fileStructureTemplate(projectName: projectName)),
            ("MODELS.md", sectionTemplate(title: "Models", projectName: projectName, description: "Data models reference.")),
            ("SERVICES.md", sectionTemplate(title: "Services", projectName: projectName, description: "Service layer reference.")),
            ("VIEWS.md", sectionTemplate(title: "Views", projectName: projectName, description: "View hierarchy reference.")),
            ("VIEWMODELS.md", sectionTemplate(title: "ViewModels", projectName: projectName, description: "ViewModel reference.")),
            ("DEPENDENCIES.md", sectionTemplate(title: "Dependencies", projectName: projectName, description: "External dependencies.")),
            ("KNOWN_ISSUES.md", sectionTemplate(title: "Known Issues", projectName: projectName, description: "Known bugs and limitations.")),
            ("TODO.md", sectionTemplate(title: "TODO", projectName: projectName, description: "Planned work.")),
            ("CHANGELOG.md", changelogTemplate(projectName: projectName)),
            ("README.md", readmeTemplate(projectName: projectName)),
        ]

        for (filename, content) in docs {
            let fileURL = docsDir.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }

        // Also create README at root if it doesn't exist
        let rootReadme = projectURL.appendingPathComponent("README.md")
        if !FileManager.default.fileExists(atPath: rootReadme.path) {
            try readmeTemplate(projectName: projectName).write(to: rootReadme, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - ARCHITECTURE.md Refresh

    /// Refresh ARCHITECTURE.md in the project's docs/ folder.
    /// Creates docs/ directory if it doesn't exist.
    /// Always overwrites to get the latest template.
    func refreshArchitectureMd(at projectURL: URL, projectName: String) throws {
        let docsDir = projectURL.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)

        let archURL = docsDir.appendingPathComponent("ARCHITECTURE.md")
        let content = architectureTemplate(projectName: projectName)
        try content.write(to: archURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Type-Specific Scaffolding

    private func createPythonScaffold(at url: URL) throws {
        let main = "def main():\n    print(\"Hello, World!\")\n\n\nif __name__ == \"__main__\":\n    main()\n"
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

    // MARK: - Doc Templates

    private func architectureTemplate(projectName: String) -> String {
        """
        # \(projectName) — Architecture

        ## Tech Stack
        _List primary technologies, frameworks, and tools._

        ## Folder Structure
        _Describe the directory layout and conventions._

        ## Key Design Decisions
        _Document important architectural choices and rationale._

        ## Data Flow
        _Describe how data moves through the application._

        ## Agent Teams Context

        > This section is auto-updated by the Update Docs button when Agent Teams is enabled.

        ### File Ownership Boundaries
        | Domain | Primary Files | Owner Pattern |
        |--------|--------------|---------------|
        | _Scan project to populate_ | | |

        ### Dependency Graph
        _Run Update Docs with Agent Teams enabled to generate._

        ### Shared State Risks
        _Run Update Docs with Agent Teams enabled to generate._
        """
    }

    private func fileStructureTemplate(projectName: String) -> String {
        """
        # \(projectName) — File Structure

        ```
        /
        ├── docs/           — Project documentation
        ├── README.md       — Project overview
        └── ...
        ```

        _Update this file as the project grows._
        """
    }

    private func sectionTemplate(title: String, projectName: String, description: String) -> String {
        """
        # \(projectName) — \(title)

        \(description)

        _This file is a placeholder. Fill in as the project develops._
        """
    }

    private func changelogTemplate(projectName: String) -> String {
        """
        # \(projectName) — Changelog

        ## [Unreleased]
        - Initial project setup
        """
    }

    private func readmeTemplate(projectName: String) -> String {
        """
        # \(projectName)

        ## Overview
        _Describe what this project does._

        ## Getting Started
        _How to set up and run the project._

        ## Documentation
        See the `/docs` folder for detailed documentation.
        """
    }

    // MARK: - Gitignore Templates

    private var gitignoreGeneral: String {
        ".DS_Store\n.build/\n*.swp\n*~\n"
    }

    private var gitignorePython: String {
        ".DS_Store\n__pycache__/\n*.pyc\nvenv/\n.env\ndist/\n*.egg-info/\n"
    }
}
