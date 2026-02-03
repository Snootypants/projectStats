import AppKit
import SwiftUI

struct TerminalTabBar: View {
    @ObservedObject var viewModel: TerminalTabsViewModel

    @State private var renameTarget: TerminalTabItem?
    @State private var renameText: String = ""
    @State private var showRenamePrompt = false
    @State private var showAddMenu = false
    @State private var showServerPopover = false
    @State private var showCustomCommandSheet = false
    @State private var customCommand: String = ""

    var body: some View {
        VStack(spacing: 6) {
            ForEach(viewModel.tabs) { tab in
                TerminalTabButton(
                    tab: tab,
                    isActive: viewModel.activeTabID == tab.id,
                    onSelect: {
                        viewModel.selectTab(tab)
                    },
                    onCtrlSelect: {
                        if tab.kind == .devServer {
                            openDevServer(tab)
                        }
                    },
                    onCopyURL: {
                        if tab.kind == .devServer {
                            copyDevServer(tab)
                        }
                    }
                )
                .contextMenu {
                    Button("Rename") {
                        renameTarget = tab
                        renameText = tab.title
                        showRenamePrompt = true
                    }

                    Button("Duplicate") {
                        viewModel.duplicateTab(tab)
                    }

                    Divider()

                    Button("Clear Output") {
                        tab.clearOutput()
                    }

                    Button("Kill Process") {
                        tab.sendControlC()
                    }

                    if tab.kind != .shell {
                        Button("Close") {
                            viewModel.closeTab(tab)
                        }
                    }
                }
            }

            Spacer()

            Menu {
                Button("Dev Server: npm run dev") {
                    viewModel.addDevServerTab(command: "npm run dev")
                }
                Button("Dev Server: npm start") {
                    viewModel.addDevServerTab(command: "npm start")
                }
                Button("Dev Server: yarn dev") {
                    viewModel.addDevServerTab(command: "yarn dev")
                }
                Button("Dev Server: npx prisma studio") {
                    viewModel.addDevServerTab(command: "npx prisma studio")
                }
                Button("Dev Server: python manage.py runserver") {
                    viewModel.addDevServerTab(command: "python manage.py runserver")
                }
                Divider()
                Button("Custom Command...") {
                    showCustomCommandSheet = true
                }
            } label: {
                Text("+")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .padding(.bottom, 4)

            Button {
                showServerPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                    if !viewModel.runningServers.isEmpty {
                        Text("\(viewModel.runningServers.count)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showServerPopover, arrowEdge: .trailing) {
                RunningServersPopover(servers: viewModel.runningServers)
                    .frame(width: 260)
            }
        }
        .frame(width: 44)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
        .alert("Rename Tab", isPresented: $showRenamePrompt) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let target = renameTarget {
                    viewModel.renameTab(target, title: renameText)
                }
            }
        }
        .sheet(isPresented: $showCustomCommandSheet) {
            VStack(spacing: 16) {
                Text("Custom Command")
                    .font(.headline)

                TextField("Command", text: $customCommand)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)

                HStack {
                    Spacer()
                    Button("Cancel") {
                        showCustomCommandSheet = false
                        customCommand = ""
                    }
                    Button("Run") {
                        let trimmed = customCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            viewModel.addDevServerTab(command: trimmed)
                        }
                        showCustomCommandSheet = false
                        customCommand = ""
                    }
                }
            }
            .padding(20)
            .frame(width: 360)
        }
    }

    private func copyDevServer(_ tab: TerminalTabItem) {
        guard let port = tab.port else { return }
        let url = "http://localhost:\(port)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    private func openDevServer(_ tab: TerminalTabItem) {
        guard let port = tab.port else { return }
        let url = URL(string: "http://localhost:\(port)")!
        NSWorkspace.shared.open(url)
    }
}

private struct TerminalTabButton: View {
    @ObservedObject var tab: TerminalTabItem
    let isActive: Bool
    let onSelect: () -> Void
    let onCtrlSelect: () -> Void
    let onCopyURL: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .leading) {
            Button {
                onSelect()
                if tab.kind == .devServer {
                    onCopyURL()
                }
            } label: {
                VStack(spacing: 4) {
                    tabIcon
                    if tab.kind == .devServer, let port = tab.port {
                        Text(":\(port)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 36, height: 40)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .onTapGesture(modifiers: .control) {
                onCtrlSelect()
            }
            .onHover { hovering in
                isHovering = hovering
            }

            if isHovering {
                TerminalTabHoverCard(tab: tab)
                    .offset(x: -220)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    private var tabIcon: some View {
        ZStack(alignment: .topTrailing) {
            Text(tabLetter)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 18, height: 18)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            statusIndicator
                .offset(x: 6, y: -6)
        }
    }

    private var statusIndicator: some View {
        Group {
            switch tab.status {
            case .working:
                ProgressView()
                    .controlSize(.mini)
            case .idle:
                Circle().fill(Color.green).frame(width: 6, height: 6)
            case .error:
                Circle().fill(Color.red).frame(width: 6, height: 6)
            case .needsAttention:
                Circle().fill(Color.yellow).frame(width: 7, height: 7)
            }
        }
    }

    private var tabLetter: String {
        switch tab.kind {
        case .shell: return "T"
        case .claude: return "C"
        case .ccYolo: return "Y"
        case .devServer: return "D"
        case .ghost: return "G"
        }
    }
}

private struct TerminalTabHoverCard: View {
    @ObservedObject var tab: TerminalTabItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tab.title)
                .font(.system(size: 12, weight: .semibold))

            if let command = tab.devCommand, tab.kind == .devServer {
                Text(command)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if tab.kind == .devServer, let port = tab.port {
                Text("localhost:\(port)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if tab.kind == .devServer, let start = tab.startTime {
                Text("Running: \(runningDuration(from: start))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if tab.kind == .claude || tab.kind == .ccYolo {
                if let usage = ClaudeContextMonitor.shared.latestContextSummary {
                    Text("Context: \(usage.percentString)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text("Status: \(statusLabel)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if !tab.commandHistory.isEmpty {
                Text("Recent commands")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                ForEach(tab.commandHistory.prefix(3), id: \.self) { command in
                    Text(command)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 6)
    }

    private var statusLabel: String {
        switch tab.status {
        case .working: return "Working..."
        case .idle: return "Idle"
        case .error: return "Error"
        case .needsAttention: return "Needs attention"
        }
    }

    private func runningDuration(from start: Date) -> String {
        let interval = Int(Date().timeIntervalSince(start))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
