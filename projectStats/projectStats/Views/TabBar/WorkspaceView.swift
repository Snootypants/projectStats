import AppKit
import SwiftData
import SwiftUI

struct WorkspaceView: View {
    let projectPath: String
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @ObservedObject private var timeTrackingService = TimeTrackingService.shared
    @State private var showClaudeConfig = false
    @State private var isCreatingBackup = false
    @State private var backupMessage: String?
    @State private var showCreateBranchSheet = false
    @State private var showDocBuilder = false
    @State private var swarmEnabled = false
    @State private var showSwarmWarning = false
    @AppStorage("swarm.warningDismissed") private var swarmWarningDismissed = false

    /// Resolve the Project from the path
    private var project: Project? {
        dashboardVM.projects.first { $0.path.path == projectPath }
    }

    var body: some View {
        if let project = project {
            VStack(spacing: 0) {
                // Lockout bar — shows Claude plan usage at top of every workspace
                CompactLockoutBar()
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                // Workspace toolbar — back button + project info + actions
                workspaceToolbar(project: project)

                Divider()

                // Existing IDE Mode view (reused as-is)
                IDEModeView(project: project)
            }
            .onAppear {
                TerminalOutputMonitor.shared.activeProjectPath = project.path.path
                TimeTrackingService.shared.startTracking(project: project.path.path)
                swarmEnabled = AgentTeamsService.isSwarmEnabled(for: project.path.path)

                // Import prompts and work logs from /prompts and /work folders
                Task {
                    let context = AppModelContainer.shared.mainContext
                    await PromptImportService.shared.importPromptsIfNeeded(
                        for: project.path,
                        context: context
                    )
                    await PromptImportService.shared.importWorkLogsIfNeeded(
                        for: project.path,
                        context: context
                    )
                }

                Task {
                    await ClaudePlanUsageService.shared.fetchUsage()
                    await ClaudeContextMonitor.shared.refresh()
                    await ClaudeUsageService.shared.refreshProjectIfNeeded(project.path.path)
                    await DashboardViewModel.shared.syncSingleProject(path: project.path.path)
                }
            }
            .onDisappear {
                if TerminalOutputMonitor.shared.activeProjectPath == project.path.path {
                    TerminalOutputMonitor.shared.activeProjectPath = nil
                }
                TimeTrackingService.shared.stopTracking()
                Task {
                    await DashboardViewModel.shared.syncSingleProject(path: project.path.path)
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

                // Project time counter
                Text(timeTrackingService.projectTimeFormatted)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(4)
            }

            Spacer()

            Menu("Open In") {
                Button("VS Code") { openIn(app: "Visual Studio Code", project: project) }
                Button("Cursor") { openIn(app: "Cursor", project: project) }
                Button("Xcode") { openIn(app: "Xcode", project: project) }
                Button("Finder") { openInFinder(project: project) }
                Button("Terminal") { openInTerminal(project: project) }
                Divider()
                Button("Copy Path") { copyPath(project: project) }
            }
            .menuStyle(.borderlessButton)

            // VIBE button — toggles into vibe mode
            Button {
                tabManager.toggleVibeMode()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                    Text("VIBE")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)
            .help("Toggle VIBE mode (Cmd+Shift+V)")

            // Update Docs button
            Button {
                showDocBuilder = true
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
            }
            .buttonStyle(.plain)
            .help("Build documentation (Cmd+Shift+D)")

            // Backup button
            Button {
                createBackup(for: project)
            } label: {
                if isCreatingBackup {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "archivebox")
                }
            }
            .buttonStyle(.plain)
            .disabled(isCreatingBackup)
            .help(backupMessage ?? "Create zip backup in Downloads")

            // Branch button
            Button {
                showCreateBranchSheet = true
            } label: {
                Image(systemName: "arrow.triangle.branch")
            }
            .buttonStyle(.plain)
            .help("Create local branch copy")

            // Swarm toggle (only visible when Agent Teams is globally enabled)
            if SettingsViewModel.shared.agentTeamsEnabled {
                Button {
                    toggleSwarm(for: project)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: swarmEnabled ? "person.3.fill" : "person.3")
                        Text(swarmEnabled ? "SWARM" : "Swarm")
                            .font(.system(size: 11, weight: swarmEnabled ? .bold : .regular))
                    }
                    .foregroundStyle(swarmEnabled ? Color.orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(swarmEnabled ? "Swarm mode ON — SKILL.md deployed" : "Enable swarm mode for this project")
            }

            GitControlsView(projectPath: project.path)

            Button {
                showClaudeConfig = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Claude Config")

            Text("\(project.formattedLineCount) lines")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(projectStatsTooltip(project))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
        .sheet(isPresented: $showClaudeConfig) {
            ClaudeConfigSheet(projectPath: project.path)
        }
        .sheet(isPresented: $showDocBuilder) {
            DocBuilderSheet(project: project)
        }
        .alert("Agent Teams (Swarm)", isPresented: $showSwarmWarning) {
            Button("Enable") {
                actuallyEnableSwarm(true, for: project)
            }
            Button("Enable & Don't Ask Again") {
                swarmWarningDismissed = true
                actuallyEnableSwarm(true, for: project)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Agent Teams runs multiple Claude Code instances simultaneously. Each teammate consumes tokens independently, which can burn through your hourly rate limit 2–5x faster. Use intentionally.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDocBuilder)) { _ in
            showDocBuilder = true
        }
        .sheet(isPresented: $showCreateBranchSheet) {
            CreateBranchSheet(
                projectPath: project.path,
                onCreated: { branchPath in
                    showCreateBranchSheet = false
                    // Open the new branch folder in a new tab
                    tabManager.newTab()
                    tabManager.openProject(path: branchPath.path)
                },
                onCancel: { showCreateBranchSheet = false }
            )
        }
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

    private func openIn(app: String, project: Project) {
        Shell.run("open -a '\(app)' '\(project.path.path)'")
    }

    private func openInFinder(project: Project) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path.path)
    }

    private func openInTerminal(project: Project) {
        Shell.run("open -a 'Terminal' '\(project.path.path)'")
    }

    private func copyPath(project: Project) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(project.path.path, forType: .string)
    }

    private func projectStatsTooltip(_ project: Project) -> String {
        var lines: [String] = []
        lines.append("Lines: \(project.lineCount.formatted())")
        lines.append("Files: \(project.fileCount)")
        if let commits = project.totalCommits {
            lines.append("Commits: \(commits.formatted())")
        }
        if let language = project.language {
            lines.append("Language: \(language)")
        }
        if let commit = project.lastCommit {
            lines.append("Last commit: \(commit.message)")
        }
        return lines.joined(separator: "\n")
    }

    private func toggleSwarm(for project: Project) {
        let newState = !swarmEnabled

        // Show warning on first enable
        if newState && !swarmWarningDismissed {
            showSwarmWarning = true
            return
        }

        actuallyEnableSwarm(newState, for: project)
    }

    private func actuallyEnableSwarm(_ enabled: Bool, for project: Project) {
        swarmEnabled = enabled
        AgentTeamsService.setSwarmEnabled(enabled, for: project.path.path)

        if enabled {
            try? AgentTeamsService.deploySkillMd(to: project.path, projectName: project.name)
        }
        // Swarm OFF does NOT delete files
    }

    private func createBackup(for project: Project) {
        isCreatingBackup = true
        backupMessage = "Creating backup..."
        Task {
            do {
                let result = try await BackupService.shared.createBackup(for: project.path)
                BackupService.shared.revealInFinder(result.url)
                backupMessage = "Backup created: \(ByteCountFormatter.string(fromByteCount: result.size, countStyle: .file))"
            } catch {
                backupMessage = error.localizedDescription
            }
            isCreatingBackup = false
        }
    }
}
