import SwiftUI

/// Ports of the website's Arabic helpers. Work on Unicode scalars (the website indexes UTF-16 units;
/// every Arabic letter and mark is one BMP scalar), never on Swift Characters (which merge marks).
enum Arabic {
    // MARK: lib/arabic/normalize.ts

    /// التشكيل + التطويل: U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED, U+0640.
    static func isTashkeel(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x610...0x61A, 0x64B...0x65F, 0x670, 0x6D6...0x6ED, 0x640: return true
        default: return false
        }
    }

    /// Python `\s` (the website mirrors Python's whitespace set).
    static func isSpace(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x09...0x0D, 0x1C...0x20, 0x85, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000: return true
        default: return false
        }
    }

    static func fold(_ s: Unicode.Scalar) -> Unicode.Scalar {
        switch s.value {
        case 0x625, 0x623, 0x622, 0x671: return "\u{627}" // إ أ آ ٱ → ا
        case 0x649: return "\u{64A}" // ى → ي
        case 0x629: return "\u{647}" // ة → ه
        case 0x624: return "\u{648}" // ؤ → و
        case 0x626: return "\u{64A}" // ئ → ي
        default: return s
        }
    }

    /// تطبيع عربي للمطابقة والبحث (identical to the website's normalize()).
    static func normalize(_ input: String) -> String {
        var out = String.UnicodeScalarView()
        var started = false
        var pendingSpace = false
        for c in input.unicodeScalars {
            if isTashkeel(c) { continue }
            if isSpace(c) {
                if started { pendingSpace = true }
                continue
            }
            if pendingSpace { out.append(" "); pendingSpace = false }
            started = true
            out.append(fold(c))
        }
        return String(out)
    }

    // MARK: lib/arabic/highlight.ts

    private static let stop: Set<String> = ["الله", "هو", "ذو", "ذي", "ذا", "رب", "لا", "الا", "في", "من", "عن", "ما", "ان", "و"]

    /// Python str.lstrip(chars).
    private static func lstrip(_ s: String, _ chars: String) -> String {
        let set = Set(chars.unicodeScalars)
        var v = Array(s.unicodeScalars)
        while let f = v.first, set.contains(f) { v.removeFirst() }
        return String(String.UnicodeScalarView(v))
    }

    /// Candidate search terms derived from a name: the whole name, then meaningful words (with and without «ال»).
    static func nameTerms(_ name: String) -> [String] {
        let nn = normalize(name)
        var terms: [String] = []
        func add(_ t: String) { if !terms.contains(t) { terms.append(t) } }
        if nn.unicodeScalars.count >= 3 { add(nn) }
        for w in nn.split(separator: " ").map(String.init) {
            if stop.contains(w) { continue }
            if w.unicodeScalars.count >= 3 { add(w) }
            let bare = lstrip(w, "ال")
            if bare.unicodeScalars.count >= 3 && bare != w { add(bare) }
        }
        // longest first (stable, like Array.prototype.sort)
        return terms.enumerated()
            .sorted { a, b in
                let la = a.element.unicodeScalars.count, lb = b.element.unicodeScalars.count
                return la != lb ? la > lb : a.offset < b.offset
            }
            .map(\.element)
    }

    private static func project(_ o: [Unicode.Scalar]) -> (norm: [Unicode.Scalar], map: [Int]) {
        var norm: [Unicode.Scalar] = []
        var map: [Int] = []
        var prevSpace = true
        for (i, ch) in o.enumerated() {
            if isTashkeel(ch) { continue }
            if ch.properties.isWhitespace {
                if prevSpace { continue }
                norm.append(" "); map.append(i); prevSpace = true
                continue
            }
            prevSpace = false
            norm.append(fold(ch)); map.append(i)
        }
        if norm.last == " " { norm.removeLast(); map.removeLast() }
        return (norm, map)
    }

    private static func indexOf(_ hay: [Unicode.Scalar], _ needle: [Unicode.Scalar], from: Int) -> Int? {
        guard !needle.isEmpty, hay.count >= needle.count, from <= hay.count - needle.count else { return nil }
        var i = from
        while i <= hay.count - needle.count {
            if hay[i] == needle[0] {
                var ok = true
                for k in 1..<needle.count where hay[i + k] != needle[k] { ok = false; break }
                if ok { return i }
            }
            i += 1
        }
        return nil
    }

    /// Ranges (scalar offsets in the ORIGINAL text) where any of `terms` occurs; non-overlapping, sorted, merged.
    static func highlightRanges(_ original: [Unicode.Scalar], _ terms: [String]) -> [Range<Int>] {
        guard !original.isEmpty, !terms.isEmpty else { return [] }
        let (norm, map) = project(original)
        var taken = [Bool](repeating: false, count: norm.count)
        var ranges: [Range<Int>] = []
        for t in terms {
            let tn = Array(normalize(t).unicodeScalars)
            if tn.isEmpty { continue }
            var from = 0
            while let at = indexOf(norm, tn, from: from) {
                let end = at + tn.count
                if !(at..<end).contains(where: { taken[$0] }) {
                    for k in at..<end { taken[k] = true }
                    let startO = map[at]
                    var endO = map[end - 1] + 1
                    while endO < original.count && isTashkeel(original[endO]) { endO += 1 }
                    ranges.append(startO..<endO)
                }
                from = at + 1
            }
        }
        ranges.sort { $0.lowerBound < $1.lowerBound }
        var merged: [Range<Int>] = []
        for r in ranges {
            if let last = merged.last, r.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, r.upperBound)
            } else {
                merged.append(r)
            }
        }
        return merged
    }

    /// The text exactly as stored, with the name's occurrences coloured (the website's <mark class="text-gold">).
    static func highlighted(_ text: String, terms: [String], mark: Color) -> AttributedString {
        let sc = Array(text.unicodeScalars)
        let ranges = highlightRanges(sc, terms)
        guard !ranges.isEmpty else { return AttributedString(text) }
        func str(_ r: Range<Int>) -> String { String(String.UnicodeScalarView(sc[r])) }
        var out = AttributedString()
        var pos = 0
        for r in ranges {
            if r.lowerBound > pos { out += AttributedString(str(pos..<r.lowerBound)) }
            var m = AttributedString(str(r))
            m.foregroundColor = mark
            out += m
            pos = r.upperBound
        }
        if pos < sc.count { out += AttributedString(str(pos..<sc.count)) }
        return out
    }

    // MARK: lib/arabic/count.ts

    struct CountForms { let one, two, few, many: String }
    static let positions = CountForms(one: "موضع واحد", two: "موضعان", few: "مواضع", many: "موضعًا")
    static let verses = CountForms(one: "آية واحدة", two: "آيتان", few: "آيات", many: "آية")
    static let situations = CountForms(one: "حالة واحدة", two: "حالتان", few: "حالات", many: "حالة")
    static let hadiths = CountForms(one: "حديث واحد", two: "حديثان", few: "أحاديث", many: "حديثًا")
    static let names = CountForms(one: "اسم واحد", two: "اسمان", few: "أسماء", many: "اسمًا")
    static let witnesses = CountForms(one: "شاهد واحد", two: "شاهدان", few: "شواهد", many: "شاهدًا")

    /// «موضع واحد» · «موضعان» · «5 مواضع» · «32 موضعًا».
    static func count(_ n: Int, _ f: CountForms) -> String {
        if n == 1 { return f.one }
        if n == 2 { return f.two }
        return "\(Num.fmt(n)) \(n <= 10 ? f.few : f.many)"
    }

    /// «N آيات · M أحاديث» hiding the zero part; empty when both are zero.
    static func supportLabel(_ verses: Int, _ hadiths: Int) -> String {
        var parts: [String] = []
        if verses > 0 { parts.append(count(verses, Self.verses)) }
        if hadiths > 0 { parts.append(count(hadiths, Self.hadiths)) }
        return parts.joined(separator: " · ")
    }

    /// components/feel/SituationItem.tsx namesCount(): «1 اسم» · «2 اسمان» · «5 أسماء» · «17 اسمًا».
    static func namesCount(_ n: Int) -> String {
        "\(n) \(n == 1 ? "اسم" : n == 2 ? "اسمان" : n <= 10 ? "أسماء" : "اسمًا")"
    }

    /// components/names/NameCard.tsx badges.
    static func positionsBadge(_ n: Int) -> String { "\(n) \(n == 1 ? "موضع" : n == 2 ? "موضعان" : n <= 10 ? "مواضع" : "موضعًا")" }
    static func surahsBadge(_ n: Int) -> String { "\(n) \(n == 1 ? "سورة" : n == 2 ? "سورتان" : n <= 10 ? "سور" : "سورة")" }

    // MARK: lib/content/titles.ts

    /// «اسم الله X», except when X itself starts with «الله» / «هو» / «الذي» / «ذو» / «ذي» / «رب».
    static func nameTitle(_ name: String) -> String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = n.split(separator: " ").first.map(String.init) ?? n
        return ["الله", "هو", "الذي", "ذو", "ذي", "رب"].contains(first) ? n : "اسم الله \(n)"
    }

    /// components/home/HomeSections.tsx firstLines(): the first n non-empty trimmed lines.
    static func firstLines(_ text: String, _ n: Int) -> String {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(n)
            .joined(separator: "\n")
    }

    /// `white-space: pre-line` text with the light markdown the content uses (`**bold**`).
    static func rich(_ text: String, size: CGFloat) -> AttributedString {
        let parts = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "**")
        let balanced = parts.count % 2 == 1
        var out = AttributedString()
        for (k, p) in parts.enumerated() {
            var a = AttributedString(balanced || k == 0 ? p : "**" + p)
            if balanced && k % 2 == 1 { a.font = AppFont.sans(size, .bold) }
            out += a
        }
        return out
    }
}
