import SwiftUI

struct ReportPreviewView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)

            TextEditor(text: .constant(markdown))
                .font(.system(.body, design: .monospaced))
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    ReportPreviewView(markdown: "# Sample Report\n\nHello world")
}
