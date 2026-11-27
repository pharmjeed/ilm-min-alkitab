import AppIntents
import SwiftUI
import WidgetKit

/// One moment of the widgets. «تلقائي»: the day's name (its positions one after another, an hour each) or the day's
/// sunnah, a day each, «بدّل» between them. A collection of «محفوظاتي» (chosen in «المزيد»): its items one after
/// another, an hour each, «التالي» to move on (owner 2026-11-26).
struct TodayEntry: TimelineEntry {
    enum Slide: Hashable {
        case name(Today.Name, Today.Verse?)
        case sunnah(Today.Sunnah)
        case text(title: String, sub: String?, link: URL?)

        var link: URL? {
            switch self {
            case .name(let n, _): return Today.link(n)
            case .sunnah(let s): return Today.link(s)
            case .text(_, _, let l): return l
            }
        }
    }

    enum Action: Hashable { case toSunnah, toName, next }

    let date: Date
    /// «اسم اليوم» / «سنّة اليوم» / the collection's title, what it shows, and its button.
    let header: String
    let slide: Slide?
    let action: Action?

    static func make(_ date: Date, _ c: Today.Content, _ setup: WidgetSetup) -> TodayEntry {
        let h = face(setup.home, date, c)
        return TodayEntry(date: date, header: h.header, slide: h.slide, action: h.action)
    }

    /// The widget's moment by its choice in «المزيد»: a collection, the day's name always, the day's sunnah always,
    /// or «تلقائي» (a day each, «بدّل» between them).
    private static func face(_ f: WidgetSetup.Face, _ date: Date,
                             _ c: Today.Content) -> (header: String, slide: Slide?, action: Action?) {
        let hour = Today.hourNumber(date)
        if f.mode == "collection", let ch = f.choice, !ch.items.isEmpty {
            let k = hour + CollectionCursor.offset
            let n = ch.items.count
            let i = ((k % n) + n) % n
            let round = (k - i) / n   // how many times the collection went round: a name shows its next position
            let s = slide(ch.items[i], c, round)
            return (ch.title, s, n > 1 ? .next : nil)
        }
        let name = c.name(date).map { Slide.name($0, Today.verse(of: $0.id, slot: hour)) }
        let sunnah = c.sunnah(date).map(Slide.sunnah)
        let auto = f.mode != "name" && f.mode != "sunnah"
        let showSunnah: Bool
        switch f.mode {
        case "name": showSunnah = name == nil && sunnah != nil
        case "sunnah": showSunnah = sunnah != nil
        default: showSunnah = TodaySwitch.showsSunnah(date) && sunnah != nil
        }
        let both = auto && name != nil && sunnah != nil
        return (showSunnah ? "سنّة اليوم" : "اسم اليوم",
                showSunnah ? sunnah : name,
                both ? (showSunnah ? .toName : .toSunnah) : nil)
    }

    private static func slide(_ it: WidgetChoice.Item, _ c: Today.Content, _ round: Int) -> Slide? {
        switch it.k {
        case "name":
            guard let id = it.id, let n = c.name(id: id) else { return nil }
            return .name(n, Today.verse(of: id, slot: round))
        case "position":
            guard let id = it.id, let n = c.name(id: id) else { return nil }
            let all = Today.verses(of: id)
            return .name(n, all.first { $0.s == it.s && $0.a == it.a } ?? all.first)
        case "sunnah":
            guard let fp = it.fp, let st = it.stateId, let todo = it.todo else { return nil }
            return .sunnah(Today.Sunnah(fp: fp, stateId: st, time: it.time ?? "", todo: todo, fruit: it.fruit,
                                        grade: nil, source: it.meta))
        default:
            guard let t = it.title else { return nil }
            return .text(title: t, sub: it.sub, link: it.link.flatMap(URL.init(string:)))
        }
    }

    /// The widget gallery's sample, drawn redacted.
    static let placeholder = TodayEntry(
        date: Date(), header: "اسم اليوم",
        slide: .name(Today.Name(id: 0, name: "اسم اليوم", excerpt: "معنى الاسم، ومتى تستحضره، ومتى تدعو به."), nil),
        action: nil)
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

/// «التالي»: the next item of the chosen collection.
struct CollectionNextIntent: AppIntent {
    static var title: LocalizedStringResource = "التالي من مجموعتي"
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult {
        CollectionCursor.offset += 1
        return .result()
    }
}

enum CollectionCursor {
    private static let key = "collection.offset"
    static var offset: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
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
    /// Quran text only.
    static func amiri(_ size: CGFloat) -> Font { .custom("Amiri-Regular", size: size) }
}

/// The home widget, small / medium / large.
struct TodayWidgetView: View {
    let entry: TodayEntry
    let family: WidgetFamily

    var body: some View { home }

    // MARK: home screen

    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }

    private var home: some View {
        VStack(alignment: .leading, spacing: small ? 6 : 8) {
            HStack(alignment: .center, spacing: 6) {
                Text(entry.header)
                    .font(WidgetLook.sans(small ? 11 : 12, .medium)).foregroundStyle(WidgetLook.gold).lineLimit(1)
                Spacer(minLength: 4)
                if let a = entry.action { button(a) }
            }
            switch entry.slide {
            case .name(let n, let v): nameBody(n, v)
            case .sunnah(let s): sunnahBody(s)
            case .text(let t, let sub, _): textBody(t, sub)
            case nil: empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .multilineTextAlignment(.leading)
        .containerBackground(for: .widget) { WidgetLook.night }
        .widgetURL(entry.slide?.link)
    }

    @ViewBuilder private func button(_ a: TodayEntry.Action) -> some View {
        let label = a == .next ? "التالي ←" : a == .toName ? "الاسم ←" : "السنّة ←"
        let pill = Text(label)
            .font(WidgetLook.sans(small ? 10 : 11, .bold)).foregroundStyle(WidgetLook.night)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(WidgetLook.gold, in: Capsule())
        if a == .next {
            Button(intent: CollectionNextIntent()) { pill }.buttonStyle(.plain)
        } else {
            Button(intent: TodaySwitchIntent()) { pill }.buttonStyle(.plain)
        }
    }

    /// The name with its ayah (owner 2026-11-26): the largest ayah size whose WHOLE ayah fits (an ayah is never cut);
    /// when even the smallest does not fit, the name with its meaning and the ayah's reference.
    private func nameBody(_ n: Today.Name, _ verse: Today.Verse?) -> some View {
        let sizes: [CGFloat] = small ? [15, 13, 11.5] : large ? [21, 18, 16, 14, 12.5] : [17, 15, 13, 11.5]
        return ViewThatFits(in: .vertical) {
            if let v = verse {
                if large { nameWithVerse(n, v, sizes[0], meaning: true) }
                nameWithVerse(n, v, sizes[0])
                nameWithVerse(n, v, sizes[1])
                nameWithVerse(n, v, sizes[2])
                if sizes.count > 3 { nameWithVerse(n, v, sizes[3]) }
                if sizes.count > 4 { nameWithVerse(n, v, sizes[4]) }
            }
            nameWithMeaning(n, verse)
        }
    }

    private func nameWithVerse(_ n: Today.Name, _ v: Today.Verse, _ size: CGFloat, meaning: Bool = false) -> some View {
        var ayah = AttributedString("﴿\(v.text)﴾")
        ayah.font = WidgetLook.amiri(size)
        ayah.foregroundColor = WidgetLook.cream
        var ref = AttributedString(" \(v.ref.nonBreaking)")
        ref.font = WidgetLook.sans(max(10, size * 0.62))
        ref.foregroundColor = WidgetLook.cream.opacity(0.6)
        return VStack(alignment: .leading, spacing: small ? 2 : 4) {
            Text(n.name).font(WidgetLook.serif(small ? 20 : large ? 34 : 24)).foregroundStyle(WidgetLook.gold)
                .lineLimit(small || large ? 2 : 1).minimumScaleFactor(0.55)
            Text(ayah + ref)
            if meaning {
                Text(NotificationText.body(n.excerpt, max: 160)).font(WidgetLook.sans(14))
                    .foregroundStyle(WidgetLook.cream.opacity(0.85)).lineSpacing(4).padding(.top, 4)
            }
            if large {
                Spacer(minLength: 0)
                Text("اقرأ معناه، ومتى تدعو به ←").font(WidgetLook.sans(11, .medium)).foregroundStyle(WidgetLook.gold)
            }
        }
    }

    private func nameWithMeaning(_ n: Today.Name, _ verse: Today.Verse?) -> some View {
        VStack(alignment: .leading, spacing: small ? 4 : 8) {
            Text(n.name).font(WidgetLook.serif(small ? 24 : large ? 40 : 30)).foregroundStyle(WidgetLook.cream)
                .lineLimit(small ? 3 : 2).minimumScaleFactor(0.55)
            Text(NotificationText.body(n.excerpt, max: small ? 50 : large ? 230 : 75))
                .font(WidgetLook.sans(small ? 11 : large ? 15 : 13)).foregroundStyle(WidgetLook.cream.opacity(0.9))
                .lineSpacing(large ? 6 : 3)
            Spacer(minLength: 0)
            if let v = verse {
                Text("آيته \(v.ref) ←").font(WidgetLook.sans(11, .medium)).foregroundStyle(WidgetLook.gold)
            } else if !small {
                Text("اقرأ معناه، ومتى تدعو به ←").font(WidgetLook.sans(11, .medium)).foregroundStyle(WidgetLook.gold)
            }
        }
    }

    private func sunnahBody(_ s: Today.Sunnah) -> some View {
        let meta = [s.grade, s.source].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: small ? 4 : 8) {
            if !s.time.isEmpty {
                Text(s.time).font(WidgetLook.sans(small ? 11 : 12)).foregroundStyle(WidgetLook.cream.opacity(0.75))
                    .lineLimit(1)
            }
            Text(s.todo).font(WidgetLook.sans(small ? 13 : large ? 20 : 16, .bold)).foregroundStyle(WidgetLook.cream)
                .lineSpacing(3).lineLimit(small ? 4 : large ? 6 : 3).minimumScaleFactor(0.7)
            if let f = s.fruit, !small || s.todo.count < 40 {
                Text("← \(f)").font(WidgetLook.sans(small ? 11 : large ? 17 : 14, .medium)).foregroundStyle(WidgetLook.green)
                    .lineSpacing(3).lineLimit(small ? 2 : 3).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            if !small && !meta.isEmpty {
                Text(meta).font(WidgetLook.sans(11)).foregroundStyle(WidgetLook.cream.opacity(0.6)).lineLimit(1)
            }
        }
    }

    private func textBody(_ title: String, _ sub: String?) -> some View {
        VStack(alignment: .leading, spacing: small ? 4 : 8) {
            Text(title).font(WidgetLook.sans(small ? 15 : large ? 24 : 19, .bold)).foregroundStyle(WidgetLook.cream)
                .lineSpacing(3).lineLimit(small ? 4 : large ? 6 : 3).minimumScaleFactor(0.7)
            if let sub, !sub.isEmpty {
                Text(sub).font(WidgetLook.sans(small ? 11 : 13)).foregroundStyle(WidgetLook.cream.opacity(0.75))
                    .lineLimit(small ? 2 : large ? 6 : 2)
            }
            Spacer(minLength: 0)
        }
    }

    private var empty: some View {
        Text("افتح «علم من الكتاب» مرة ليظهر هنا اسم اليوم.")
            .font(WidgetLook.sans(13)).foregroundStyle(WidgetLook.cream)
    }
}

extension String {
    /// «[آل عمران: 117]» kept on one line.
    var nonBreaking: String { replacingOccurrences(of: " ", with: "\u{00A0}") }
}
