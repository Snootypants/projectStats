import SwiftUI

struct SimpleFileViewerView: View {
    @Binding var fileURL: URL?

    @State private var content: String = ""
    @State private var originalContent: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadToken = UUID()

    private let maxPreviewBytes: Int = 2 * 1024 * 1024
    private enum FileReadError: Error, LocalizedError {
        case notRegularFile
        case tooLarge(String)
        case binaryUnsupported
        case readFailed(String)

        var errorDescription: String? {
            switch self {
            case .notRegularFile:
                return "This item isn't a regular file."
            case .tooLarge(let size):
                return "File is \(size), which is too large to preview here."
            case .binaryUnsupported:
                return "Binary files aren't supported in the preview."
            case .readFailed(let message):
                return message
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            contentView
        }
        .onAppear(perform: loadIfNeeded)
        .onChange(of: fileURL) { _, _ in
            loadIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(fileURL?.lastPathComponent ?? "No file selected")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            if hasChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            Button("Save") {
                saveFile()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(fileURL == nil || isLoading || errorMessage != nil || !hasChanges)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
    }

    @ViewBuilder
    private var contentView: some View {
        if fileURL == nil {
            placeholderView(
                icon: "doc.text",
                title: "Select a file to view",
                message: "Choose a file from the left panel."
            )
        } else if isLoading {
            placeholderView(
                icon: "hourglass",
                title: "Loading…",
                message: "Reading file contents."
            )
        } else if let errorMessage = errorMessage {
            placeholderView(
                icon: "exclamationmark.triangle.fill",
                title: "Unable to preview",
                message: errorMessage
            )
        } else {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    LineNumberTextEditor(text: $content, readOnly: false)
                        .frame(width: geo.size.width - (content.isEmpty ? 0 : 60), height: geo.size.height)
                    if !content.isEmpty {
                        MinimapView(
                            text: content,
                            visibleRange: 0.3,
                            scrollOffset: 0,
                            onScroll: { _ in }
                        )
                    }
                }
            }
        }
    }

    private var hasChanges: Bool {
        content != originalContent
    }

    private func loadIfNeeded() {
        guard let url = fileURL else {
            content = ""
            originalContent = ""
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        let token = UUID()
        loadToken = token

        Task.detached(priority: .userInitiated) {
            let result = readFile(at: url, maxBytes: maxPreviewBytes)
            await MainActor.run {
                guard loadToken == token else { return }
                switch result {
                case .success(let text):
                    content = text
                    originalContent = text
                    errorMessage = nil
                case .failure(let message):
                    content = ""
                    originalContent = ""
                    errorMessage = message.localizedDescription
                }
                isLoading = false
            }
        }
    }

    private func saveFile() {
        guard let url = fileURL else { return }
        let textToSave = content
        isLoading = true

        Task.detached(priority: .userInitiated) {
            do {
                try textToSave.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run {
                    originalContent = textToSave
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func readFile(at url: URL, maxBytes: Int) -> Result<String, FileReadError> {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            if let type = attrs[.type] as? FileAttributeType, type != .typeRegular {
                return .failure(.notRegularFile)
            }

            let knownSize = (attrs[.size] as? NSNumber)?.intValue ?? 0
            if knownSize == 0 {
                return .success("")
            }

            if knownSize > maxBytes {
                let prettySize = ByteCountFormatter.string(fromByteCount: Int64(knownSize), countStyle: .file)
                return .failure(.tooLarge(prettySize))
            }

            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }

            let data = try handle.read(upToCount: maxBytes + 1) ?? Data()
            if data.count > maxBytes {
                return .failure(.tooLarge("larger than \(maxBytes) bytes"))
            }

            if data.prefix(4096).contains(0) {
                return .failure(.binaryUnsupported)
            }

            let text = String(decoding: data, as: UTF8.self)
            return .success(text)
        } catch {
            return .failure(.readFailed(error.localizedDescription))
        }
    }

    @ViewBuilder
    private func placeholderView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
