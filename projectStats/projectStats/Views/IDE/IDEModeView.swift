import SwiftUI

struct IDEModeView: View {
    let project: Project

    @State private var selectedFile: URL?
    @State private var openFiles: [OpenFile] = []
    @State private var activeFileID: UUID?
    @State private var activeTab: IDETab = .prompts
    @State private var sidebarWidth: CGFloat = 250

    private enum IDETab {
        case files
        case prompts
        case environment
    }

    var body: some View {
        GeometryReader { proxy in
            let idealTerminalWidth = max(320, proxy.size.width * 0.33)
            let maxTerminalWidth = max(420, proxy.size.width * 0.5)

            HSplitView {
                // Left sidebar - File Browser
                VStack(spacing: 0) {
                    // Project header
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        Text(project.name)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding()
                    .background(Color.primary.opacity(0.03))

                    Divider()

                    // File tree
                    FileBrowserView(
                        rootPath: project.path,
                        selectedFile: $selectedFile
                    )
                }
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 350)

                // Middle - Content
                VStack(spacing: 0) {
                // Toggle between File Viewer and Prompt Manager
                HStack(spacing: 0) {
                    Button {
                        activeTab = .files
                    } label: {
                        Label("Files", systemImage: "doc.text")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(activeTab == .files ? Color.accentColor.opacity(0.2) : Color.clear)
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeTab = .prompts
                    } label: {
                        Label("Prompts", systemImage: "text.badge.plus")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(activeTab == .prompts ? Color.accentColor.opacity(0.2) : Color.clear)
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeTab = .environment
                    } label: {
                        Label("Environment", systemImage: "key")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(activeTab == .environment ? Color.accentColor.opacity(0.2) : Color.clear)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                        // Quick actions
                        quickActions
                    }
                    .background(Color.primary.opacity(0.03))

                    Divider()

                    // Content
                switch activeTab {
                case .prompts:
                    PromptManagerView(projectPath: project.path)
                case .files:
                    FileViewerView(
                        openFiles: $openFiles,
                        activeFileID: $activeFileID
                    )
                case .environment:
                    EnvironmentManagerView(projectPath: project.path)
                }
            }
            .overlay(alignment: .leading) {
                panelDivider
            }

                // Right - Terminal Panel
                TerminalPanelView(projectPath: project.path)
                    .id(project.path)
                    .frame(minWidth: 280, idealWidth: idealTerminalWidth, maxWidth: maxTerminalWidth)
                    .overlay(alignment: .leading) {
                        panelDivider
                    }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onChange(of: selectedFile) { _, newValue in
            if let path = newValue {
                openFile(at: path)
                activeTab = .files
            }
        }
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.2))
            .frame(width: 1)
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            Button {
                openInVSCode()
            } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.plain)
            .help("Open in VSCode")

            Button {
                openInFinder()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.plain)
            .help("Open in Finder")

            Button {
                openInTerminal()
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.plain)
            .help("Open in Terminal")

            if let url = project.githubURL, let _ = URL(string: url) {
                Button {
                    openGitHub()
                } label: {
                    Image(systemName: "link")
                }
                .buttonStyle(.plain)
                .help("Open on GitHub")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - File Management

    private func openFile(at path: URL) {
        // Check if already open
        if let existing = openFiles.first(where: { $0.path == path }) {
            activeFileID = existing.id
            return
        }

        // Load content
        guard let content = try? String(contentsOf: path, encoding: .utf8) else { return }

        let newFile = OpenFile(path: path, content: content)
        openFiles.append(newFile)
        activeFileID = newFile.id
    }

    // MARK: - Quick Actions

    private func openInVSCode() {
        Shell.run("open -a 'Visual Studio Code' '\(project.path.path)'")
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path.path)
    }

    private func openInTerminal() {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(project.path.path)'"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    private func openGitHub() {
        guard let urlString = project.githubURL, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
