import SwiftUI
import AppKit

struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectListViewModel
    @State private var selectedProjectID: UUID?
    @State private var showNewProjectWizard = false

    var body: some View {
        HSplitView {
            // Project list
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        showNewProjectWizard = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(8)
                }
                List(viewModel.filteredProjects, selection: $selectedProjectID) { project in
                    ProjectRowView(project: project)
                        .tag(project.id)
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 350)
            .sheet(isPresented: $showNewProjectWizard) {
                NewProjectWizard()
            }

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

// MARK: - Color Hex Extension for Project Cards

private extension Color {
    static func fromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255

        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Compact Project Card (Square for Overview Grid)
struct CompactProjectCard: View {
    let project: Project
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"
    @State private var isHovering = false

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    private var isArchived: Bool {
        !project.countsTowardTotals
    }

    private var archiveService: ProjectArchiveService { .shared }

    private var isFavorite: Bool {
        dashboardVM.isFavorite(project)
    }

    private var canToggleFavorite: Bool {
        isFavorite || dashboardVM.canAddFavorite
    }

    private var favoriteHelpText: String {
        if isFavorite { return "Unfavorite" }
        return canToggleFavorite ? "Favorite" : "Max 3 favorites"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with status and language
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                if let language = project.language {
                    Text(language)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if let metrics = project.gitMetrics, metrics.commits7d > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                            Text("\(metrics.commits7d)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    }

                    Button {
                        dashboardVM.toggleFavorite(project)
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(favoriteHelpText)
                    .disabled(!canToggleFavorite)
                }
            }

            // Project name
            Text(project.name)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            // Stats row
            HStack(spacing: 8) {
                Label(project.lastActivityString, systemImage: "clock")
                Spacer()
                Text("\(project.formattedLineCount)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            // Hover actions
            if isHovering {
                HStack(spacing: 6) {
                    Button {
                        openInEditor()
                    } label: {
                        Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button {
                        openInFinder()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    if project.githubURL != nil {
                        Button {
                            openGitHub()
                        } label: {
                            Image(systemName: "link")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
        }
        .padding(12)
        .frame(minHeight: 120)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isHovering ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: accentColor.opacity(0.25), radius: 12, x: 0, y: 4)
        .opacity(isArchived ? 0.6 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            projectContextMenu
        }
    }

    @ViewBuilder
    private var projectContextMenu: some View {
        Button(isArchived ? "Restore from Archive" : "Archive Project") {
            toggleArchiveStatus()
        }

        Divider()

        Button("Open in Finder") {
            openInFinder()
        }

        Button("Open in Editor") {
            openInEditor()
        }

        if project.githubURL != nil {
            Button("Open on GitHub") {
                openGitHub()
            }
        }
    }

    private func toggleArchiveStatus() {
        if isArchived {
            archiveService.restoreProject(project.path.path, context: modelContext)
        } else {
            archiveService.archiveProject(project.path.path, context: modelContext)
        }
        Task {
            await DashboardViewModel.shared.refresh()
        }
    }

    private var statusColor: Color {
        switch project.status {
        case .active: return .green
        case .inProgress: return .yellow
        case .dormant: return .gray
        case .paused: return .yellow
        case .experimental: return .blue
        case .archived: return .gray
        case .abandoned: return .gray
        }
    }

    private func openInEditor() {
        let editor = SettingsViewModel.shared.defaultEditor
        let appName: String

        switch editor {
        case .vscode:
            appName = "Visual Studio Code"
        case .cursor:
            appName = "Cursor"
        case .xcode:
            appName = "Xcode"
        case .sublime:
            appName = "Sublime Text"
        case .finder:
            openInFinder()
            return
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier(for: editor)) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([project.path], withApplicationAt: appURL, configuration: config)
        } else {
            _ = Shell.run("open -a \"\(appName)\" \"\(project.path.path)\"")
        }
    }

    private func bundleIdentifier(for editor: Editor) -> String {
        switch editor {
        case .vscode: return "com.microsoft.VSCode"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .xcode: return "com.apple.dt.Xcode"
        case .sublime: return "com.sublimetext.4"
        case .finder: return "com.apple.finder"
        }
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path.path)
    }

    private func openGitHub() {
        if let urlString = project.githubURL, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Full Project Card (for other uses)
struct ProjectCard: View {
    let project: Project
    @State private var isHovering = false

    private var isArchived: Bool {
        !project.countsTowardTotals
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(project.name)
                    .font(.system(size: 16, weight: .semibold))
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

                if let metrics = project.gitMetrics, metrics.commits7d > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                        Text("\(metrics.commits7d)")
                            .fontWeight(.medium)
                        if metrics.linesAdded7d > 0 || metrics.linesRemoved7d > 0 {
                            Text("+\(metrics.linesAdded7d)/-\(metrics.linesRemoved7d)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                } else {
                    Text("\(project.formattedLineCount) lines")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if isHovering {
                HStack(spacing: 8) {
                    Button("Open") {
                        openInEditor()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if project.githubURL != nil {
                        Button {
                            openGitHub()
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
        .opacity(isArchived ? 0.6 : 1.0)
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
        case .paused: return .yellow
        case .experimental: return .blue
        case .archived: return .gray
        case .abandoned: return .gray
        }
    }

    private func openInEditor() {
        let editor = SettingsViewModel.shared.defaultEditor
        let appName: String

        switch editor {
        case .vscode:
            appName = "Visual Studio Code"
        case .cursor:
            appName = "Cursor"
        case .xcode:
            appName = "Xcode"
        case .sublime:
            appName = "Sublime Text"
        case .finder:
            openInFinder()
            return
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier(for: editor)) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([project.path], withApplicationAt: appURL, configuration: config)
        } else {
            _ = Shell.run("open -a \"\(appName)\" \"\(project.path.path)\"")
        }
    }

    private func bundleIdentifier(for editor: Editor) -> String {
        switch editor {
        case .vscode: return "com.microsoft.VSCode"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .xcode: return "com.apple.dt.Xcode"
        case .sublime: return "com.sublimetext.4"
        case .finder: return "com.apple.finder"
        }
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path.path)
    }

    private func openGitHub() {
        if let urlString = project.githubURL, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    let vm = ProjectListViewModel()

    return ProjectListView(viewModel: vm)
        .frame(width: 900, height: 600)
        .environmentObject(DashboardViewModel())
}
