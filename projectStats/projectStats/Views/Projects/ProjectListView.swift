import SwiftUI

struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectListViewModel
    @State private var selectedProjectID: UUID?

    var body: some View {
        HSplitView {
            // Project list
            List(viewModel.filteredProjects, selection: $selectedProjectID) { project in
                ProjectRowView(project: project)
                    .tag(project.id)
            }
            .listStyle(.inset)
            .frame(minWidth: 350)

            // Detail view
            if let selectedID = selectedProjectID,
               let project = viewModel.filteredProjects.first(where: { $0.id == selectedID }) {
                ProjectDetailView(project: project)
                    .frame(minWidth: 400)
            } else {
                VStack {
                    Image(systemName: "sidebar.squares.left")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a project")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct ProjectCard: View {
    let project: Project
    @StateObject private var projectListVM = ProjectListViewModel()
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let language = project.language {
                    Text(language)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            if let description = project.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Label(project.lastActivityString, systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(project.formattedLineCount) lines")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isHovering {
                HStack(spacing: 8) {
                    Button("Open") {
                        projectListVM.openInEditor(project)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if project.githubURL != nil {
                        Button {
                            projectListVM.openGitHub(project)
                        } label: {
                            Image(systemName: "link")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovering ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
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
}

#Preview {
    let vm = ProjectListViewModel()

    return ProjectListView(viewModel: vm)
        .frame(width: 900, height: 600)
}
