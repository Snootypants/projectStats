import SwiftUI

struct ReadmePreview: View {
    let content: String
    @State private var isExpanded = false

    private let maxCollapsedLines = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AttributedString(parseMarkdown(content)))
                .textSelection(.enabled)
                .lineLimit(isExpanded ? nil : maxCollapsedLines)

            if shouldShowExpandButton {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "Show Less" : "Show More")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var shouldShowExpandButton: Bool {
        content.components(separatedBy: .newlines).count > maxCollapsedLines
    }

    private func parseMarkdown(_ text: String) -> String {
        // Basic markdown cleaning for display
        var result = text

        // Remove link formatting: [text](url) -> text
        let linkPattern = "\\[([^\\]]+)\\]\\([^)]+\\)"
        if let regex = try? NSRegularExpression(pattern: linkPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1")
        }

        // Remove images: ![alt](url) -> [Image: alt]
        let imagePattern = "!\\[([^\\]]*)\\]\\([^)]+\\)"
        if let regex = try? NSRegularExpression(pattern: imagePattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[Image: $1]")
        }

        // Clean up multiple newlines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result
    }
}

#Preview {
    ReadmePreview(content: """
    # My Project

    A comprehensive project for demonstrating features.

    ## Features

    - Feature one with [link](https://example.com)
    - Feature two
    - Feature three

    ## Installation

    ```bash
    npm install my-project
    ```

    ## Usage

    Import and use like this:

    ```javascript
    import { myProject } from 'my-project';
    myProject.init();
    ```

    ## Contributing

    Pull requests are welcome!

    ## License

    MIT
    """)
    .frame(width: 500)
    .padding()
}
