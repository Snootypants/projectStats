import SwiftUI

struct CommitDialog: View {
    let status: GitStatusSummary
    let onCommit: (String, [String], Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""
    @State private var selectedPaths: Set<String>

    init(status: GitStatusSummary, onCommit: @escaping (String, [String], Bool) -> Void) {
        self.status = status
        self.onCommit = onCommit
        _selectedPaths = State(initialValue: Set(status.changes.map { $0.path }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Commit Changes")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Message:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Commit message", text: $message)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Changed files (\(status.totalCount)):")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(status.changes) { change in
                            Toggle(isOn: Binding(
                                get: { selectedPaths.contains(change.path) },
                                set: { isOn in
                                    if isOn {
                                        selectedPaths.insert(change.path)
                                    } else {
                                        selectedPaths.remove(change.path)
                                    }
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Text(change.status)
                                        .font(.system(size: 11, weight: .bold))
                                        .frame(width: 18)
                                    Text(change.path)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Commit") {
                    onCommit(message, Array(selectedPaths), false)
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Commit & Push") {
                    onCommit(message, Array(selectedPaths), true)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420, height: 420)
    }
}

#Preview {
    CommitDialog(status: .empty) { _, _, _ in }
}
