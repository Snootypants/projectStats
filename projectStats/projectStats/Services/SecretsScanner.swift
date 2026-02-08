import Foundation

final class SecretsScanner {
    static let shared = SecretsScanner()

    var isGitleaksAvailable: Bool {
        Shell.run("which gitleaks").contains("/gitleaks")
    }

    /// Scan staged files for secrets using gitleaks. Falls back to basic regex if gitleaks not installed.
    func scanStagedFiles(in projectPath: URL) -> [SecretMatch] {
        let result = Shell.runResult(
            "gitleaks protect --staged --no-banner --report-format json --report-path /dev/stdout",
            at: projectPath
        )

        // gitleaks exit code 0 = clean, exit code 1 = leaks found (with JSON output)
        if result.exitCode == 0 {
            return []
        }

        if let data = result.output.data(using: .utf8),
           let findings = try? JSONDecoder().decode([GitleaksMatch].self, from: data) {
            return findings.map { SecretMatch(
                type: $0.RuleID,
                filePath: $0.File,
                line: $0.StartLine,
                snippet: $0.Match
            )}
        }

        // Fallback: basic regex scan if gitleaks not available or JSON parse failed
        return fallbackScan(in: projectPath)
    }

    // MARK: - Gitleaks JSON Model

    private struct GitleaksMatch: Decodable {
        let RuleID: String
        let File: String
        let StartLine: Int
        let Match: String
    }

    // MARK: - Legacy Regex Fallback

    private let patterns: [(name: String, regex: String)] = [
        ("AWS Key", "AKIA[0-9A-Z]{16}"),
        ("GitHub Token", "ghp_[a-zA-Z0-9]{36}"),
        ("Slack Token", "xox[baprs]-[0-9a-zA-Z]{10,}"),
        ("Private Key", "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"),
        ("Anthropic Key", "sk-ant-[a-zA-Z0-9-_]{32,}"),
        ("OpenAI Key", "sk-[a-zA-Z0-9]{32,}"),
        ("Stripe Key", "sk_(live|test)_[a-zA-Z0-9]{24,}"),
        ("Generic Secret", "(password|secret|token|api_key)\\s*[=:]\\s*['\"][^'\"]+['\"]")
    ]

    private func fallbackScan(in projectPath: URL) -> [SecretMatch] {
        let stagedResult = Shell.runResult("git diff --cached --name-only", at: projectPath)
        guard stagedResult.exitCode == 0 else { return [] }

        let stagedFiles = stagedResult.output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { projectPath.appendingPathComponent($0) }

        var matches: [SecretMatch] = []
        for file in stagedFiles {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for (name, pattern) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let nsrange = NSRange(content.startIndex..., in: content)
                let results = regex.matches(in: content, range: nsrange)
                for result in results {
                    let line = lineNumber(for: result.range, in: content)
                    let snippet = snippetFor(range: result.range, in: content)
                    matches.append(SecretMatch(type: name, filePath: file.path, line: line, snippet: snippet))
                }
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
