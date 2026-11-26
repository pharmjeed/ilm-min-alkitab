import Foundation

/// «اسم اليوم» and «سنّة اليوم» (owner 2026-11-26) — shared by the app (notifications, Siri, Spotlight) and the widget
/// extension, so both always show the same name and the same sunnah. Reads only two small pack files: the names index
/// (`names/index`) and «برنامج اليوم والليلة» (`sunan/day`).
enum Today {
    /// Days since 1970-01-01 UTC — the website's day (lib/content/daily.ts).
    static func dayNumber(_ date: Date = Date()) -> Int {
        Int((date.timeIntervalSince1970 * 1000 / 86_400_000).rounded(.down))
    }

    /// The start of the next website day after `date` (when «اسم اليوم» changes).
    static func nextDay(after date: Date) -> Date {
        Date(timeIntervalSince1970: Double(dayNumber(date) + 1) * 86_400)
    }

    /// Index of «اسم اليوم» among `count` names — the website's pickNameOfDay (lib/content/daily.ts).
    static func nameIndex(mode: String, fixedIndex: Int?, count: Int, date: Date) -> Int {
        guard count > 0 else { return 0 }
        if mode == "fixed", let fixedIndex { return fixedIndex }
        let d = dayNumber(date)
        if mode == "random_daily" {
            var r = Mulberry32(seed: UInt32(truncatingIfNeeded: Int64(d) * 7919))
            return Int((r.next() * Double(count)).rounded(.down))
        }
        return ((d % count) + count) % count
    }

    /// The home widget alternates: the name one day, the sunnah the next.
    static func sunnahDay(_ date: Date) -> Bool { dayNumber(date) % 2 != 0 }

    /// Hours since 1970 (UTC): the widgets move to the next position, or the next item of a collection, every hour
    /// (owner 2026-11-26 «اجعلها بطريقة تعرض كل المواضع على مر الزمن»).
    static func hourNumber(_ date: Date) -> Int { Int((date.timeIntervalSince1970 / 3600).rounded(.down)) }

    static func hourStart(_ date: Date) -> Date { Date(timeIntervalSince1970: Double(hourNumber(date)) * 3600) }

    /// Every position of a name in the name page's order: the extension's own file, or (inside the app) the file of
    /// the extension embedded in it.
    static func verses(of id: Int) -> [Verse] {
        versesLock.lock()
        defer { versesLock.unlock() }
        if let hit = versesCache[id] { return hit }
        let v = readVerses(id)
        if versesCache.count > 40 { versesCache.removeAll() }
        versesCache[id] = v
        return v
    }

    /// The timeline asks for the same few names many times (an entry an hour): each file is read once.
    nonisolated(unsafe) private static var versesCache: [Int: [Verse]] = [:]
    private static let versesLock = NSLock()

    private static func readVerses(_ id: Int) -> [Verse] {
        let file = "widget-verses/\(id).json"
        let own = Bundle.main.resourceURL?.appendingPathComponent(file)
        let embedded = Bundle.main.builtInPlugInsURL?.appendingPathComponent("IlmWidgets.appex").appendingPathComponent(file)
        for url in [own, embedded].compactMap({ $0 }) {
            if let d = try? Data(contentsOf: url), let v = try? JSONDecoder().decode([Verse].self, from: d) { return v }
        }
        return []
    }

    /// The position shown at `slot` (an hour number): one after another, all of them over time.
    static func verse(of id: Int, slot: Int) -> Verse? {
        let v = verses(of: id)
        return v.isEmpty ? nil : v[((slot % v.count) + v.count) % v.count]
    }

    // MARK: content

    struct Name: Hashable {
        let id: Int
        let name: String
        let excerpt: String
    }

    /// A Quran position of a name (gen/widget-verses/<id>.json, from the names packs): the text verbatim, never cut.
    struct Verse: Hashable, Decodable {
        let s: Int
        let surah: String
        let a: Int
        let last: Int?
        let text: String
        /// «[التوبة: 2]», «[البقرة: 1–3]» — as on the name page.
        var ref: String { "[\(surah): \(last.map { "\(a)–\($0)" } ?? "\(a)")]" }
    }

    struct Sunnah: Hashable {
        let fp: String
        let stateId: Int
        /// The time of «برنامج اليوم والليلة» it belongs to («عند النوم»…).
        let time: String
        let todo: String
        let fruit: String?
        let grade: String?
        let source: String?
    }

    /// The two pack files, decoded with only what «اليوم» needs.
    struct Content {
        let names: NamesFile?
        let day: DayFile?

        static func load(names: URL?, day: URL?) -> Content {
            let dec = JSONDecoder()
            func read<T: Decodable>(_ u: URL?) -> T? { u.flatMap { try? dec.decode(T.self, from: Data(contentsOf: $0)) } }
            return Content(names: read(names), day: read(day))
        }

        func name(id: Int) -> Name? {
            guard let c = names?.names.first(where: { $0.id == id }) else { return nil }
            return Name(id: c.id, name: c.name, excerpt: c.excerpt)
        }

        func name(_ date: Date) -> Name? {
            guard let f = names, !f.names.isEmpty else { return nil }
            // as NamesRepo.nameOfDay: a fixed id that is missing falls back to the first name
            let fixed = f.nameOfDay.fixedId.map { id in f.names.firstIndex { $0.id == id } ?? 0 }
            let i = Today.nameIndex(mode: f.nameOfDay.mode, fixedIndex: fixed, count: f.names.count, date: date)
            let c = f.names[min(max(i, 0), f.names.count - 1)]
            return Name(id: c.id, name: c.name, excerpt: c.excerpt)
        }

        /// The starred sunan («ابدأ بهذه») of the given times, in the programme's order.
        private func stars(_ keep: (Int, DayFile.Time) -> Bool) -> [Sunnah] {
            guard let d = day else { return [] }
            var out: [Sunnah] = []
            var seen = Set<String>()
            for (pi, p) in d.periods.enumerated() {
                for t in p.times where keep(pi, t) {
                    for it in t.items where it.star == true && !seen.contains(it.fp) {
                        seen.insert(it.fp)
                        out.append(Sunnah(fp: it.fp, stateId: it.stateId, time: t.title, todo: it.todo, fruit: it.fruit,
                                          grade: it.grade, source: it.srcLabel))
                    }
                }
            }
            return out
        }

        /// «سنّة اليوم»: one starred sunnah a day from «اليوم والليلة» and «في مواقف يومك» (never a season's — the
        /// Hajj, Ramadan… are not every day); on Fridays one of «يوم الجمعة».
        func sunnah(_ date: Date, calendar: Calendar = .current) -> Sunnah? {
            let d = Today.dayNumber(date)
            func pick(_ s: [Sunnah]) -> Sunnah? { s.isEmpty ? nil : s[((d % s.count) + s.count) % s.count] }
            if calendar.component(.weekday, from: date) == 6, let f = pick(stars { _, t in t.title == "يوم الجمعة" }) {
                return f
            }
            return pick(stars { p, _ in p < 2 })
        }
    }

    struct NamesFile: Decodable {
        struct Setting: Decodable {
            let mode: String
            let fixedId: Int?
        }
        struct Card: Decodable {
            let id: Int
            let name: String
            let excerpt: String
        }
        let nameOfDay: Setting
        let names: [Card]
    }

    struct DayFile: Decodable {
        struct Period: Decodable { let times: [Time] }
        struct Time: Decodable {
            let title: String
            let items: [Item]
        }
        struct Item: Decodable {
            let fp: String
            let stateId: Int
            let star: Bool?
            let todo: String
            let fruit: String?
            let grade: String?
            let srcLabel: String?
        }
        let periods: [Period]
    }

    // MARK: links (the widget opens the app on the name or the sunnah)

    static func link(_ n: Name) -> URL { URL(string: "ilm://name/\(n.id)")! }
    static func link(_ s: Sunnah) -> URL { URL(string: "ilm://sunnah/\(s.stateId)/\(s.fp)")! }
}

/// mulberry32, bit-identical to the website's rng() (JS Math.imul / >>> 0 ⇒ wrapping UInt32 arithmetic).
struct Mulberry32 {
    private var a: UInt32
    init(seed: UInt32) { a = seed }
    mutating func next() -> Double {
        a = a &+ 0x6D2B_79F5
        var t = a
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}

/// A shortened text for a notification, a widget or Siri: the excerpt verbatim, at most `max` characters (Unicode
/// scalars, as the website counts). A cut never falls inside an ayah: the excerpt is cut before its «﴿» or keeps the
/// whole ayah.
enum NotificationText {
    static let fallback = "افتح لتقرأ معنى الاسم، ومتى تدعو به."
    private static let trailing: Set<Unicode.Scalar> = [":", "،", "؛", "—", "–", "-", ",", "."]

    static func body(_ excerpt: String, max: Int = 140) -> String {
        let s = Array(excerpt.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars)
        let n = s.count
        // ayah spans: consecutive ornate brackets (open, close); an unclosed one runs to the end
        let brackets = s.indices.filter { s[$0] == "\u{FD3F}" || s[$0] == "\u{FD3E}" }
        var spans: [(Int, Int)] = []
        var k = 0
        while k < brackets.count {
            spans.append((brackets[k], k + 1 < brackets.count ? brackets[k + 1] : n))
            k += 2
        }
        let complete = spans.allSatisfy { $0.1 < n }
        if n <= max && complete { return String(String.UnicodeScalarView(s)) }
        let starts = Set(spans.map(\.0))
        let ends = Set(spans.map(\.1))
        func splits(_ c: Int) -> Bool { spans.contains { $0.0 < c && c <= $0.1 } }
        func boundary(_ c: Int) -> Bool {
            c >= n || s[c].properties.isWhitespace || s[c - 1].properties.isWhitespace
                || starts.contains(c) || ends.contains(c - 1)
        }
        var cut = Swift.min(n, max - 1)
        while cut > 0 && (splits(cut) || !boundary(cut)) { cut -= 1 }
        var head = Array(s[0..<cut])
        while let last = head.last, last.properties.isWhitespace || trailing.contains(last) { head.removeLast() }
        guard !head.isEmpty else { return fallback }
        return String(String.UnicodeScalarView(head)) + "…"
    }
}
