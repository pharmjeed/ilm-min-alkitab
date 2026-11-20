import SwiftUI

/// Visual identity shared with the website (app/globals.css of the platform).
/// Dark is the default; light follows the same tokens as the site's [data-theme=light].
enum Palette {
    static func bg(_ s: ColorScheme) -> Color { s == .dark ? Color(hex: 0x0D1F1F) : Color(hex: 0xF5E9D0) }
    static func surface(_ s: ColorScheme) -> Color { s == .dark ? Color(hex: 0x122828) : Color(hex: 0xFBF3E3) }
    static func surface2(_ s: ColorScheme) -> Color { s == .dark ? Color(hex: 0x183333) : Color(hex: 0xF1E3C6) }
    static func cream(_ s: ColorScheme) -> Color { s == .dark ? Color(hex: 0xF7ECD6) : Color(hex: 0x0D1F1F) }
    static func muted(_ s: ColorScheme) -> Color { s == .dark ? Color(hex: 0xF7ECD6, alpha: 0.66) : Color(hex: 0x0D1F1F, alpha: 0.64) }
    static func gold(_ s: ColorScheme) -> Color { s == .dark ? Color(hex: 0xD4A449) : Color(hex: 0x846008) }
    static func line(_ s: ColorScheme) -> Color { s == .dark ? Color(hex: 0xD4A449, alpha: 0.22) : Color(hex: 0xB8860B, alpha: 0.28) }
    static func result(_ s: ColorScheme) -> Color { s == .dark ? Color(hex: 0x8BE0A8) : Color(hex: 0x1F7A4D) }
    static func neg(_ s: ColorScheme) -> Color { s == .dark ? Color(hex: 0xC9826B) : Color(hex: 0xA2482B) }
    static let emerald = Color(hex: 0x2F6B5E)
    static let night = Color(hex: 0x0D1F1F)
}

/// Resolved colours for the current scheme — read it with `@Environment(\.colorScheme)` → `Theme(scheme)`.
struct Theme {
    let scheme: ColorScheme
    init(_ scheme: ColorScheme) { self.scheme = scheme }
    var bg: Color { Palette.bg(scheme) }
    var surface: Color { Palette.surface(scheme) }
    var surface2: Color { Palette.surface2(scheme) }
    var cream: Color { Palette.cream(scheme) }
    var muted: Color { Palette.muted(scheme) }
    var gold: Color { Palette.gold(scheme) }
    var line: Color { Palette.line(scheme) }
    var result: Color { Palette.result(scheme) }
    var neg: Color { Palette.neg(scheme) }
}

/// Fonts: Thmanyah Sans (body), Thmanyah Serif Display (headings), Amiri (Quran and hadith ONLY).
/// Sizes scale with Dynamic Type via `relativeTo`.
enum AppFont {
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black, .semibold: name = "thmanyahsans-Bold"
        case .medium: name = "thmanyahsans-Medium"
        default: name = "thmanyahsans-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(weight == .medium ? "thmanyahserifdisplay-Medium" : "thmanyahserifdisplay-Bold", size: size, relativeTo: style)
    }
    static func amiri(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(bold ? "Amiri-Bold" : "Amiri-Regular", size: size, relativeTo: style)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// Western digits everywhere (as on the site), Arabic text otherwise.
enum Num {
    static func fmt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}
