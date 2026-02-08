import Foundation

extension String {
    /// Strips all ANSI escape codes (CSI, OSC, character set, keypad mode, stray escapes, BEL)
    func strippingAnsiCodes() -> String {
        let pattern = [
            "\\x1B\\[[0-9;?]*[a-zA-Z]",                    // CSI sequences (includes DEC private mode)
            "\\x1B\\][^\u{07}]*(?:\u{07}|\\x1B\\\\)",       // OSC sequences
            "\\x1B[()][0-9A-B]",                             // Character set selection
            "\\x1B[=>]",                                     // Keypad mode
        ].joined(separator: "|")

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let range = NSRange(startIndex..., in: self)
        var result = regex.stringByReplacingMatches(in: self, range: range, withTemplate: "")
        result = result.replacingOccurrences(of: "\u{1B}", with: "")
        result = result.replacingOccurrences(of: "\u{07}", with: "")
        return result
    }

    /// Restores word boundaries lost during ANSI stripping.
    /// Terminal output often uses cursor movement instead of spaces,
    /// causing words to smash together after stripping.
    func restoreWordBoundaries() -> String {
        var result = self
        // Insert space between a lowercase/digit and an uppercase letter (camelCase boundary)
        if let regex = try? NSRegularExpression(pattern: "([a-z0-9])([A-Z])") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1 $2")
        }
        // Collapse runs of whitespace to a single space (but preserve newlines)
        if let regex = try? NSRegularExpression(pattern: "[^\\S\\n]+") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: " ")
        }
        // Clean up null bytes and other control chars that slip through
        result = result.filter { $0.asciiValue == nil || $0.asciiValue! >= 32 || $0 == "\n" || $0 == "\r" || $0 == "\t" }
        return result
    }
}
