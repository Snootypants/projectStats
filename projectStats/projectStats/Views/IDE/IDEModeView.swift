import AppKit
import SwiftUI

struct IDEModeView: View {
    let project: Project

    @StateObject private var terminalTabs: TerminalTabsViewModel
    @StateObject private var environmentViewModel: EnvironmentViewModel

    @State private var selectedFile: URL?
    @State private var openFiles: [OpenFile] = []
    @State private var activeFileID: UUID?
    @State private var activeTab: IDETab = .prompts

    @AppStorage("workspace.terminalWidth") private var terminalWidth: Double = 450
    @AppStorage("workspace.explorerWidth") private var explorerWidth: Double = 200
    @AppStorage("workspace.viewerWidth") private var viewerWidth: Double = 450
    @AppStorage("workspace.showTerminal") private var showTerminal: Bool = true
    @AppStorage("workspace.showExplorer") private var showExplorer: Bool = true
    @AppStorage("workspace.showViewer") private var showViewer: Bool = true

    @State private var dragStartTerminal: (CGFloat, CGFloat, CGFloat)?
    @State private var dragStartExplorer: (CGFloat, CGFloat, CGFloat)?

    private enum IDETab {
        case files
        case prompts
        case environment
    }

    init(project: Project) {
        self.project = project
        _terminalTabs = StateObject(wrappedValue: TerminalTabsViewModel(projectPath: project.path))
        _environmentViewModel = StateObject(wrappedValue: EnvironmentViewModel(projectPath: project.path))
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = layoutWidths(totalWidth: proxy.size.width)

            HStack(spacing: 0) {
                if showTerminal {
                    TerminalPanelView(viewModel: terminalTabs)
                        .frame(width: layout.terminal)
                }

                if showTerminal && showExplorer {
                    ResizableDivider { delta in
                        adjustTerminalDivider(delta: delta, layout: layout)
                    } onEnd: {
                        dragStartTerminal = nil
                    } onDoubleTap: {
                        terminalWidth = 450
                    }
                }

                if showExplorer {
                    FileBrowserView(
                        rootPath: project.path,
                        selectedFile: $selectedFile,
                        onImportEnvFile: { url in
                            environmentViewModel.importEnvFile(at: url)
                            activeTab = .environment
                        },
                        onRequestDocUpdate: {
                            terminalTabs.addGhostDocUpdateTab()
                        },
                        onRefreshStats: {
                            Task { await DashboardViewModel.shared.syncSingleProject(path: project.path.path) }
                        }
                    )
                    .frame(width: layout.explorer)
                }

                if (showExplorer && showViewer) || (showTerminal && showViewer && !showExplorer) {
                    ResizableDivider { delta in
                        adjustExplorerDivider(delta: delta, layout: layout)
                    } onEnd: {
                        dragStartExplorer = nil
                    } onDoubleTap: {
                        explorerWidth = 200
                    }
                }

                if showViewer {
                    viewerColumn
                        .frame(width: layout.viewer)
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
        .onReceive(NotificationCenter.default.publisher(for: .requestDocUpdate)) { notification in
            guard let path = notification.userInfo?["projectPath"] as? String,
                  path == project.path.path else { return }
            terminalTabs.addGhostDocUpdateTab()
        }
        .background {
            keyboardShortcuts
        }
    }

    private var viewerColumn: some View {
        VStack(spacing: 0) {
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
            }
            .background(Color.primary.opacity(0.03))

            Divider()

            switch activeTab {
            case .prompts:
                PromptManagerView(projectPath: project.path)
            case .files:
                FileViewerView(openFiles: $openFiles, activeFileID: $activeFileID)
            case .environment:
                EnvironmentManagerView(viewModel: environmentViewModel)
            }
        }
    }

    private var keyboardShortcuts: some View {
        Group {
            Button("") { showTerminal.toggle() }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button("") { showExplorer.toggle() }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button("") { showViewer.toggle() }
                .keyboardShortcut("3", modifiers: [.command, .shift])
            Button("") { showExplorer.toggle() }
                .keyboardShortcut("b", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    private func layoutWidths(totalWidth: CGFloat) -> (terminal: CGFloat, explorer: CGFloat, viewer: CGFloat) {
        let minTerminal: CGFloat = 300
        let minExplorer: CGFloat = 150
        let minViewer: CGFloat = 300
        let dividerWidth: CGFloat = 6

        let visibleCount = [showTerminal, showExplorer, showViewer].filter { $0 }.count
        let available = totalWidth - CGFloat(max(0, visibleCount - 1)) * dividerWidth

        var terminal = showTerminal ? CGFloat(terminalWidth) : 0
        var explorer = showExplorer ? CGFloat(explorerWidth) : 0
        var viewer = showViewer ? CGFloat(viewerWidth) : 0

        if showTerminal && showExplorer && showViewer {
            terminal = min(max(terminal, minTerminal), available - minExplorer - minViewer)
            explorer = min(max(explorer, minExplorer), available - terminal - minViewer)
            viewer = max(minViewer, available - terminal - explorer)
        } else if showTerminal && showExplorer {
            let total = max(terminal + explorer, 1)
            terminal = available * (terminal / total)
            explorer = available - terminal
        } else if showTerminal && showViewer {
            terminal = min(max(terminal, minTerminal), available - minViewer)
            viewer = max(minViewer, available - terminal)
        } else if showExplorer && showViewer {
            explorer = min(max(explorer, minExplorer), available - minViewer)
            viewer = max(minViewer, available - explorer)
        } else if showTerminal {
            terminal = available
        } else if showExplorer {
            explorer = available
        } else if showViewer {
            viewer = available
        }

        return (terminal, explorer, viewer)
    }

    private func adjustTerminalDivider(delta: CGFloat, layout: (terminal: CGFloat, explorer: CGFloat, viewer: CGFloat)) {
        let minTerminal: CGFloat = 300
        let minExplorer: CGFloat = 150
        let minViewer: CGFloat = 300

        if dragStartTerminal == nil {
            dragStartTerminal = (layout.terminal, layout.explorer, layout.viewer)
        }

        guard let start = dragStartTerminal else { return }
        var newTerminal = start.0 + delta
        var newExplorer = start.1 - delta
        var newViewer = start.2

        newTerminal = max(minTerminal, newTerminal)

        if showExplorer {
            newExplorer = max(minExplorer, newExplorer)
        } else if showViewer {
            newViewer = max(minViewer, newViewer - delta)
        }

        terminalWidth = Double(newTerminal)
        explorerWidth = Double(newExplorer)
        viewerWidth = Double(newViewer)
    }

    private func adjustExplorerDivider(delta: CGFloat, layout: (terminal: CGFloat, explorer: CGFloat, viewer: CGFloat)) {
        let minExplorer: CGFloat = 150
        let minViewer: CGFloat = 300

        if dragStartExplorer == nil {
            dragStartExplorer = (layout.terminal, layout.explorer, layout.viewer)
        }

        guard let start = dragStartExplorer else { return }
        if !showExplorer && showTerminal {
            var newTerminal = start.0 + delta
            var newViewer = start.2 - delta
            newTerminal = max(300, newTerminal)
            newViewer = max(minViewer, newViewer)
            terminalWidth = Double(newTerminal)
            viewerWidth = Double(newViewer)
            return
        }

        var newExplorer = start.1 + delta
        var newViewer = start.2 - delta

        newExplorer = max(minExplorer, newExplorer)
        newViewer = max(minViewer, newViewer)

        explorerWidth = Double(newExplorer)
        viewerWidth = Double(newViewer)
    }

    private func openFile(at path: URL) {
        if let existing = openFiles.first(where: { $0.path == path }) {
            activeFileID = existing.id
            return
        }

        guard let content = try? String(contentsOf: path, encoding: .utf8) else { return }

        let newFile = OpenFile(path: path, content: content)
        openFiles.append(newFile)
        activeFileID = newFile.id
    }
}

private struct ResizableDivider: View {
    let onDrag: (CGFloat) -> Void
    let onEnd: () -> Void
    let onDoubleTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .overlay(
                Rectangle()
                    .fill(isHovering ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.2))
                    .frame(width: isHovering ? 3 : 1)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onDrag(value.translation.width)
                    }
                    .onEnded { _ in
                        onEnd()
                    }
            )
            .onTapGesture(count: 2) {
                onDoubleTap()
            }
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
