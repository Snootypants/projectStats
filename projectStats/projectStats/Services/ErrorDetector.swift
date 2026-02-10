import Foundation

// MARK: - DORMANT — Not wired to any UI or ViewModel.
// Error detection patterns defined but never instantiated or called.
// Do NOT maintain or update until activated.
// To activate: remove this marker, wire to a ViewModel, add tests.

struct DetectedError: Identifiable {
    let id = UUID()
    let type: String
    let snippet: String
    let suggestion: String?
}

final class ErrorDetector {
    let patterns = [
        "at .+\\(.+:\\d+:\\d+\\)",
        "Error:",
        "Exception:",
        "FATAL:",
        "panic:",
        "error\\[E\\d+\\]:",
        "error: ",
        "exit code \\d+",
        "failed with"
    ]

    func detectError(in output: String) -> DetectedError? {
        for pattern in patterns {
            if let match = output.range(of: pattern, options: .regularExpression) {
                let snippet = extractErrorContext(output, around: match)
                return DetectedError(type: classifyError(pattern), snippet: snippet, suggestion: nil)
            }
        }
        return nil
    }

    private func classifyError(_ pattern: String) -> String {
        if pattern.contains("panic") { return "panic" }
        if pattern.contains("Exception") { return "exception" }
        if pattern.contains("FATAL") { return "fatal" }
        if pattern.contains("Error") { return "error" }
        return "error"
    }

    private func extractErrorContext(_ output: String, around range: Range<String.Index>) -> String {
        let start = output.index(range.lowerBound, offsetBy: -120, limitedBy: output.startIndex) ?? output.startIndex
        let end = output.index(range.upperBound, offsetBy: 120, limitedBy: output.endIndex) ?? output.endIndex
        return String(output[start..<end])
    }
}
