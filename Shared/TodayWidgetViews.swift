import AppIntents
import SwiftUI
import WidgetKit

/// One moment of the «اليوم» widgets: the day's name and sunnah, and which of the two the home widget shows now.
struct TodayEntry: TimelineEntry {
    let date: Date
    let name: Today.Name?
    let sunnah: Today.Sunnah?
    /// The day's turn (owner 2026-11-26: «يوم كذا ويوم كذا»), or the other one after «بدّل».
    let showsSunnah: Bool

    static func make(_ date: Date, _ c: Today.Content) -> TodayEntry {
        TodayEntry(date: date, name: c.name(date), sunnah: c.sunnah(date), showsSunnah: TodaySwitch.showsSunnah(date))
    }

    /// The widget gallery's sample, drawn redacted.
    static let placeholder = TodayEntry(
        date: Date(),
        name: Today.Name(id: 0, name: "اسم اليوم", excerpt: "معنى الاسم، ومتى تستحضره، ومتى تدعو به."),
        sunnah: nil, showsSunnah: false)
}

/// «بدّل»: the button on the home widget shows the other one (the day's name ↔ the day's sunnah) until the day ends.
struct TodaySwitchIntent: AppIntent {
    static var title: LocalizedStringResource = "بدّل بين اسم اليوم وسنّة اليوم"
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult {
        TodaySwitch.flip()
        return .result()
    }
}

enum TodaySwitch {
    private static let dayKey = "today.switch.day"
    private static let onKey = "today.switch.on"
    private static var d: UserDefaults { .standard }

    static func isFlipped(_ date: Date) -> Bool {
        d.object(forKey: dayKey) != nil && d.integer(forKey: dayKey) == Today.dayNumber(date) && d.bool(forKey: onKey)
    }

    static func showsSunnah(_ date: Date) -> Bool { Today.sunnahDay(date) != isFlipped(date) }

    static func flip(_ now: Date = Date()) {
        let today = Today.dayNumber(now)
        if d.object(forKey: dayKey) == nil || d.integer(forKey: dayKey) != today {
            d.set(today, forKey: dayKey)
            d.set(true, forKey: onKey)
        } else {
            d.set(!d.bool(forKey: onKey), forKey: onKey)
        }
    }
}

/// The brand's dark look on every widget (night, gold, cream; the result in green as in the sunnah texts).
enum WidgetLook {
    static let night = Color(red: 0x0D / 255, green: 0x1F / 255, blue: 0x1F / 255)
    static let gold = Color(red: 0xD4 / 255, green: 0xA4 / 255, blue: 0x49 / 255)
    static let cream = Color(red: 0xF7 / 255, green: 0xEC / 255, blue: 0xD6 / 255)
    static let green = Color(red: 0x8B / 255, green: 0xE0 / 255, blue: 0xA8 / 255)

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .semibold, .heavy, .black: return .custom("thmanyahsans-Bold", size: size)
        case .medium: return .custom("thmanyahsans-Medium", size: size)
        default: return .custom("thmanyahsans-Regular", size: size)
        }
    }
    static func serif(_ size: CGFloat) -> Font { .custom("thmanyahserifdisplay-Bold", size: size) }
}

/// Every family of the two widgets: the home widget (small / medium / large) and the lock screen (a line, a box).
struct TodayWidgetView: View {
    let entry: TodayEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryRectangular: rectangular
        default: home
        }
    }

    // MARK: lock screen — «اسم اليوم» and one line

    private var inline: some View {
        Text(entry.name.map { "اسم اليوم: \($0.name)" } ?? "اسم اليوم")
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(entry.name.map(Today.link))
    }

    /// The box's size is the system's (about 160×72 points); the text fills it (owner 2026-11-26 «صغيرة في شاشة القفل»):
    /// the largest name that stays on one line with its line under it, else a smaller one, else a long name on up to
    /// three lines alone. Line heights are the fonts' own (1.25 × size), so each layout's height is known.
    private var rectangular: some View {
        ViewThatFits(in: .vertical) {
            lockBox(name: 26, text: 15)
            lockBox(name: 22, text: 14)
            lockBox(name: 19, text: 13)
            lockBox(name: 17, text: nil)
            lockBox(name: 14, text: nil, lines: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(entry.name.map(Today.link))
    }

    private func lockBox(name size: CGFloat, text: CGFloat?, lines: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("اسم اليوم").font(WidgetLook.sans(12, .medium)).widgetAccentable()
            Text(entry.name?.name ?? "—").font(WidgetLook.serif(size)).lineLimit(lines)
            if let text, let n = entry.name { lockLine(n.excerpt, text) }
        }
    }

    /// One line of the excerpt: the longest cut that fits whole (a cut never falls inside an ayah — NotificationText).
    private func lockLine(_ excerpt: String, _ size: CGFloat) -> some View {
        func cut(_ m: Int) -> some View {
            Text(NotificationText.body(excerpt, max: m)).font(WidgetLook.sans(size)).lineLimit(1)
        }
        return ViewThatFits(in: .horizontal) {
            cut(60)
            cut(44)
            cut(34)
            cut(26)
            cut(20).minimumScaleFactor(0.75)
        }
    }

    // MARK: home screen — the name one day, the sunnah the next, «بدّل» between them

    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }

    private var home: some View {
        let showSunnah = entry.showsSunnah && entry.sunnah != nil
        return VStack(alignment: .leading, spacing: small ? 6 : 8) {
            HStack(alignment: .center, spacing: 6) {
                Text(showSunnah ? "سنّة اليوم" : "اسم اليوم")
                    .font(WidgetLook.sans(small ? 11 : 12, .medium)).foregroundStyle(WidgetLook.gold)
                Spacer(minLength: 4)
                if entry.sunnah != nil && entry.name != nil {
                    Button(intent: TodaySwitchIntent()) {
                        Text(showSunnah ? "الاسم ←" : "السنّة ←")
                            .font(WidgetLook.sans(small ? 10 : 11, .bold)).foregroundStyle(WidgetLook.night)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(WidgetLook.gold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            if showSunnah, let s = entry.sunnah { sunnahBody(s) } else if let n = entry.name { nameBody(n) } else { empty }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .multilineTextAlignment(.leading)
        .containerBackground(for: .widget) { WidgetLook.night }
        .widgetURL(showSunnah ? entry.sunnah.map(Today.link) : entry.name.map(Today.link))
    }

    private func nameBody(_ n: Today.Name) -> some View {
        VStack(alignment: .leading, spacing: small ? 4 : 8) {
            Text(n.name).font(WidgetLook.serif(small ? 24 : large ? 40 : 30)).foregroundStyle(WidgetLook.cream)
                .lineLimit(small ? 3 : 2).minimumScaleFactor(0.55)
            Text(NotificationText.body(n.excerpt, max: small ? 60 : large ? 230 : 105))
                .font(WidgetLook.sans(small ? 11 : large ? 15 : 13)).foregroundStyle(WidgetLook.cream.opacity(0.9))
                .lineSpacing(large ? 6 : 3)
            Spacer(minLength: 0)
            if !small {
                Text("اقرأ معناه، ومتى تدعو به ←").font(WidgetLook.sans(11, .medium)).foregroundStyle(WidgetLook.gold)
            }
        }
    }

    private func sunnahBody(_ s: Today.Sunnah) -> some View {
        let meta = [s.grade, s.source].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: small ? 4 : 8) {
            Text(s.time).font(WidgetLook.sans(small ? 11 : 12)).foregroundStyle(WidgetLook.cream.opacity(0.75))
            Text(s.todo).font(WidgetLook.sans(small ? 13 : large ? 20 : 16, .bold)).foregroundStyle(WidgetLook.cream)
                .lineSpacing(3).lineLimit(small ? 4 : large ? 6 : 3).minimumScaleFactor(0.7)
            if let f = s.fruit, !small || s.todo.count < 40 {
                Text("← \(f)").font(WidgetLook.sans(small ? 11 : large ? 17 : 14, .medium)).foregroundStyle(WidgetLook.green)
                    .lineSpacing(3).lineLimit(small ? 2 : 3).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            if !small && !meta.isEmpty {
                Text(meta).font(WidgetLook.sans(11)).foregroundStyle(WidgetLook.cream.opacity(0.6))
            }
        }
    }

    private var empty: some View {
        Text("افتح «علم من الكتاب» مرة ليظهر هنا اسم اليوم.")
            .font(WidgetLook.sans(13)).foregroundStyle(WidgetLook.cream)
    }
}
