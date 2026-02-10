import AppKit
import Foundation
import SwiftData

enum ProjectType: String, CaseIterable, Identifiable {
    case blank = "Blank"
    case swift = "Swift"
    case nextjs = "Next.js"
    case python = "Python"
    case xcode = "Xcode"
    case kanbanSwarmTest = "Kanban (Swarm Test)"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .blank: return "folder"
        case .swift: return "swift"
        case .nextjs: return "globe"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .xcode: return "hammer"
        case .kanbanSwarmTest: return "person.3.fill"
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

        // Type-specific scaffolding
        try scaffoldProject(type: type, at: projectURL)

        // Generate projectstats.json for scanner discovery
        try generateProjectStatsJSON(at: projectURL, name: folderName, language: languageForType(type))

        // Git init + initial commit (after scaffold so files are included)
        Shell.run("cd '\(projectURL.path)' && git init && git add . && git commit -m 'Initial scaffold'")

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
        context.safeSave()

        return projectURL
    }

    /// For Xcode projects: launch Xcode and let user pick folder after
    func launchXcodeForProjectCreation() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Xcode.app"))
    }

    /// For Xcode: user picks existing Xcode project folder, we add docs + DB entry
    func adoptXcodeProject(at url: URL, context: ModelContext) throws {
        try createDefaultDocs(at: url, projectName: url.lastPathComponent)
        try generateProjectStatsJSON(at: url, name: url.lastPathComponent, language: "Swift")
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
        context.safeSave()
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
        case .kanbanSwarmTest:
            try createKanbanSwarmScaffold(at: url)
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

    /// Generate a minimal projectstats.json for scanner discovery
    private func generateProjectStatsJSON(at projectURL: URL, name: String, language: String?) throws {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let stats: [String: Any] = [
            "name": name,
            "description": "",
            "status": "active",
            "language": language ?? "Unknown",
            "languages": [:] as [String: Int],
            "lineCount": 0,
            "fileCount": 0,
            "structure": "flat",
            "sourceDirectories": ["."],
            "excludedDirectories": ["node_modules", ".git", ".build"],
            "techStack": [] as [String],
            "generatedAt": isoFormatter.string(from: Date()),
            "generatedBy": "projectStats"
        ]

        let data = try JSONSerialization.data(withJSONObject: stats, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: projectURL.appendingPathComponent("projectstats.json"))
    }

    private func languageForType(_ type: ProjectType) -> String? {
        switch type {
        case .blank: return nil
        case .swift: return "Swift"
        case .nextjs: return "TypeScript"
        case .python: return "Python"
        case .xcode: return "Swift"
        case .kanbanSwarmTest: return "JavaScript"
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

    // MARK: - Kanban Swarm Scaffold

    private func createKanbanSwarmScaffold(at url: URL) throws {
        try createGitignore(at: url, content: gitignoreGeneral)

        // index.html — semantic skeleton
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Kanban Board</title>
            <link rel="stylesheet" href="style.css">
        </head>
        <body data-theme="light">
            <header>
                <h1>Kanban Board</h1>
                <nav>
                    <input type="text" id="search-cards" placeholder="Search cards...">
                    <button id="add-card">+ New Card</button>
                    <button id="theme-toggle">Toggle Theme</button>
                </nav>
            </header>
            <main class="board">
                <section class="column" id="todo" data-column="todo">
                    <h2>To Do</h2>
                    <div class="card-list"></div>
                    <p class="empty-state">No cards yet</p>
                </section>
                <section class="column" id="in-progress" data-column="in-progress">
                    <h2>In Progress</h2>
                    <div class="card-list"></div>
                    <p class="empty-state">No cards yet</p>
                </section>
                <section class="column" id="done" data-column="done">
                    <h2>Done</h2>
                    <div class="card-list"></div>
                    <p class="empty-state">No cards yet</p>
                </section>
            </main>
            <footer>
                <kbd>N</kbd> New card &middot; <kbd>Ctrl+Z</kbd> Undo &middot; <kbd>Esc</kbd> Cancel
            </footer>
            <script src="app.js"></script>
        </body>
        </html>
        """
        try html.write(to: url.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        // style.css — design tokens + layout
        let css = """
        /* Design Tokens */
        :root {
            --bg: #f5f5f5;
            --card-bg: #ffffff;
            --text: #1a1a1a;
            --accent: #3b82f6;
            --border: #e5e7eb;
            --column-bg: #f0f0f0;
            --shadow: rgba(0,0,0,0.08);
            --spacing-sm: 8px;
            --spacing-md: 16px;
            --spacing-lg: 24px;
        }

        [data-theme="dark"] {
            --bg: #1a1a1a;
            --card-bg: #2d2d2d;
            --text: #e5e5e5;
            --accent: #60a5fa;
            --border: #404040;
            --column-bg: #242424;
            --shadow: rgba(0,0,0,0.3);
        }

        /* TODO: Implement responsive layout, card styles, drag states */
        /* Teammate 2 owns this file */

        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: system-ui, sans-serif; background: var(--bg); color: var(--text); transition: background 0.2s ease, color 0.2s ease; }
        """
        try css.write(to: url.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)

        // app.js — module skeleton
        let js = """
        // Kanban App — State Store Pattern
        // Teammate 3 owns this file

        const state = {
            cards: [],
            undoStack: [],
            theme: 'light'
        };

        // TODO: Implement these functions
        function createCard(title) {}
        function deleteCard(id) {}
        function editCard(id, newTitle) {}
        function dragStart(e) {}
        function dragDrop(e) {}
        function saveToLocalStorage() {}
        function loadFromLocalStorage() {}
        function toggleTheme() {}
        function undo() {}
        function filterCards(query) {}

        // Init
        document.addEventListener('DOMContentLoaded', () => {
            loadFromLocalStorage();
        });
        """
        try js.write(to: url.appendingPathComponent("app.js"), atomically: true, encoding: .utf8)

        // Create prompts/1.md with the swarm prompt
        let promptsDir = url.appendingPathComponent("prompts")
        try FileManager.default.createDirectory(at: promptsDir, withIntermediateDirectories: true)
        try SwarmTestPrompt.kanbanPrompt.write(to: promptsDir.appendingPathComponent("1.md"), atomically: true, encoding: .utf8)
    }

    // MARK: - Gitignore Templates

    private var gitignoreGeneral: String {
        ".DS_Store\n.build/\n*.swp\n*~\n"
    }

    private var gitignorePython: String {
        ".DS_Store\n__pycache__/\n*.pyc\nvenv/\n.env\ndist/\n*.egg-info/\n"
    }
}
