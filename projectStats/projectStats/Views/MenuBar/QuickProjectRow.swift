import SwiftUI

struct QuickProjectRow: View {
    let project: Project
    @State private var isHovering = false
    @StateObject private var projectListVM = ProjectListViewModel()

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Project info
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(project.lastActivityString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if project.lineCount > 0 {
                        Text("\(project.formattedLineCount) lines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let language = project.language {
                        Text(language)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }

            Spacer()

            // Quick actions (shown on hover)
            if isHovering {
                HStack(spacing: 4) {
                    Button {
                        projectListVM.openInEditor(project)
                    } label: {
                        Image(systemName: "rectangle.and.pencil.and.ellipsis")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Open in Editor")

                    if project.githubURL != nil {
                        Button {
                            projectListVM.openGitHub(project)
                        } label: {
                            Image(systemName: "link")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Open on GitHub")

                        Button {
                            projectListVM.copyGitHubURL(project)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Copy URL")
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            projectListVM.openInFinder(project)
        }
    }

    private var statusColor: Color {
        switch project.status {
        case .active: return .green
        case .inProgress: return .yellow
        case .dormant: return .gray
        }
    }
}

#Preview {
    QuickProjectRow(project: Project(
        path: URL(fileURLWithPath: "/Users/test/Code/myproject"),
        name: "myproject",
        description: "A test project",
        githubURL: "https://github.com/test/myproject",
        language: "Swift",
        lineCount: 5000,
        fileCount: 42
    ))
    .frame(width: 320)
    .padding()
}
