import SwiftUI

/// VIBE Tab — Phase 1 rebuild placeholder
/// Will be fully rebuilt in Scope D with chat UI
struct VibeTabView: View {
    let projectPath: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("VIBE Tab — Rebuilding...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(URL(fileURLWithPath: projectPath).lastPathComponent)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
