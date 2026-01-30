import Foundation

struct ReadmeParser {
    static func extractDescription(from url: URL) -> String? {
        let readmeNames = ["README.md", "README.MD", "readme.md", "Readme.md", "README", "readme"]

        for name in readmeNames {
            let readmeURL = url.appendingPathComponent(name)
            if let content = try? String(contentsOf: readmeURL, encoding: .utf8) {
                return parseFirstParagraph(from: content)
            }
        }

        return nil
    }

    static func parseFirstParagraph(from markdown: String) -> String? {
        let lines = markdown.components(separatedBy: .newlines)
        var paragraphLines: [String] = []
        var foundContent = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines at the start
            if !foundContent && trimmed.isEmpty {
                continue
            }

            // Skip headers
            if trimmed.hasPrefix("#") {
                if foundContent {
                    break
                }
                continue
            }

            // Skip badges (images at the start)
            if trimmed.hasPrefix("![") || trimmed.hasPrefix("[![") {
                continue
            }

            // Empty line after content means end of paragraph
            if trimmed.isEmpty && foundContent {
                break
            }

            if !trimmed.isEmpty {
                foundContent = true
                paragraphLines.append(trimmed)
            }
        }

        let paragraph = paragraphLines.joined(separator: " ")

        // Clean up markdown formatting
        let cleaned = paragraph
            .replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression) // Links
            .replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression) // Bold
            .replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression) // Italic
            .replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression) // Code

        return cleaned.isEmpty ? nil : String(cleaned.prefix(300))
    }

    static func readFullContent(from url: URL) -> String? {
        let readmeNames = ["README.md", "README.MD", "readme.md", "Readme.md", "README", "readme"]

        for name in readmeNames {
            let readmeURL = url.appendingPathComponent(name)
            if let content = try? String(contentsOf: readmeURL, encoding: .utf8) {
                return content
            }
        }

        return nil
    }
}
