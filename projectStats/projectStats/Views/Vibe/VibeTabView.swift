import SwiftUI

struct VibeTabView: View {
    let projectPath: String

    var body: some View {
        Text("VIBE — \(URL(fileURLWithPath: projectPath).lastPathComponent)")
            .font(.title2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
