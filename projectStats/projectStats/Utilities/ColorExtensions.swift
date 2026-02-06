import SwiftUI

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.hasPrefix("#") ? String(h.dropFirst()) : h
        guard h.count == 6, let n = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: Double((n & 0xFF0000) >> 16) / 255,
            green: Double((n & 0x00FF00) >> 8) / 255,
            blue: Double(n & 0x0000FF) / 255
        )
    }
}
