import SwiftUI

struct ProjectRowView: View {
    let project: Project
    @StateObject private var projectListVM = ProjectListViewModel()
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            VStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
            }
            .frame(width: 16)

            // Project info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.name)
                        .font(.system(.body, weight: .medium))

                    if let language = project.language {
                        Text(language)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(languageColor.opacity(0.15))
                            .foregroundStyle(languageColor)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 12) {
                    Label(project.lastActivityString, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("\(project.formattedLineCount) lines", systemImage: "text.alignleft")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if project.fileCount > 0 {
                        Label("\(project.fileCount) files", systemImage: "doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let description = project.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Badges
            HStack(spacing: 6) {
                if project.promptCount > 0 {
                    Badge(text: "\(project.promptCount) prompts", color: .purple)
                }

                if project.workLogCount > 0 {
                    Badge(text: "\(project.workLogCount) logs", color: .orange)
                }

                if project.githubURL != nil {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            // Quick actions (shown on hover)
            if isHovering {
                HStack(spacing: 4) {
                    Button {
                        projectListVM.openInEditor(project)
                    } label: {
                        Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Editor")

                    Button {
                        projectListVM.openInFinder(project)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")

                    if project.githubURL != nil {
                        Button {
                            projectListVM.openGitHub(project)
                        } label: {
                            Image(systemName: "safari")
                        }
                        .buttonStyle(.borderless)
                        .help("Open on GitHub")
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }

    private var statusColor: Color {
        switch project.status {
        case .active: return .green
        case .inProgress: return .yellow
        case .dormant: return .gray
        }
    }

    private var languageColor: Color {
        switch project.language?.lowercased() {
        case "swift": return .orange
        case "typescript", "javascript": return .yellow
        case "python": return .blue
        case "rust": return .orange
        case "go": return .cyan
        case "ruby": return .red
        case "java", "kotlin": return .purple
        default: return .gray
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    List {
        ProjectRowView(project: Project(
            path: URL(fileURLWithPath: "/Users/test/Code/myproject"),
            name: "myproject",
            description: "A comprehensive test project for demonstration purposes",
            githubURL: "https://github.com/test/myproject",
            language: "Swift",
            lineCount: 15420,
            fileCount: 87,
            promptCount: 3,
            workLogCount: 12,
            lastCommit: Commit(id: "abc123", message: "Fix bug", author: "Test", date: Date())
        ))

        ProjectRowView(project: Project(
            path: URL(fileURLWithPath: "/Users/test/Code/another"),
            name: "another-project",
            description: nil,
            githubURL: nil,
            language: "TypeScript",
            lineCount: 8234,
            fileCount: 156
        ))
    }
    .listStyle(.inset)
    .frame(width: 500, height: 300)
}
