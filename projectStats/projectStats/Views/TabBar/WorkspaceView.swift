import SwiftUI

struct WorkspaceView: View {
    let projectPath: String
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel

    /// Resolve the Project from the path
    private var project: Project? {
        dashboardVM.projects.first { $0.path.path == projectPath }
    }

    var body: some View {
        if let project = project {
            VStack(spacing: 0) {
                // Workspace toolbar — back button + project info + actions
                workspaceToolbar(project: project)

                Divider()

                // Existing IDE Mode view (reused as-is)
                IDEModeView(project: project)
            }
            .onAppear {
                TerminalOutputMonitor.shared.activeProjectPath = project.path.path
            }
            .onDisappear {
                if TerminalOutputMonitor.shared.activeProjectPath == project.path.path {
                    TerminalOutputMonitor.shared.activeProjectPath = nil
                }
            }
        } else {
            // Project not found (maybe directory was deleted)
            VStack(spacing: 16) {
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Project not found")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(projectPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button("Go Back") {
                    tabManager.navigateBack()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func workspaceToolbar(project: Project) -> some View {
        HStack(spacing: 12) {
            // Back button
            Button {
                tabManager.navigateBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Projects")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Divider()
                .frame(height: 16)

            // Project name and status
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(for: project.status))
                    .frame(width: 8, height: 8)
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
            }

            // Branch indicator
            if let branch = project.currentBranch {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text(branch)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer()

            // Line count
            Text("\(project.formattedLineCount) lines")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }

    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .active: return .green
        case .inProgress: return .yellow
        case .paused: return .yellow
        case .experimental: return .blue
        case .dormant, .archived, .abandoned: return .gray
        }
    }
}
