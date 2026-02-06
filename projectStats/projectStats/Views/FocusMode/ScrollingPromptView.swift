import SwiftUI

struct ScrollingPromptView: View {
    @State private var offset: CGFloat = 0
    @State private var promptText: String = ""

    var body: some View {
        GeometryReader { geo in
            Text(promptText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green.opacity(0.7))
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .offset(y: geo.size.height - offset)
                .onAppear {
                    loadRandomPrompt()
                    withAnimation(.linear(duration: max(Double(promptText.count) / 20.0, 30.0))) {
                        offset = geo.size.height + CGFloat(promptText.count) * 1.2
                    }
                }
        }
        .allowsHitTesting(false)
    }

    private func loadRandomPrompt() {
        promptText = """
        # SCOPE A: Initialize Project

        Create the foundation for a new application...
        Set up the project structure, install dependencies,
        and configure the build system.

        ## Requirements
        - Swift 5.9+
        - macOS 14+
        - SwiftData for persistence
        - SwiftUI for UI layer

        ## Implementation
        Begin by creating the data models...
        """
    }
}
