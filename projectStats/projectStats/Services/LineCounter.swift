import Foundation

struct LineCounter {
    static let sourceExtensions: Set<String> = [
        "swift", "ts", "tsx", "js", "jsx", "py", "rs", "go", "java", "kt", "kts",
        "c", "cpp", "h", "hpp", "cs", "rb", "php", "vue", "svelte", "astro",
        "html", "css", "scss", "sass", "less", "sql", "sh", "bash", "zsh",
        "yaml", "yml", "json", "toml", "xml", "md", "markdown"
    ]

    static let excludedDirs: Set<String> = [
        ".git", "node_modules", ".build", "build", "dist", "Pods", "DerivedData",
        ".next", "vendor", "__pycache__", ".venv", "venv", "target", ".idea",
        ".vscode", "coverage", ".nyc_output", "tmp", ".cache", ".turbo"
    ]

    static func countLines(in directory: URL) -> (lines: Int, files: Int) {
        var totalLines = 0
        var totalFiles = 0

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }

        while let fileURL = enumerator.nextObject() as? URL {
            // Skip excluded directories
            let pathComponents = fileURL.pathComponents
            if pathComponents.contains(where: { excludedDirs.contains($0) }) {
                if FileManager.default.isDirectory(at: fileURL) {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Check if it's a directory
            if FileManager.default.isDirectory(at: fileURL) {
                continue
            }

            // Check extension
            guard sourceExtensions.contains(fileURL.fileExtensionLower) else {
                continue
            }

            // Count lines
            if let contents = try? String(contentsOf: fileURL, encoding: .utf8) {
                totalLines += contents.components(separatedBy: .newlines).count
                totalFiles += 1
            }
        }

        return (totalLines, totalFiles)
    }

    static func detectLanguage(in directory: URL) -> String? {
        var extensionCounts: [String: Int] = [:]

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        while let fileURL = enumerator.nextObject() as? URL {
            let pathComponents = fileURL.pathComponents
            if pathComponents.contains(where: { excludedDirs.contains($0) }) {
                continue
            }

            let ext = fileURL.fileExtensionLower
            if sourceExtensions.contains(ext) {
                extensionCounts[ext, default: 0] += 1
            }
        }

        guard let topExtension = extensionCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        return languageName(for: topExtension)
    }

    static func languageName(for ext: String) -> String {
        switch ext {
        case "swift": return "Swift"
        case "ts", "tsx": return "TypeScript"
        case "js", "jsx": return "JavaScript"
        case "py": return "Python"
        case "rs": return "Rust"
        case "go": return "Go"
        case "java": return "Java"
        case "kt", "kts": return "Kotlin"
        case "c": return "C"
        case "cpp", "hpp": return "C++"
        case "h": return "C/C++ Header"
        case "cs": return "C#"
        case "rb": return "Ruby"
        case "php": return "PHP"
        case "vue": return "Vue"
        case "svelte": return "Svelte"
        case "html": return "HTML"
        case "css", "scss", "sass", "less": return "CSS"
        case "sql": return "SQL"
        case "sh", "bash", "zsh": return "Shell"
        default: return ext.uppercased()
        }
    }
}
