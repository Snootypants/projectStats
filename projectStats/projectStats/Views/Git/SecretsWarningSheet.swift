import SwiftUI

struct SecretsWarningSheet: View {
    let secrets: [SecretMatch]
    let onCancel: () -> Void
    let onCommitAnyway: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)

                VStack(alignment: .leading) {
                    Text("Secrets Detected!")
                        .font(.headline)
                    Text("\(secrets.count) potential secret(s) found in staged files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

            // List of secrets
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(secrets) { secret in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(.orange)
                                Text(secret.type)
                                    .font(.headline)
                            }

                            Text(secret.filePath)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let line = secret.line {
                                Text("Line \(line)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            if let snippet = secret.snippet {
                                Text(snippet)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(8)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(4)
                                    .lineLimit(2)
                            }
                        }
                        .padding()
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
            }
            .frame(maxHeight: 300)

            // Warning text
            Text("Committing secrets to git can expose API keys and credentials. Consider using environment variables or a .env file (added to .gitignore).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Buttons
            HStack {
                Button("Cancel Commit") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Commit Anyway") {
                    onCommitAnyway()
                }
                .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 500)
    }
}

#Preview {
    SecretsWarningSheet(
        secrets: [
            SecretMatch(type: "GitHub Token", filePath: "config.swift", line: 42, snippet: "let token = \"ghp_abc...\"")
        ],
        onCancel: {},
        onCommitAnyway: {}
    )
}
