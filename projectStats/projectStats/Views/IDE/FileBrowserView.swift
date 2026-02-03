import AppKit
import SwiftUI

struct FileNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: URL
    let isDirectory: Bool
    var children: [FileNode]?
    var isExpanded: Bool = false

    var icon: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        return fileIcon(for: name)
    }

    var iconColor: Color {
        if isDirectory { return .blue }
        return fileColor(for: name)
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx": return "curlybraces"
        case "ts", "tsx": return "curlybraces"
        case "json": return "doc.text"
        case "md": return "doc.richtext"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "html": return "globe"
        case "css", "scss": return "paintbrush"
        case "yml", "yaml": return "doc.text"
        default: return "doc"
        }
    }

    private func fileColor(for name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "md": return .purple
        case "py": return .green
        case "json": return .gray
        default: return .secondary
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id
    }
}

struct FileBrowserView: View {
    let rootPath: URL
    @Binding var selectedFile: URL?
    var onImportEnvFile: ((URL) -> Void)?
    var onRequestDocUpdate: (() -> Void)?
    var onRefreshStats: (() -> Void)?

    @State private var rootNode: FileNode?
    @State private var expandedPaths: Set<URL> = []
    @State private var selectedFolder: URL?
    @AppStorage("showHiddenFiles") private var showHiddenFiles: Bool = false

    @State private var showNewFilePrompt = false
    @State private var showNewFolderPrompt = false
    @State private var newFileName = ""
    @State private var newFolderName = ""
    @State private var showRenamePrompt = false
    @State private var renameText = ""
    @State private var renameTarget: URL?
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: URL?

    // Folders to skip
    private let excludedFolders: Set<String> = [
        "node_modules", ".git", ".next", "dist", "build",
        ".build", "DerivedData", "Pods", ".swiftpm",
        "__pycache__", ".venv", "venv", "target", ".idea"
    ]

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let root = rootNode {
                        FileNodeView(
                            node: root,
                            selectedFile: $selectedFile,
                            selectedFolder: $selectedFolder,
                            expandedPaths: $expandedPaths,
                            level: 0,
                            actions: actions
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .onAppear { loadFileTree() }
        .onChange(of: rootPath) { _, _ in loadFileTree() }
        .alert("New File", isPresented: $showNewFilePrompt) {
            TextField("Filename", text: $newFileName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { createFile() }
        }
        .alert("New Folder", isPresented: $showNewFolderPrompt) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { createFolder() }
        }
        .alert("Rename", isPresented: $showRenamePrompt) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") { renameItem() }
        }
        .confirmationDialog("Delete", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { deleteItem() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move the item to Trash.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                showNewFilePrompt = true
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .buttonStyle(.plain)
            .help("New File")

            Button {
                showNewFolderPrompt = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.plain)
            .help("New Folder")

            Button {
                refreshTree()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button {
                showHiddenFiles.toggle()
                refreshTree()
            } label: {
                Image(systemName: showHiddenFiles ? "eye" : "eye.slash")
            }
            .buttonStyle(.plain)
            .help("Toggle Hidden")

            Button {
                expandedPaths.removeAll()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .buttonStyle(.plain)
            .help("Collapse All")

            Spacer()

            Button("Update Docs") {
                onRequestDocUpdate?()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
    }

    private var actions: FileBrowserActions {
        FileBrowserActions(
            rename: { url in
                renameTarget = url
                renameText = url.lastPathComponent
                showRenamePrompt = true
            },
            copy: { url in
                FileClipboard.shared.copy(url)
            },
            paste: { url in
                pasteClipboard(into: url)
            },
            duplicate: { url in
                duplicateItem(url)
            },
            delete: { url in
                deleteTarget = url
                showDeleteConfirm = true
            },
            reveal: { url in
                NSWorkspace.shared.activateFileViewerSelecting([url])
            },
            openInVSCode: { url in
                Shell.run("open -a 'Visual Studio Code' '\(url.path)'")
            },
            openInXcode: { url in
                Shell.run("open -a 'Xcode' '\(url.path)'")
            },
            openInTerminal: { url in
                let path = url.hasDirectoryPath ? url.path : url.deletingLastPathComponent().path
                Shell.run("open -a 'Terminal' '\(path)'")
            },
            copyPath: { url in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            },
            importEnv: { url in
                onImportEnvFile?(url)
            },
            pushEnvToKeychain: { url in
                pushEnvToKeychain(url)
            }
        )
    }

    private func refreshTree() {
        loadFileTree()
        onRefreshStats?()
    }

    private func loadFileTree() {
        rootNode = buildFileNode(at: rootPath)
    }

    private func buildFileNode(at url: URL, depth: Int = 0) -> FileNode? {
        let fm = FileManager.default
        let name = url.lastPathComponent

        if !showHiddenFiles, name.hasPrefix(".") {
            return nil
        }

        // Skip excluded folders
        if excludedFolders.contains(name) { return nil }

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }

        if isDir.boolValue {
            // Limit depth to prevent performance issues
            guard depth < 10 else { return FileNode(name: name, path: url, isDirectory: true, children: []) }

            let contents = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])) ?? []

            let children = contents
                .sorted { (a, b) -> Bool in
                    let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if aIsDir != bIsDir { return aIsDir }
                    return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
                }
                .compactMap { buildFileNode(at: $0, depth: depth + 1) }

            return FileNode(name: name, path: url, isDirectory: true, children: children)
        } else {
            return FileNode(name: name, path: url, isDirectory: false, children: nil)
        }
    }

    private func createFile() {
        let trimmed = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let directory = selectedFolder ?? rootPath
        let newURL = directory.appendingPathComponent(trimmed)
        FileManager.default.createFile(atPath: newURL.path, contents: nil)
        newFileName = ""
        refreshTree()
    }

    private func createFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let directory = selectedFolder ?? rootPath
        let newURL = directory.appendingPathComponent(trimmed)
        try? FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
        newFolderName = ""
        refreshTree()
    }

    private func renameItem() {
        guard let target = renameTarget else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newURL = target.deletingLastPathComponent().appendingPathComponent(trimmed)
        try? FileManager.default.moveItem(at: target, to: newURL)
        refreshTree()
    }

    private func deleteItem() {
        guard let target = deleteTarget else { return }
        _ = try? FileManager.default.trashItem(at: target, resultingItemURL: nil)
        refreshTree()
    }

    private func duplicateItem(_ url: URL) {
        let parent = url.deletingLastPathComponent()
        let destination = uniqueDestination(for: url, in: parent)
        try? FileManager.default.copyItem(at: url, to: destination)
        refreshTree()
    }

    private func pasteClipboard(into url: URL) {
        guard let source = FileClipboard.shared.contents else { return }
        let destinationFolder = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        let destination = uniqueDestination(for: source, in: destinationFolder)
        try? FileManager.default.copyItem(at: source, to: destination)
        refreshTree()
    }

    private func uniqueDestination(for source: URL, in directory: URL) -> URL {
        let baseName = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = directory.appendingPathComponent(source.lastPathComponent)
        var counter = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            let suffix = " copy\(counter == 1 ? "" : " \(counter)")"
            let filename = ext.isEmpty ? baseName + suffix : baseName + suffix + "." + ext
            candidate = directory.appendingPathComponent(filename)
            counter += 1
        }

        return candidate
    }

    private func pushEnvToKeychain(_ url: URL) {
        let envService = EnvFileService()
        let variables = envService.parseEnvFile(at: url)
        let projectName = rootPath.lastPathComponent

        for variable in variables where !variable.key.isEmpty {
            let key = "\(projectName):\(variable.key)"
            _ = KeychainService.shared.setSecret(variable.value, forKey: key)
        }
    }
}

struct FileBrowserActions {
    let rename: (URL) -> Void
    let copy: (URL) -> Void
    let paste: (URL) -> Void
    let duplicate: (URL) -> Void
    let delete: (URL) -> Void
    let reveal: (URL) -> Void
    let openInVSCode: (URL) -> Void
    let openInXcode: (URL) -> Void
    let openInTerminal: (URL) -> Void
    let copyPath: (URL) -> Void
    let importEnv: (URL) -> Void
    let pushEnvToKeychain: (URL) -> Void
}

struct FileNodeView: View {
    let node: FileNode
    @Binding var selectedFile: URL?
    @Binding var selectedFolder: URL?
    @Binding var expandedPaths: Set<URL>
    let level: Int
    let actions: FileBrowserActions

    private var isExpanded: Bool {
        expandedPaths.contains(node.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if level > 0 {
                    Spacer()
                        .frame(width: CGFloat(level) * 16)
                }

                if node.isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                Image(systemName: node.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(node.iconColor)
                    .frame(width: 18)

                Text(node.name)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(selectedFile == node.path ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isDirectory {
                    selectedFolder = node.path
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isExpanded {
                            expandedPaths.remove(node.path)
                        } else {
                            expandedPaths.insert(node.path)
                        }
                    }
                } else {
                    selectedFile = node.path
                }
            }
            .contextMenu { contextMenu }

            if node.isDirectory && isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileNodeView(
                        node: child,
                        selectedFile: $selectedFile,
                        selectedFolder: $selectedFolder,
                        expandedPaths: $expandedPaths,
                        level: level + 1,
                        actions: actions
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Rename") { actions.rename(node.path) }
        Button("Copy") { actions.copy(node.path) }
        Button("Paste") { actions.paste(node.path) }
        Button("Duplicate") { actions.duplicate(node.path) }

        Divider()

        Button("Delete") { actions.delete(node.path) }

        Divider()

        Button("Reveal in Finder") { actions.reveal(node.path) }
        Button("Open in VS Code") { actions.openInVSCode(node.path) }
        Button("Open in Xcode") { actions.openInXcode(node.path) }
        Button("Open in Terminal") { actions.openInTerminal(node.path) }

        Divider()

        Button("Copy Path") { actions.copyPath(node.path) }

        if node.name.hasPrefix(".env") {
            Divider()
            Button("Import to Env Manager") { actions.importEnv(node.path) }
            Button("Push Values to Keychain") { actions.pushEnvToKeychain(node.path) }
        }
    }
}

final class FileClipboard {
    static let shared = FileClipboard()
    private(set) var contents: URL?

    func copy(_ url: URL) {
        contents = url
    }
}
