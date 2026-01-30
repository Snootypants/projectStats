import SwiftUI

struct OpenFile: Identifiable, Equatable {
    let id = UUID()
    let path: URL
    var content: String

    var name: String { path.lastPathComponent }

    static func == (lhs: OpenFile, rhs: OpenFile) -> Bool {
        lhs.path == rhs.path
    }
}

struct FileViewerView: View {
    @Binding var openFiles: [OpenFile]
    @Binding var activeFileID: UUID?

    var activeFile: OpenFile? {
        guard let id = activeFileID else { return openFiles.first }
        return openFiles.first { $0.id == id }
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
                                onSelect: { activeFileID = file.id },
                                onClose: { closeFile(file) }
                            )
                        }
                    }
                }
                .background(Color.primary.opacity(0.05))

                Divider()
            }

            // Content
            if let file = activeFile {
                ScrollView {
                    Text(file.content)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a file to view")
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
}

struct FileTab: View {
    let file: OpenFile
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(file.name)
                .font(.system(size: 12))
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
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
