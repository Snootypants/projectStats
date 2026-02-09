import AppKit
import SwiftUI

// MARK: - Line Number Ruler View

final class LineNumberRulerView: NSRulerView {
    private var textView: NSTextView? { clientView as? NSTextView }

    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private let textColor = NSColor.secondaryLabelColor
    private let backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.5)
    private let separatorColor = NSColor.separatorColor

    override var isFlipped: Bool { true }

    override var requiredThickness: CGFloat {
        guard let textView else { return 36 }
        let lineCount = max(textView.string.components(separatedBy: "\n").count, 1)
        let digits = max(String(lineCount).count, 2)
        return CGFloat(digits) * 8 + 12
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Clip drawing to bounds to prevent bleeding
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(rect: bounds).addClip()

        // Fill background
        backgroundColor.setFill()
        rect.fill()

        // Draw separator line
        separatorColor.setStroke()
        let sepX = bounds.maxX - 0.5
        NSBezierPath.strokeLine(from: NSPoint(x: sepX, y: rect.minY), to: NSPoint(x: sepX, y: rect.maxY))

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        let text = textView.string as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        var lineNumber = 1
        // Count lines before visible range
        text.enumerateSubstrings(in: NSRange(location: 0, length: visibleCharRange.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineNumber += 1
        }

        // Draw line numbers for visible lines
        text.enumerateSubstrings(in: visibleCharRange, options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            lineRect.origin.y += textView.textContainerInset.height

            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: attrs)
            let x = self.bounds.width - labelSize.width - 8
            let y = lineRect.origin.y + (lineRect.height - labelSize.height) / 2

            label.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            lineNumber += 1
        }

        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

// MARK: - Scroll View Subclass (prevents SwiftUI from expanding to full content size)

final class FlippedScrollView: NSScrollView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

// MARK: - NSViewRepresentable Wrapper

struct LineNumberTextEditor: NSViewRepresentable {
    @Binding var text: String
    var readOnly: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> FlippedScrollView {
        let scrollView = FlippedScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // Create text storage → layout manager → text container → text view
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = !readOnly
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.documentView = textView
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true

        // Set up line number ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        let ruler = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
        ruler.clientView = textView
        scrollView.verticalRulerView = ruler

        // Listen for text and selection changes to refresh line numbers
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: FlippedScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text changed externally
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            scrollView.verticalRulerView?.needsDisplay = true
        }

        textView.isEditable = !readOnly
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LineNumberTextEditor
        weak var textView: NSTextView?

        init(_ parent: LineNumberTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            tv.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }

        @objc func selectionDidChange(_ notification: Notification) {
            textView?.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }
    }
}
