import AppKit
import SwiftUI

@MainActor
final class FocusModeWindowManager {
    static let shared = FocusModeWindowManager()
    private var window: NSWindow?
    private var eventMonitor: Any?

    func showFullscreen(terminalMonitor: TerminalOutputMonitor, usageMonitor: ClaudePlanUsageService) {
        guard window == nil else { return }

        let view = FocusModeView(terminalMonitor: terminalMonitor, usageMonitor: usageMonitor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        let hostingView = NSHostingView(rootView: view)

        let win = NSWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentView = hostingView
        win.level = .screenSaver
        win.backgroundColor = .black
        win.isOpaque = true
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.makeKeyAndOrderFront(nil)

        if let screen = NSScreen.main {
            win.setFrame(screen.frame, display: true)
        }

        self.window = win

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                return nil
            }
            if event.modifierFlags.contains([.command, .shift]),
               event.charactersIgnoringModifiers == "g" {
                NotificationCenter.default.post(name: .toggleScrollingPrompt, object: nil)
                return nil
            }
            return event
        }
    }

    func dismiss() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        window?.close()
        window = nil
    }
}
