import SwiftUI
import UIKit
import Observation

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
/// Sizes scale with Dynamic Type via `relativeTo`, times the in-app «حجم النص» (`TextScale`, read inside view bodies,
/// so every screen re-renders when it changes).
enum AppFont {
    private static var k: CGFloat { TextScale.shared.factor }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black, .semibold: name = "thmanyahsans-Bold"
        case .medium: name = "thmanyahsans-Medium"
        default: name = "thmanyahsans-Regular"
        }
        return .custom(name, size: size * k, relativeTo: style)
    }
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(weight == .medium ? "thmanyahserifdisplay-Medium" : "thmanyahserifdisplay-Bold", size: size * k, relativeTo: style)
    }
    static func amiri(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(bold ? "Amiri-Bold" : "Amiri-Regular", size: size * k, relativeTo: style)
    }
}

/// «حجم النص» in «المزيد»: عادي · كبير · أكبر, on top of the iPhone's own text size (Dynamic Type).
@Observable
final class TextScale {
    enum Level: Int, CaseIterable, Identifiable {
        case normal = 0, large = 1, larger = 2
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .normal: return "عادي"
            case .large: return "كبير"
            case .larger: return "أكبر"
            }
        }
        var factor: CGFloat {
            switch self {
            case .normal: return 1
            case .large: return 1.15
            case .larger: return 1.3
            }
        }
    }

    static let shared = TextScale()
    private(set) var level: Level

    private init() {
        level = Level(rawValue: UserDefaults.standard.integer(forKey: "textScale")) ?? .normal
    }

    var factor: CGFloat { level.factor }

    func set(_ l: Level) {
        level = l
        UserDefaults.standard.set(l.rawValue, forKey: "textScale")
    }
}

/// «المظهر» in «المزيد»: تلقائي (the iPhone's setting) · داكن (default) · فاتح — applied to the whole window.
enum Appearance: String, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "تلقائي"
        case .dark: return "داكن"
        case .light: return "فاتح"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
    private var style: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .dark: return .dark
        case .light: return .light
        }
    }
    static func from(_ raw: String) -> Appearance { Appearance(rawValue: raw) ?? .dark }

    /// `preferredColorScheme(nil)` does not undo an earlier explicit scheme, so the windows are set directly as well.
    @MainActor static func apply(_ mode: Appearance) {
        Task { @MainActor in
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                for w in ws.windows {
                    w.overrideUserInterfaceStyle = mode.style
                    w.rootViewController?.overrideUserInterfaceStyle = mode.style
                }
            }
        }
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
