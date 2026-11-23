import SwiftUI

/// Wording and pure helpers of the website's sunan pages (`lib/sunan/view.ts`, `components/sunan/*`).
enum SunanText {
    static let title = "السنن والأسباب"
    static let kicker = "سر علم السنن والأسباب"
    static let lead = "جعل الله لكل شيءٍ سببًا، وبيّن في كتابه وعلى لسان نبيّه ﷺ: إذا فعلتَ كذا كان لك كذا."
    static let dayTitle = "برنامج اليوم والليلة"
    static let dayLead = "سنن يومك وليلتك من استيقاظك إلى نومك، ثم مواقف يومك، ثم أسبوعك وشهرك وسنتك: ماذا تفعل، وما ثمرته."
    static let deedsTitle = "ماذا يجلب هذا العمل؟"
    static let deedsLead = "اختر عملًا صالحًا تعرف ما يجلبه لك من الثمرات، أو ذنبًا تعرف عواقبه فتحذره."
    static let searchPrompt = "ابحث عن حالك: البركة، الدَّين، الهمّ، الذرية…"

    // lib/arabic/count.ts
    static let sunan = Arabic.CountForms(one: "سنّة واحدة", two: "سنّتان", few: "سنن", many: "سنّة")
    static let states = Arabic.CountForms(one: "حال واحدة", two: "حالان", few: "أحوال", many: "حالًا")
    static let needs = Arabic.CountForms(one: "حاجة واحدة", two: "حاجتان", few: "حاجات", many: "حاجة")
    static let domains = Arabic.CountForms(one: "مجال واحد", two: "مجالان", few: "مجالات", many: "مجالًا")
    static let fruits = Arabic.CountForms(one: "ثمرة واحدة", two: "ثمرتان", few: "ثمرات", many: "ثمرة")
    static let consequences = Arabic.CountForms(one: "عاقبة واحدة", two: "عاقبتان", few: "عواقب", many: "عاقبة")
    static let deeds = Arabic.CountForms(one: "عمل واحد", two: "عملان", few: "أعمال", many: "عملًا")
    static let narrations = Arabic.CountForms(one: "رواية واحدة", two: "روايتان", few: "روايات", many: "رواية")

    static func count(_ n: Int, _ f: Arabic.CountForms) -> String { Arabic.count(n, f) }

    /// DEED_KIND_LABEL
    static func deedKind(_ kind: String) -> String { kind == "sin" ? "ذنب" : "عمل صالح" }

    /// «164 ثمرة في 26 حاجة» / «135 عاقبة في 14 حاجة».
    static func deedCountLine(_ d: SunanDeed) -> String {
        "\(count(d.fruitsCount, d.sin ? consequences : fruits)) في \(count(d.needsCount, needs))"
    }

    /// APPLY_LABEL (nil for a kind this app does not know: show the text without a label).
    static func applyLabel(_ k: String) -> String? {
        switch k {
        case "say": return "قل"
        case "time": return "الوقت"
        case "count": return "العدد"
        case "read": return "اقرأ"
        default: return nil
        }
    }

    /// «القرآن الكريم · سورة نوح: 10–12» / «متفق عليه · صحيح مسلم 918 · صحيح» (repeats dropped).
    static func sourceLine(_ it: SunnahItem) -> String {
        var seen = Set<String>()
        var parts: [String] = []
        for part in [it.srcLabel, it.ref, it.grade] {
            guard let p = part, !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !seen.contains(p) else { continue }
            seen.insert(p)
            parts.append(p)
        }
        return parts.joined(separator: " · ")
    }

    /// «الدرجة · المصدر» of the day / deeds rows («قرآن · القرآن الكريم» → «القرآن الكريم»).
    static func sourceOf(grade: String?, srcLabel: String?) -> String {
        if grade == "قرآن" { return srcLabel ?? "القرآن الكريم" }
        return [srcLabel, grade].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Keeps a short reference on one line (the site's `whitespace-nowrap`): spaces → no-break spaces, word joiners around «–».
    static func nowrap(_ s: String) -> String {
        let nbsp = String(Character(Unicode.Scalar(UInt8(0xA0))))
        let wj = Unicode.Scalar(UInt32(0x2060)).map { String(Character($0)) } ?? ""
        return s.replacingOccurrences(of: " ", with: nbsp).replacingOccurrences(of: "–", with: wj + "–" + wj)
    }

    /// «↗» forced to its text glyph (iOS would draw it as an emoji).
    static let outArrow = "↗" + (Unicode.Scalar(UInt32(0xFE0E)).map { String(Character($0)) } ?? "")

    static func dorarURL(_ code: String) -> URL? { URL(string: "https://dorar.net/h/\(code)") }

    static func itemURL(_ fp: String) -> URL { Site.url("/sunan/item/\(fp)") }

    /// «ابدأ بهذه» first (sheet order kept), then the rest.
    static func starFirst(_ items: [SunnahItem]) -> [SunnahItem] {
        items.filter(\.isStar) + items.filter { !$0.isStar }
    }

    // MARK: text runs (0 = plain, 1 = cause gold, 2 = result green)

    struct Run { var t: String; let k: Int }

    /// «السبب ← النتيجة» → halves at the first «←» (result nil without an arrow).
    static func easyParts(_ easy: String) -> (cause: String, result: String?) {
        guard let r = easy.range(of: "←") else { return (easy.trimmingCharacters(in: .whitespacesAndNewlines), nil) }
        return (String(easy[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines),
                String(easy[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func segRuns(_ segs: [SunanSeg]) -> [Run] {
        var out: [Run] = []
        for s in segs {
            let r: Run
            switch s {
            case .plain(let t): r = Run(t: t, k: 0)
            case .run(let t, let k): r = Run(t: t, k: k)
            }
            if r.t.isEmpty { continue }
            if let last = out.last, last.k == r.k { out[out.count - 1].t += r.t } else { out.append(r) }
        }
        return out
    }

    static func plain(_ segs: [SunanSeg]) -> String {
        segs.map { s -> String in
            switch s {
            case .plain(let t): return t
            case .run(let t, _): return t
            }
        }.joined()
    }

    /// Runs of text[start, end) coloured by the highlight ranges (UTF-16 offsets, end exclusive).
    static func rangeRuns(_ ns: NSString, _ hl: [[Int]], _ start: Int, _ end: Int) -> [Run] {
        let end = min(end, ns.length)
        guard start < end else { return [] }
        var cuts = Set([start, end])
        for h in hl where h.count >= 2 {
            if h[0] > start && h[0] < end { cuts.insert(h[0]) }
            if h[1] > start && h[1] < end { cuts.insert(h[1]) }
        }
        let points = cuts.sorted()
        var out: [Run] = []
        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            let h = hl.first { $0.count >= 3 && $0[0] <= a && b <= $0[1] }
            let k = h?[2] ?? 0
            let t = ns.substring(with: NSRange(location: a, length: b - a))
            if let last = out.last, last.k == k { out[out.count - 1].t += t } else if !t.isEmpty { out.append(Run(t: t, k: k)) }
        }
        return out
    }

    private static func isWS(_ u: unichar) -> Bool {
        guard let s = Unicode.Scalar(u) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(s)
    }

    private static let ayahMarker = try? NSRegularExpression(pattern: #"\s*\((\d+)\)"#)

    /// Canonical Quran text («ayah (n) ayah (n)…») → one entry per ayah with its runs; the ayah text is never altered.
    static func quranAyat(_ text: String, _ hl: [[Int]]) -> [(a: Int, runs: [Run])] {
        let ns = text as NSString
        var out: [(a: Int, runs: [Run])] = []
        var from = 0
        for m in ayahMarker?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? [] {
            var s = from
            while s < m.range.location && isWS(ns.character(at: s)) { s += 1 }
            if m.range.location > s {
                out.append((Int(ns.substring(with: m.range(at: 1))) ?? 0, rangeRuns(ns, hl, s, m.range.location)))
            }
            from = m.range.location + m.range.length
        }
        if from < ns.length, !ns.substring(from: from).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var s = from
            while s < ns.length && isWS(ns.character(at: s)) { s += 1 }
            var e = ns.length
            while e > s && isWS(ns.character(at: e - 1)) { e -= 1 }
            out.append((0, rangeRuns(ns, hl, s, e)))
        }
        return out
    }

    private static let quote = try? NSRegularExpression(pattern: "﴿[^﴾]*﴾")

    /// Prose split on «﴿…﴾» so Quran quotations can be set in Amiri (text unchanged).
    static func quranQuotes(_ text: String) -> [(t: String, q: Bool)] {
        let ns = text as NSString
        var out: [(t: String, q: Bool)] = []
        var from = 0
        for m in quote?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? [] {
            if m.range.location > from { out.append((ns.substring(with: NSRange(location: from, length: m.range.location - from)), false)) }
            out.append((ns.substring(with: m.range), true))
            from = m.range.location + m.range.length
        }
        if from < ns.length { out.append((ns.substring(from: from), false)) }
        return out
    }

    // MARK: attributed text

    static func color(_ k: Int, _ t: Theme) -> Color? { k == 1 ? t.gold : k == 2 ? t.result : nil }

    static func attr(_ runs: [Run], _ t: Theme) -> AttributedString {
        var out = AttributedString()
        for r in runs {
            var a = AttributedString(r.t)
            if let c = color(r.k, t) { a.foregroundColor = c }
            out += a
        }
        return out
    }

    /// EasyLine: the cause in gold, «←» muted, the result in green.
    static func easy(_ easy: String, _ t: Theme) -> AttributedString {
        let p = easyParts(easy)
        var c = AttributedString(p.cause)
        c.foregroundColor = t.gold
        guard let r = p.result else { return c }
        var arrow = AttributedString(" ← ")
        arrow.foregroundColor = t.muted
        var res = AttributedString(r)
        res.foregroundColor = t.result
        return c + arrow + res
    }

    /// «ماذا تفعل» in gold → «ثمرته» in green (the day programme rows).
    static func todo(_ todo: String, fruit: String?, _ t: Theme) -> AttributedString {
        var c = AttributedString(todo)
        c.foregroundColor = t.gold
        guard let fruit, !fruit.isEmpty else { return c }
        var arrow = AttributedString(" ← ")
        arrow.foregroundColor = t.muted
        var res = AttributedString(fruit)
        res.foregroundColor = t.result
        return c + arrow + res
    }

    /// WithQuran: the «﴿…﴾» parts in Amiri, nothing else changes.
    static func withQuran(_ text: String, size: CGFloat) -> AttributedString {
        var out = AttributedString()
        for p in quranQuotes(text) {
            var a = AttributedString(p.t)
            if p.q { a.font = AppFont.amiri(size * 1.1) }
            out += a
        }
        return out
    }
}
