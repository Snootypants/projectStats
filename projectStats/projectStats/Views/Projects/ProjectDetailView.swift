import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @StateObject private var projectListVM = ProjectListViewModel()
    @State private var readmeContent: String?
    @State private var commitHistory: [Commit] = []
    @State private var isLoadingReadme = false
    @State private var showIDEMode = false

    var body: some View {
        VStack(spacing: 0) {
            if showIDEMode {
                IDEModeView(project: project)
            } else {
                detailContent
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showIDEMode.toggle()
                } label: {
                    Label(
                        showIDEMode ? "Show Details" : "Open IDE",
                        systemImage: showIDEMode ? "info.circle" : "rectangle.split.3x1"
                    )
                }
            }
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(project.name)
                                    .font(.title)
                                    .fontWeight(.bold)

                                StatusBadge(status: project.status)
                            }

                            if let language = project.language {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                                        .font(.caption)
                                    Text(language)
                                        .font(.subheadline)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Action buttons
                        HStack(spacing: 8) {
                            Button {
                                projectListVM.openInEditor(project)
                            } label: {
                                Label("Open", systemImage: "rectangle.and.pencil.and.ellipsis")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                projectListVM.openInFinder(project)
                            } label: {
                                Label("Finder", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)

                            if project.githubURL != nil {
                                Button {
                                    projectListVM.openGitHub(project)
                                } label: {
                                    Label("GitHub", systemImage: "link")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    projectListVM.copyGitHubURL(project)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .help("Copy GitHub URL")
                            }
                        }
                    }

                    if let description = project.description {
                        Text(description)
                            .foregroundStyle(.secondary)
                    }

                    Text(project.path.path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatTile(title: "Lines", value: project.formattedLineCount, icon: "text.alignleft")
                    StatTile(title: "Files", value: "\(project.fileCount)", icon: "doc.text")
                    StatTile(title: "Prompts", value: "\(project.promptCount)", icon: "text.bubble")
                    StatTile(title: "Work Logs", value: "\(project.workLogCount)", icon: "list.bullet.clipboard")
                }

                // Last commit
                if let commit = project.lastCommit {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Commit")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(commit.shortMessage)
                                    .font(.body)

                                HStack {
                                    Text(commit.shortHash)
                                        .font(.caption)
                                        .fontDesign(.monospaced)

                                    Text("by \(commit.author)")
                                        .font(.caption)

                                    Text(commit.date.relativeString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // README preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("README")
                            .font(.headline)

                        Spacer()

                        if isLoadingReadme {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

                    if let content = readmeContent {
                        ReadmePreview(content: content)
                    } else {
                        Text("No README found")
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Commit history
                if !commitHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Commits")
                            .font(.headline)

                        VStack(spacing: 0) {
                            ForEach(commitHistory.prefix(10)) { commit in
                                CommitRow(commit: commit)

                                if commit.id != commitHistory.prefix(10).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
        }
        .task {
            await loadDetails()
        }
    }

    private func loadDetails() async {
        isLoadingReadme = true
        defer { isLoadingReadme = false }

        readmeContent = ReadmeParser.readFullContent(from: project.path)
        commitHistory = GitService.shared.getCommitHistory(at: project.path, limit: 20)
    }
}

struct StatusBadge: View {
    let status: ProjectStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .active: return .green
        case .inProgress: return .yellow
        case .dormant: return .gray
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CommitRow: View {
    let commit: Commit

    var body: some View {
        HStack(spacing: 10) {
            Text(commit.shortHash)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.blue)
                .frame(width: 60, alignment: .leading)

            Text(commit.shortMessage)
                .font(.callout)
                .lineLimit(1)

            Spacer()

            Text(commit.date.relativeString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    ProjectDetailView(project: Project(
        path: URL(fileURLWithPath: "/Users/test/Code/myproject"),
        name: "myproject",
        description: "A comprehensive test project demonstrating various features of the project scanner and stats dashboard.",
        githubURL: "https://github.com/test/myproject",
        language: "Swift",
        lineCount: 15420,
        fileCount: 87,
        promptCount: 3,
        workLogCount: 12,
        lastCommit: Commit(id: "abc123def456789", message: "Fix critical bug in authentication flow", author: "Caleb Belshe", date: Date())
    ))
    .frame(width: 600, height: 800)
}
