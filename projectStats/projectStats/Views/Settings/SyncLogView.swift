import SwiftUI
import AppKit

struct SyncLogView: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sync Log")
                    .font(.headline)
                Spacer()
                Button("Copy") {
                    let text = lines.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }

            ScrollView {
                Text(lines.joined(separator: "\n"))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .frame(minWidth: 700, minHeight: 400)
    }
}
