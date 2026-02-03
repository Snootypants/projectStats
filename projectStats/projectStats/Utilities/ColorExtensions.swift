import AppKit
import SwiftUI

extension Color {
    /// Create Color from a hex string (e.g., "#FF9500" or "FF9500")
    /// Returns nil if the hex string is invalid
    static func fromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255

        return Color(red: r, green: g, blue: b)
    }

    /// Convert Color to hex string
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB) else {
            return nil
        }

        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Accent Color Presets

struct AccentColorPreset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let hex: String

    var color: Color {
        Color.fromHex(hex) ?? .orange
    }

    static let presets: [AccentColorPreset] = [
        AccentColorPreset(name: "Orange", hex: "#FF9500"),
        AccentColorPreset(name: "Blue", hex: "#007AFF"),
        AccentColorPreset(name: "Purple", hex: "#AF52DE"),
        AccentColorPreset(name: "Green", hex: "#34C759"),
        AccentColorPreset(name: "Pink", hex: "#FF2D55"),
        AccentColorPreset(name: "Teal", hex: "#5AC8FA"),
        AccentColorPreset(name: "Indigo", hex: "#5856D6")
    ]
}
