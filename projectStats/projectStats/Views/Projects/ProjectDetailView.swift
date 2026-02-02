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
                    if let totalCommits = project.totalCommits {
                        StatTile(title: "Commits", value: "\(totalCommits)", icon: "arrow.triangle.branch")
                    } else {
                        StatTile(title: "Prompts", value: "\(project.promptCount)", icon: "text.bubble")
                    }
                    StatTile(title: "Work Logs", value: "\(project.workLogCount)", icon: "list.bullet.clipboard")
                }

                // Tech Stack (if available from JSON)
                if !project.techStack.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tech Stack")
                            .font(.headline)

                        FlowLayout(spacing: 6) {
                            ForEach(project.techStack, id: \.self) { tech in
                                Text(tech)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Language Breakdown (if available from JSON)
                if !project.languageBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Languages")
                            .font(.headline)

                        VStack(spacing: 6) {
                            ForEach(project.languageBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { lang, lines in
                                HStack {
                                    Text(lang)
                                        .font(.callout)
                                    Spacer()
                                    Text(formatLineCount(lines))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Structure info (if available and noteworthy)
                if let structure = project.structure, structure != "standard" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Structure")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Type")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                Text(structure.capitalized)
                                    .font(.callout)
                            }

                            if let notes = project.structureNotes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Git Activity Stats
                if let metrics = project.gitMetrics {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Git Activity")
                            .font(.headline)

                        HStack(spacing: 16) {
                            // Last 7 days
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last 7 Days")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading) {
                                        Text("\(metrics.commits7d)")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                        Text("commits")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    VStack(alignment: .leading) {
                                        HStack(spacing: 4) {
                                            Text("+\(metrics.linesAdded7d)")
                                                .foregroundStyle(.green)
                                            Text("-\(metrics.linesRemoved7d)")
                                                .foregroundStyle(.red)
                                        }
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        Text("lines")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Last 30 days
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last 30 Days")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading) {
                                        Text("\(metrics.commits30d)")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                        Text("commits")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    VStack(alignment: .leading) {
                                        HStack(spacing: 4) {
                                            Text("+\(metrics.linesAdded30d)")
                                                .foregroundStyle(.green)
                                            Text("-\(metrics.linesRemoved30d)")
                                                .foregroundStyle(.red)
                                        }
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        Text("lines")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Repository info
                if let repoInfo = project.gitRepoInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repository")
                            .font(.headline)

                        if repoInfo.isGitRepo {
                            VStack(alignment: .leading, spacing: 6) {
                                repoInfoRow("Repository", repoInfo.displayName)
                                repoInfoRow("Branch", project.currentBranch ?? repoInfo.branch ?? "Unknown")

                                if let firstCommit = project.firstCommitDate {
                                    repoInfoRow("First Commit", firstCommit.formatted(date: .abbreviated, time: .omitted))
                                }

                                if let totalCommits = project.totalCommits {
                                    repoInfoRow("Total Commits", "\(totalCommits)")
                                }

                                if !project.branches.isEmpty && project.branches.count > 1 {
                                    repoInfoRow("Branches", "\(project.branches.count)")
                                }

                                repoInfoRow("Last Commit", repoInfo.lastCommitSubject ?? "Unknown")

                                if let remote = repoInfo.remoteURL {
                                    repoInfoRow("Remote", remote, allowSelection: true)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Text("Not a Git repo")
                                .foregroundStyle(.secondary)
                        }
                    }
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
                                .controlSize(.small)
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

        // Use pre-fetched commits with stats if available, otherwise fetch fresh
        if let metrics = project.gitMetrics, !metrics.recentCommits.isEmpty {
            commitHistory = metrics.recentCommits
        } else {
            commitHistory = GitService.shared.getRecentCommitsWithStats(at: project.path, limit: 20)
        }
    }

    private func formatLineCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM lines", Double(count) / 1_000_000.0)
        } else if count >= 1000 {
            return String(format: "%.1fk lines", Double(count) / 1000.0)
        }
        return "\(count) lines"
    }

    @ViewBuilder
    private func repoInfoRow(_ label: String, _ value: String, allowSelection: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .textSelectionEnabled(allowSelection)
        }
    }
}

private extension View {
    @ViewBuilder
    func textSelectionEnabled(_ enabled: Bool) -> some View {
        if enabled {
            self.textSelection(.enabled)
        } else {
            self.textSelection(.disabled)
        }
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
        case .paused: return .yellow
        case .experimental: return .blue
        case .archived: return .gray
        case .abandoned: return .gray
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
    var showStats: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            Text(commit.shortHash)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.blue)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(commit.shortMessage)
                    .font(.callout)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(commit.author)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if showStats && (commit.linesAdded > 0 || commit.linesRemoved > 0) {
                        HStack(spacing: 4) {
                            Text("+\(commit.linesAdded)")
                                .foregroundStyle(.green)
                            Text("-\(commit.linesRemoved)")
                                .foregroundStyle(.red)
                        }
                        .font(.caption2)
                        .fontWeight(.medium)
                    }
                }
            }

            Spacer()

            Text(commit.date.relativeString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// A layout that wraps items to new lines when they don't fit
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        let totalHeight = y + rowHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
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
        lastCommit: Commit(id: "abc123def456789", message: "Fix critical bug in authentication flow", author: "Caleb Belshe", date: Date()),
        techStack: ["Swift", "SwiftUI", "SwiftData", "Combine"],
        languageBreakdown: ["Swift": 12000, "JSON": 1500, "Markdown": 300],
        structure: "monorepo",
        totalCommits: 156,
        currentBranch: "main"
    ))
    .frame(width: 600, height: 800)
}
