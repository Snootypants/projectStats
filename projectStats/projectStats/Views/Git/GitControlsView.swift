import SwiftUI

struct GitControlsView: View {
    @StateObject private var viewModel: GitControlsViewModel
    @State private var showCommitDialog = false
    @State private var showBranchPrompt = false
    @State private var newBranchName = ""
    @State private var showError = false

    init(projectPath: URL) {
        _viewModel = StateObject(wrappedValue: GitControlsViewModel(projectPath: projectPath))
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption2)
                Text(viewModel.currentBranch.isEmpty ? "No Branch" : viewModel.currentBranch)
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Menu {
                Button("Commit...") { showCommitDialog = true }
                Button("Commit & Push") { showCommitDialog = true }
                Divider()
                Button("Pull") { Task { await viewModel.pull() } }
                Button("Create Branch") { showBranchPrompt = true }

                Menu("Switch Branch") {
                    ForEach(viewModel.branches, id: \.self) { branch in
                        Button(branch) { Task { await viewModel.switchBranch(name: branch) } }
                    }
                }

                Button("Create PR") { viewModel.createPullRequest() }
                Divider()
                Button("Stash") { Task { await viewModel.stash() } }
                Button("Stash Pop") { Task { await viewModel.stashPop() } }
            } label: {
                Text("Commit (\(viewModel.status.totalCount) files)")
            }
            .menuStyle(.borderlessButton)

            Button {
                Task {
                    let _ = await viewModel.push()
                    if viewModel.errorMessage != nil {
                        showError = true
                    }
                }
            } label: {
                if viewModel.aheadCount > 0 {
                    Text("Push (\(viewModel.aheadCount))")
                } else {
                    Text("Push")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert("Git Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
        .sheet(isPresented: $showCommitDialog) {
            CommitDialog(status: viewModel.status) { message, files, pushAfter in
                Task {
                    await viewModel.commit(message: message, files: files, pushAfter: pushAfter)
                    if viewModel.errorMessage != nil {
                        showError = true
                    }
                }
            }
        }
        .alert("Create Branch", isPresented: $showBranchPrompt) {
            TextField("Branch name", text: $newBranchName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                Task { await viewModel.createBranch(name: newBranchName) }
                newBranchName = ""
            }
        }
        .onAppear {
            Task { await viewModel.refresh() }
        }
    }
}

#Preview {
    GitControlsView(projectPath: URL(fileURLWithPath: "/tmp"))
}
