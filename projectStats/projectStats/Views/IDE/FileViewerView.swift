import SwiftUI

struct OpenFile: Identifiable, Equatable {
    let id = UUID()
    let path: URL
    var content: String
    var originalContent: String
    var hasChanges: Bool { content != originalContent }

    var name: String { path.lastPathComponent }

    init(path: URL, content: String) {
        self.path = path
        self.content = content
        self.originalContent = content
    }

    static func == (lhs: OpenFile, rhs: OpenFile) -> Bool {
        lhs.path == rhs.path
    }

    mutating func markSaved() {
        originalContent = content
    }
}

struct FileViewerView: View {
    @Binding var openFiles: [OpenFile]
    @Binding var activeFileID: UUID?

    var activeFileIndex: Int? {
        guard let id = activeFileID else { return openFiles.indices.first }
        return openFiles.firstIndex { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if !openFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(openFiles) { file in
                            FileTab(
                                file: file,
                                isActive: file.id == (activeFileID ?? openFiles.first?.id),
                                hasChanges: file.hasChanges,
                                onSelect: { activeFileID = file.id },
                                onClose: { closeFile(file) }
                            )
                        }
                    }
                }
                .background(Color.primary.opacity(0.05))

                Divider()
            }

            // Editor content
            if let index = activeFileIndex {
                FileEditorView(
                    file: $openFiles[index],
                    onSave: { saveFile(at: index) }
                )
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a file to edit")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private func closeFile(_ file: OpenFile) {
        if let index = openFiles.firstIndex(of: file) {
            openFiles.remove(at: index)
            if activeFileID == file.id {
                activeFileID = openFiles.first?.id
            }
        }
    }

    private func saveFile(at index: Int) {
        let file = openFiles[index]
        do {
            try file.content.write(to: file.path, atomically: true, encoding: .utf8)
            openFiles[index].markSaved()
            print("[Editor] Saved: \(file.path.lastPathComponent)")
        } catch {
            print("[Editor] Error saving file: \(error)")
        }
    }
}

struct FileEditorView: View {
    @Binding var file: OpenFile
    let onSave: () -> Void

    var body: some View {
        TextEditor(text: $file.content)
            .font(.system(size: 12, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
            .background {
                // Hidden save button for keyboard shortcut
                Button("") { onSave() }
                    .keyboardShortcut("s", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
            }
    }
}

struct FileTab: View {
    let file: OpenFile
    let isActive: Bool
    let hasChanges: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(file.name)
                .font(.system(size: 12))
                .lineLimit(1)

            if hasChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .help("Unsaved changes")
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || hasChanges ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.primary.opacity(0.1) : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(isActive ? Color.accentColor : Color.clear),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }
}
