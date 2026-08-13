import SwiftUI

enum Theme {
    static let ground = Color(red: 0x16 / 255, green: 0x15 / 255, blue: 0x13 / 255)
    static let panel = Color(red: 0x1e / 255, green: 0x1d / 255, blue: 0x1a / 255)
    static let panel2 = Color(red: 0x26 / 255, green: 0x24 / 255, blue: 0x1f / 255)
    static let rule2 = Color(red: 0x3a / 255, green: 0x38 / 255, blue: 0x33 / 255)
    static let fg = Color(red: 0xf3 / 255, green: 0xf2 / 255, blue: 0xf2 / 255)
    static let dim = Color(red: 0xa0 / 255, green: 0x9a / 255, blue: 0x91 / 255)
    static let mute = Color(red: 0x6b / 255, green: 0x66 / 255, blue: 0x5e / 255)
    static let accent = Color(red: 0xec / 255, green: 0x30 / 255, blue: 0x13 / 255)
    static let accentOn = Color(red: 0xff / 255, green: 0x6a / 255, blue: 0x4a / 255)
    static let flag = Color(red: 0xc9 / 255, green: 0xa2 / 255, blue: 0x27 / 255)
    static let fail = Color(red: 0x2a / 255, green: 0x16 / 255, blue: 0x13 / 255)

    static func hex(_ s: String) -> Color {
        var h = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return .gray }
        return Color(
            red: Double((v >> 16) & 0xff) / 255,
            green: Double((v >> 8) & 0xff) / 255,
            blue: Double(v & 0xff) / 255
        )
    }
}
