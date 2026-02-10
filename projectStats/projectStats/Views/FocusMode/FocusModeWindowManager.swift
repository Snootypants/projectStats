import AppKit

// MARK: - DORMANT — Deprecated empty stub. Safe to delete.
/// DEPRECATED — Focus Mode now uses SwiftUI overlay in TabShellView, not a separate NSWindow.
/// The previous NSWindow approach used .screenSaver window level which locked out
/// macOS Force Quit dialog and bricked the desktop. Never do that again.
@MainActor
final class FocusModeWindowManager {
    static let shared = FocusModeWindowManager()
}
