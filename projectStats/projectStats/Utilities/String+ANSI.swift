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
}
