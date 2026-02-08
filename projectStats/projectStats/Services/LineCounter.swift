import Foundation

struct LineCounter {
    /// Count lines using scc (brew install scc). Falls back to basic count if scc not available.
    static func countLines(in directory: URL) -> (lines: Int, files: Int) {
        let result = Shell.runResult("scc --format json --no-complexity --no-cocomo '\(directory.path)'")
        if result.exitCode == 0, let data = result.output.data(using: .utf8) {
            return parseSCCOutput(data)
        }
        return fallbackCount(in: directory)
    }

    static var isSCCAvailable: Bool {
        Shell.run("which scc").contains("/scc")
    }

    // MARK: - SCC JSON Parsing

    static func parseSCCOutput(_ data: Data) -> (lines: Int, files: Int) {
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return (0, 0)
        }
        var totalLines = 0
        var totalFiles = 0
        for entry in entries {
            totalLines += entry["Code"] as? Int ?? 0
            totalFiles += entry["Count"] as? Int ?? 0
        }
        return (totalLines, totalFiles)
    }

    // MARK: - Fallback (when scc is not installed)

    private static let sourceExtensions: Set<String> = [
        "swift", "ts", "tsx", "js", "jsx", "py", "rs", "go", "java", "kt", "kts",
        "c", "cpp", "h", "hpp", "cs", "rb", "php", "vue", "svelte", "astro",
        "html", "css", "scss", "sass", "less", "sql", "sh", "bash", "zsh",
        "yaml", "yml", "json", "toml", "xml", "md", "markdown"
    ]

    private static let excludedDirs: Set<String> = [
        ".git", "node_modules", ".build", "build", "dist", "Pods", "DerivedData",
        ".next", "vendor", "__pycache__", ".venv", "venv", "target", ".idea",
        ".vscode", "coverage", ".nyc_output", "tmp", ".cache", ".turbo"
    ]

    private static func fallbackCount(in directory: URL) -> (lines: Int, files: Int) {
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
            let pathComponents = fileURL.pathComponents
            if pathComponents.contains(where: { excludedDirs.contains($0) }) {
                if FileManager.default.isDirectory(at: fileURL) {
                    enumerator.skipDescendants()
                }
                continue
            }

            if FileManager.default.isDirectory(at: fileURL) {
                continue
            }

            guard sourceExtensions.contains(fileURL.fileExtensionLower) else {
                continue
            }

            if let contents = try? String(contentsOf: fileURL, encoding: .utf8) {
                totalLines += contents.components(separatedBy: .newlines).count
                totalFiles += 1
            }
        }

        return (totalLines, totalFiles)
    }
}
