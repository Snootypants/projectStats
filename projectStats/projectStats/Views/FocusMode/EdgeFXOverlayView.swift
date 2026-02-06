import SwiftUI

struct EdgeFXOverlayView: NSViewRepresentable {
    var mode: EdgeFXOverlay.Mode = .fire
    var intensity: CGFloat = 1.0

    func makeNSView(context: Context) -> EdgeFXOverlay {
        let overlay = EdgeFXOverlay(frame: .zero)
        overlay.set(mode: mode, intensity: intensity)
        return overlay
    }

    func updateNSView(_ nsView: EdgeFXOverlay, context: Context) {
        nsView.set(mode: mode, intensity: intensity)
    }
}
