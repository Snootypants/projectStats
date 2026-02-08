import SwiftUI

struct SimpleFileNode: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    let name: String
    let isDirectory: Bool
    var children: [SimpleFileNode]?
}

struct SimpleFileBrowserView: View {
    let rootPath: URL
    @Binding var selectedFile: URL?

    @State private var rootNode: SimpleFileNode?
    @State private var expanded: Set<URL> = []
    @State private var isLoading = false
    @State private var searchText = ""
    @AppStorage("showHiddenFiles") private var showHiddenFiles: Bool = true

    private let excludedFolders: Set<String> = [
        "node_modules", ".git", ".next", "dist", "build",
        ".build", "DerivedData", "Pods", ".swiftpm",
        "__pycache__", ".venv", "venv", "target", ".idea"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                TextField("Filter files...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.03))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    } else if let root = rootNode {
                        let displayNode = filteredNode(root)
                        if let displayNode {
                            FileNodeRow(
                                node: displayNode,
                                level: 0,
                                expanded: searchText.isEmpty ? $expanded : .constant(allDirectoryURLs(in: displayNode)),
                                selectedFile: $selectedFile
                            )
                        } else {
                            Text("No matches")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(8)
                        }
                    } else {
                        Text("No files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            expanded = [rootPath]
            loadTree()
        }
        .onChange(of: rootPath) { _, _ in
            expanded = [rootPath]
            loadTree()
        }
        .onChange(of: showHiddenFiles) { _, _ in
            loadTree()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Files")
                .font(.system(size: 12, weight: .semibold))

            Spacer()

            Button {
                loadTree()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
    }

    private func loadTree() {
        isLoading = true
        Task.detached(priority: .utility) {
            let node = buildFileNode(at: rootPath, depth: 0)
            await MainActor.run {
                rootNode = node
                isLoading = false
            }
        }
    }

    private func filteredNode(_ node: SimpleFileNode) -> SimpleFileNode? {
        if searchText.isEmpty { return node }
        let query = searchText.lowercased()

        if node.isDirectory {
            let filteredChildren = node.children?.compactMap { filteredNode($0) } ?? []
            if !filteredChildren.isEmpty {
                return SimpleFileNode(url: node.url, name: node.name, isDirectory: true, children: filteredChildren)
            }
            if node.name.lowercased().contains(query) { return node }
            return nil
        } else {
            return node.name.lowercased().contains(query) ? node : nil
        }
    }

    private func allDirectoryURLs(in node: SimpleFileNode) -> Set<URL> {
        var urls: Set<URL> = []
        if node.isDirectory {
            urls.insert(node.url)
            for child in node.children ?? [] {
                urls.formUnion(allDirectoryURLs(in: child))
            }
        }
        return urls
    }

    private func buildFileNode(at url: URL, depth: Int) -> SimpleFileNode? {
        let fm = FileManager.default
        let name = url.lastPathComponent

        if !showHiddenFiles, name.hasPrefix(".") { return nil }
        if excludedFolders.contains(name) { return nil }

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }

        if isDir.boolValue {
            if depth >= 8 {
                return SimpleFileNode(url: url, name: name, isDirectory: true, children: [])
            }

            let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]
            let contents = (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: options
            )) ?? []

            let children = contents
                .sorted { (a, b) -> Bool in
                    let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if aIsDir != bIsDir { return aIsDir }
                    return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
                }
                .compactMap { buildFileNode(at: $0, depth: depth + 1) }

            return SimpleFileNode(url: url, name: name, isDirectory: true, children: children)
        }

        return SimpleFileNode(url: url, name: name, isDirectory: false, children: nil)
    }
}

private struct FileNodeRow: View {
    let node: SimpleFileNode
    let level: Int
    @Binding var expanded: Set<URL>
    @Binding var selectedFile: URL?

    private var isExpanded: Bool {
        expanded.contains(node.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if level > 0 {
                    Spacer()
                        .frame(width: CGFloat(level) * 14)
                }

                if node.isDirectory {
                    Button {
                        toggleExpanded()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 12)
                }

                Image(systemName: node.isDirectory ? "folder" : "doc.text")
                    .font(.system(size: 13))
                    .foregroundStyle(node.isDirectory ? .blue : .secondary)
                    .frame(width: 16)

                Text(node.name)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(selectedFile == node.url ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isDirectory {
                    toggleExpanded()
                } else {
                    selectedFile = node.url
                }
            }

            if node.isDirectory && isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileNodeRow(
                        node: child,
                        level: level + 1,
                        expanded: $expanded,
                        selectedFile: $selectedFile
                    )
                }
            }
        }
    }

    private func toggleExpanded() {
        if isExpanded {
            expanded.remove(node.url)
        } else {
            expanded.insert(node.url)
        }
    }
}
