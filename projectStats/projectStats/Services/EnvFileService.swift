import Foundation

struct EnvFileService {
    func parseEnvFile(at url: URL) -> [EnvironmentVariable] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        return parseVariables(from: content)
    }

    func parseEnvExample(at url: URL) -> [String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        let variables = parseVariables(from: content)
        return variables.map { $0.key }
    }

    func writeEnvFile(variables: [EnvironmentVariable], to url: URL) throws {
        let content = variables
            .filter { $0.isEnabled }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func ensureGitignore(contains entry: String = ".env", in projectURL: URL) throws {
        let gitignoreURL = projectURL.appendingPathComponent(".gitignore")
        var content = (try? String(contentsOf: gitignoreURL, encoding: .utf8)) ?? ""

        if !content.contains(entry) {
            if !content.hasSuffix("\n") && !content.isEmpty {
                content += "\n"
            }
            content += "\(entry)\n"
            try content.write(to: gitignoreURL, atomically: true, encoding: .utf8)
        }
    }

    private func parseVariables(from content: String) -> [EnvironmentVariable] {
        var variables: [EnvironmentVariable] = []

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("export ") {
                line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
            }

            guard let separatorIndex = line.firstIndex(of: "=") else { continue }

            let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(line[line.index(after: separatorIndex)...])
                .trimmingCharacters(in: .whitespaces)
            let value = stripQuotes(from: rawValue)

            guard !key.isEmpty else { continue }

            variables.append(
                EnvironmentVariable(
                    key: key,
                    value: value,
                    isEnabled: !value.isEmpty,
                    source: .imported
                )
            )
        }

        return variables
    }

    private func stripQuotes(from value: String) -> String {
        guard value.count >= 2 else { return value }
        let first = value.first
        let last = value.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
