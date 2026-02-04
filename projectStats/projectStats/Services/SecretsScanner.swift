import Foundation

final class SecretsScanner {
    static let shared = SecretsScanner()

    let patterns: [(name: String, regex: String)] = [
        ("AWS Key", "AKIA[0-9A-Z]{16}"),
        ("GitHub Token", "ghp_[a-zA-Z0-9]{36}"),
        ("Slack Token", "xox[baprs]-[0-9a-zA-Z]{10,}"),
        ("Private Key", "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"),
        ("Anthropic Key", "sk-ant-[a-zA-Z0-9-_]{32,}"),
        ("OpenAI Key", "sk-[a-zA-Z0-9]{32,}"),
        ("Stripe Key", "sk_(live|test)_[a-zA-Z0-9]{24,}"),
        ("Generic Secret", "(password|secret|token|api_key)\\s*[=:]\\s*['\"][^'\"]+['\"]")
    ]

    /// Scans only git staged files for secrets
    func scanStagedFiles(in projectPath: URL) -> [SecretMatch] {
        // Get list of staged files
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", projectPath.path, "diff", "--cached", "--name-only"]
        process.currentDirectoryURL = projectPath

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let stagedFiles = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { projectPath.appendingPathComponent($0) }

        var allMatches: [SecretMatch] = []
        for file in stagedFiles {
            let matches = scan(file: file)
            allMatches.append(contentsOf: matches)
        }

        return allMatches
    }

    func scan(file: URL) -> [SecretMatch] {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        var matches: [SecretMatch] = []
        for (name, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let nsrange = NSRange(content.startIndex..., in: content)
            let results = regex.matches(in: content, options: [], range: nsrange)
            for result in results {
                let line = lineNumber(for: result.range, in: content)
                let snippet = snippetFor(range: result.range, in: content)
                matches.append(SecretMatch(type: name, filePath: file.path, line: line, snippet: snippet))
            }
        }
        return matches
    }

    private func lineNumber(for range: NSRange, in text: String) -> Int? {
        guard let swiftRange = Range(range, in: text) else { return nil }
        let prefix = text[..<swiftRange.lowerBound]
        return prefix.components(separatedBy: .newlines).count
    }

    private func snippetFor(range: NSRange, in text: String) -> String? {
        guard let swiftRange = Range(range, in: text) else { return nil }
        let start = text.index(swiftRange.lowerBound, offsetBy: -20, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(swiftRange.upperBound, offsetBy: 20, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end])
    }
}
