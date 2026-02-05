import AppKit
import SwiftUI

// MARK: - Line Numbered Text View (NSViewRepresentable)

struct LineNumberedTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    var onSave: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = LineNumberTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = font
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.delegate = context.coordinator
        textView.string = text

        // Configure for horizontal scrolling (no word wrap)
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView

        // Add line number ruler
        let rulerView = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.rulerView = rulerView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        context.coordinator.rulerView?.needsDisplay = true
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LineNumberedTextView
        weak var textView: NSTextView?
        weak var rulerView: LineNumberRulerView?

        init(_ parent: LineNumberedTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            rulerView?.needsDisplay = true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Cmd+S for save
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                return false
            }
            return false
        }
    }
}

// MARK: - Line Number Ruler View

class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let lineNumberFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    private let gutterWidth: CGFloat = 40

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.ruleThickness = gutterWidth
        self.clientView = textView

        // Observe text changes and scroll
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(boundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    @objc private func boundsDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Background
        NSColor.textBackgroundColor.set()
        rect.fill()

        // Draw separator line
        NSColor.separatorColor.set()
        let separatorRect = NSRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height)
        separatorRect.fill()

        let content = textView.string as NSString
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Find starting line number
        var lineNumber = 1
        var index = 0
        while index < characterRange.location && index < content.length {
            if content.character(at: index) == 0x0A { // newline
                lineNumber += 1
            }
            index += 1
        }

        // Draw line numbers
        let attributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        var currentIndex = characterRange.location
        while currentIndex < NSMaxRange(characterRange) {
            let lineRange = content.lineRange(for: NSRange(location: currentIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            lineRect.origin.y += textView.textContainerInset.height - visibleRect.origin.y

            let lineString = "\(lineNumber)"
            let stringSize = lineString.size(withAttributes: attributes)
            let drawPoint = NSPoint(
                x: gutterWidth - stringSize.width - 8,
                y: lineRect.origin.y + (lineRect.height - stringSize.height) / 2
            )

            lineString.draw(at: drawPoint, withAttributes: attributes)

            lineNumber += 1
            currentIndex = NSMaxRange(lineRange)
            if currentIndex >= content.length { break }
        }
    }
}

// Custom NSTextView subclass for handling save shortcut
class LineNumberTextView: NSTextView {
    var onSave: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "s" {
            onSave?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Open File Model

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
        LineNumberedTextView(text: $file.content, onSave: onSave)
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
