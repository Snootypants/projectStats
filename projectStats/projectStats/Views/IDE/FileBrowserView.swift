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
    @State private var rootNode: FileNode?
    @State private var expandedPaths: Set<URL> = []

    // Folders to skip
    private let excludedFolders: Set<String> = [
        "node_modules", ".git", ".next", "dist", "build",
        ".build", "DerivedData", "Pods", ".swiftpm",
        "__pycache__", ".venv", "venv", "target", ".idea"
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let root = rootNode {
                    FileNodeView(
                        node: root,
                        selectedFile: $selectedFile,
                        expandedPaths: $expandedPaths,
                        level: 0
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear { loadFileTree() }
        .onChange(of: rootPath) { _, _ in loadFileTree() }
    }

    private func loadFileTree() {
        rootNode = buildFileNode(at: rootPath)
    }

    private func buildFileNode(at url: URL, depth: Int = 0) -> FileNode? {
        let fm = FileManager.default
        let name = url.lastPathComponent

        // Skip excluded folders
        if excludedFolders.contains(name) { return nil }

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }

        if isDir.boolValue {
            // Limit depth to prevent performance issues
            guard depth < 10 else { return FileNode(name: name, path: url, isDirectory: true, children: []) }

            let contents = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []

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
}

struct FileNodeView: View {
    let node: FileNode
    @Binding var selectedFile: URL?
    @Binding var expandedPaths: Set<URL>
    let level: Int

    private var isExpanded: Bool {
        expandedPaths.contains(node.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Indent based on level
                if level > 0 {
                    Spacer()
                        .frame(width: CGFloat(level) * 16)
                }

                // Expand/collapse for directories
                if node.isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                // Icon
                Image(systemName: node.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(node.iconColor)
                    .frame(width: 18)

                // Name
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

            // Children (if expanded)
            if node.isDirectory && isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileNodeView(
                        node: child,
                        selectedFile: $selectedFile,
                        expandedPaths: $expandedPaths,
                        level: level + 1
                    )
                }
            }
        }
    }
}
