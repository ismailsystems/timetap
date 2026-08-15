import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    static func postureSymbol(sitting: Bool) -> String {
        sitting ? "figure.seated.side.right" : "figure.stand"
    }

    static func hex(_ s: String) -> Color {
        guard let rgb = rgb(s) else { return .gray }
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    /// Category rows and the TimeTap title sit 10% above the design size.
    static let typeBump: CGFloat = 1.1

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        #if canImport(UIKit)
        .system(size: UIFontMetrics.default.scaledValue(for: size), weight: weight)
        #else
        .system(size: size, weight: weight)
        #endif
    }

    static func rowFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        font(size * typeBump, weight: weight)
    }

    /// Pale fills (FRAG / REL / POOP yellow) get dark text. Dark fills stay white.
    static func onFill(_ hex: String) -> Color {
        guard let rgb = rgb(hex) else { return .white }
        let l = 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
        return l > 0.42 ? ground : .white
    }

    private static func rgb(_ s: String) -> (r: Double, g: Double, b: Double)? {
        var h = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        return (
            Double((v >> 16) & 0xff) / 255,
            Double((v >> 8) & 0xff) / 255,
            Double(v & 0xff) / 255
        )
    }
}
