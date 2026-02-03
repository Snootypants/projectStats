import SwiftUI

struct SecretsWarningView: View {
    let matches: [SecretMatch]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Potential Secrets Detected")
                .font(.headline)

            if matches.isEmpty {
                Text("No secrets detected")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matches) { match in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.type)
                            .font(.subheadline)
                        Text(match.filePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let line = match.line {
                            Text("Line \(line)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                Button("Add to .gitignore") {}
                Button("Commit Anyway") {}
                Button("Cancel") {}
            }
        }
        .padding()
        .frame(minWidth: 500)
    }
}

#Preview {
    SecretsWarningView(matches: [SecretMatch(type: "OpenAI Key", filePath: "/tmp/.env", line: 3, snippet: "sk-...")])
}
