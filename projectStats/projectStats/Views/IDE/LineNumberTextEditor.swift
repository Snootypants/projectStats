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

    // macOS 14+ defaults clipsToBounds to false — must set explicitly
    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        self.clipsToBounds = true
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.clipsToBounds = true
    }

    override var requiredThickness: CGFloat {
        guard let textView else { return 36 }
        let lineCount = max(textView.string.components(separatedBy: "\n").count, 1)
        let digits = max(String(lineCount).count, 2)
        return ceil(CGFloat(digits) * 8 + 16)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

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
        if visibleCharRange.location > 0 {
            text.enumerateSubstrings(in: NSRange(location: 0, length: visibleCharRange.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
                lineNumber += 1
            }
        }

        // Draw line numbers for visible lines
        text.enumerateSubstrings(in: visibleCharRange, options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            lineRect.origin.y += textView.textContainerInset.height

            // Convert from text view coordinates to ruler coordinates
            let rulerRect = self.convert(lineRect, from: textView)

            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: attrs)
            let x = self.bounds.width - labelSize.width - 8
            let y = rulerRect.origin.y + (rulerRect.height - labelSize.height) / 2

            label.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            lineNumber += 1
        }

        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

// MARK: - NSViewRepresentable Wrapper

struct LineNumberTextEditor: NSViewRepresentable {
    @Binding var text: String
    var readOnly: Bool = false
    var onScrollChange: ((CGFloat, CGFloat) -> Void)?  // (scrollOffset 0-1, visibleRange 0-1)
    var scrollTo: CGFloat?  // nil = no programmatic scroll, 0-1 = position

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Use Apple's factory method — creates a properly configured scrollable text view
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // --- Critical scrolling configuration ---
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.widthTracksTextView = true

        textView.isEditable = !readOnly
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        // Clip contents to bounds
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true

        // Set up line number ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        let ruler = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
        ruler.clientView = textView
        scrollView.verticalRulerView = ruler

        // Observe text changes for editing sync
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textDidChangeNotification(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )

        // Observe scroll position changes so ruler redraws on every scroll
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.rulerNeedsUpdate(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.rulerNeedsUpdate(_:)),
            name: NSView.frameDidChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.rulerNeedsUpdate(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text changed externally
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            scrollView.verticalRulerView?.needsDisplay = true
        }

        textView.isEditable = !readOnly

        // Programmatic scroll from minimap
        if let target = scrollTo {
            let docHeight = textView.frame.height
            let visibleHeight = scrollView.contentView.bounds.height
            if docHeight > visibleHeight {
                let y = target * (docHeight - visibleHeight)
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
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

        @objc func textDidChangeNotification(_ notification: Notification) {
            textDidChange(notification)
        }

        @objc func rulerNeedsUpdate(_ notification: Notification) {
            guard let tv = textView, let scrollView = tv.enclosingScrollView else { return }
            scrollView.verticalRulerView?.needsDisplay = true
            reportScrollPosition(scrollView: scrollView, textView: tv)
        }

        func reportScrollPosition(scrollView: NSScrollView, textView: NSTextView) {
            let docHeight = textView.frame.height
            let visibleHeight = scrollView.contentView.bounds.height
            guard docHeight > visibleHeight else {
                parent.onScrollChange?(0, 1)
                return
            }
            let offset = scrollView.contentView.bounds.origin.y / (docHeight - visibleHeight)
            let range = visibleHeight / docHeight
            parent.onScrollChange?(min(max(offset, 0), 1), min(range, 1))
        }
    }
}
