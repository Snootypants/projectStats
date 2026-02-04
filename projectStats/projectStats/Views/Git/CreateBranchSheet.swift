import SwiftUI

struct CreateBranchSheet: View {
    let projectPath: URL
    let onCreated: (URL) -> Void
    let onCancel: () -> Void

    @State private var branchName = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Local Branch")
                .font(.headline)

            Text("This creates a copy of the project folder with a new git branch. The original remains unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Branch name (e.g., feature-login)", text: $branchName)
                .textFieldStyle(.roundedBorder)

            if !branchName.isEmpty {
                let sanitized = BranchService.shared.sanitizeBranchName(branchName)
                let folderName = "\(projectPath.lastPathComponent)-\(sanitized)"
                Text("Will create: \(folderName)/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Create Branch") {
                    createBranch()
                }
                .keyboardShortcut(.return)
                .disabled(branchName.isEmpty || isCreating)
            }

            if isCreating {
                ProgressView("Creating branch...")
                    .progressViewStyle(.linear)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func createBranch() {
        isCreating = true
        error = nil

        Task {
            do {
                let result = try await BranchService.shared.createLocalBranch(
                    from: projectPath,
                    branchName: branchName
                )
                await MainActor.run {
                    onCreated(result.branchPath)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    CreateBranchSheet(
        projectPath: URL(fileURLWithPath: "/Users/test/MyProject"),
        onCreated: { _ in },
        onCancel: {}
    )
}
