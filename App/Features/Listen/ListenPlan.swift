import Foundation

/// «الاستماع» (owner 2026-11-27: «يقرأ موضع اسم او سنة بكامل محتواه ويمر على كل ما في المنصة»). A track is one
/// position of a name (or one of its hadiths, or one of its sections), or one sunnah; its parts are what the phone's
/// voice says and the ayat Mishary Alafasy recites — the Quran is never read by the phone's voice.
struct ListenTrack: Equatable {
    /// On the lock screen: the name, or the sunnah.
    var title: String
    /// Under it: the position, the hadith, or the sunnah's group.
    var subtitle: String
    var parts: [ListenPart]

    var ayat: [(Int, Int)] {
        parts.flatMap { p -> [(Int, Int)] in
            guard case .ayat(let s, let from, let to) = p else { return [] }
            return (from...max(from, to)).map { (s, $0) }
        }
    }
}

enum ListenPart: Equatable {
    case say(String)
    case ayat(surah: Int, from: Int, to: Int)
}

enum ListenSection: String, Codable { case names, sunan }

/// Where the player is: the section, the unit (a name in the order of the owner's file, or a state of the sunan), and
/// the track inside it.
struct ListenCursor: Codable, Equatable {
    var section: ListenSection
    var unit: Int
    var track: Int
}

enum ListenPlan {
    // MARK: units

    static func unitCount(_ section: ListenSection) -> Int {
        switch section {
        case .names: return NamesRepo.shared.names.count
        case .sunan: return sunanStates.count
        }
    }

    static func unitTitle(_ section: ListenSection, _ unit: Int) -> String {
        switch section {
        case .names: return NamesRepo.shared.names[safe: unit]?.name ?? ""
        case .sunan: return sunanStates[safe: unit]?.title ?? ""
        }
    }

    /// The states with sunan, in the pack's order.
    static var sunanStates: [SunanState] {
        (SunanRepo.shared.index?.states ?? []).filter { $0.counts.items > 0 }
    }

    static func nameUnit(_ id: Int) -> Int? { NamesRepo.shared.names.firstIndex { $0.id == id } }
    static func stateUnit(_ id: Int) -> Int? { sunanStates.firstIndex { $0.id == id } }

    static func tracks(_ section: ListenSection, _ unit: Int) async -> [ListenTrack] {
        switch section {
        case .names:
            guard let card = NamesRepo.shared.names[safe: unit],
                  let d = try? await NameDetails.shared.detail(card.id) else { return [] }
            return nameTracks(d)
        case .sunan:
            guard let st = sunanStates[safe: unit],
                  let reps = try? await SunanStore.shared.stateItems(st.id) else { return [] }
            var out: [ListenTrack] = []
            for rep in reps {
                out.append(sunnahTrack(rep, st))
                // «بمعناها»: the sunan of the same meaning, after their representative
                if let view = try? await SunanStore.shared.item(fp: rep.fp, stateHint: st.id) {
                    for m in view.members { out.append(sunnahTrack(m, st)) }
                }
            }
            return out
        }
    }

    // MARK: a name

    /// The name and its meaning, then every position (the ayah before, the ayah, the ayah after, the context, why the
    /// name is mentioned, what it adds), every hadith, then «ماذا يعلّمني» … «الزبدة» — the name page's content.
    static func nameTracks(_ d: NameDetail) -> [ListenTrack] {
        var out: [ListenTrack] = []
        out.append(ListenTrack(title: d.name, subtitle: "معنى الاسم",
                               parts: [.say("اسم الله: \(d.name).")] + section("معنى الاسم", d.meaning)))
        for v in d.verses {
            var p: [ListenPart] = [.say("الموضع \(v.i) من \(v.of): سورة \(v.surah)، \(ayahWords(v.a, v.last)).")]
            if let prev = v.prev {
                p.append(.say("الآية السابقة."))
                p.append(.ayat(surah: v.s, from: prev.a, to: prev.a))
            }
            p.append(.say("الآية."))
            p.append(.ayat(surah: v.s, from: v.a, to: v.last ?? v.a))
            if let next = v.next {
                p.append(.say("الآية اللاحقة."))
                p.append(.ayat(surah: v.s, from: next.a, to: next.a))
            }
            p += section("السياق", v.context)
            p += section("سبب ذكر الاسم", v.reason)
            p += section("ما يضيفه هذا الموضع", v.adds)
            out.append(ListenTrack(title: d.name, subtitle: "\(v.surah) \(v.a) · الموضع \(v.i) من \(v.of)", parts: p))
        }
        for h in d.hadiths {
            var p: [ListenPart] = [.say("الحديث \(h.i) من \(h.of).")]
            p += speech(h.text)
            let src = [h.narrator.map { "الراوي: \($0)" }, h.source.map { "المصدر: \($0)" }, h.grade.map { "الدرجة: \($0)" }]
                .compactMap { $0 }.filter { !$0.isEmpty }
            if !src.isEmpty { p.append(.say(src.joined(separator: "، ") + ".")) }
            p += section("المشهد", h.scene)
            p += section("سبب ذكر الاسم", h.reason)
            p += section("ما يضيفه هذا الحديث", h.adds)
            out.append(ListenTrack(title: d.name, subtitle: "الحديث \(h.i) من \(h.of)", parts: p))
        }
        for (title, text) in [("ماذا يعلّمني", d.teaches), ("متى أستحضره", d.whenRecall),
                              ("متى أدعو به", d.whenPray), ("الزبدة", d.summary)] {
            let p = section(title, text)
            if !p.isEmpty { out.append(ListenTrack(title: d.name, subtitle: title, parts: [.say("اسم الله: \(d.name).")] + p)) }
        }
        return out
    }

    private static func ayahWords(_ a: Int, _ last: Int?) -> String {
        guard let last, last != a else { return "الآية \(a)" }
        return "الآيات من \(a) إلى \(last)"
    }

    // MARK: a sunnah

    /// Its group, «السبب ← النتيجة», the text (an ayah recited; a hadith read), its source, and how to apply it.
    static func sunnahTrack(_ it: SunnahItem, _ st: SunanState) -> ListenTrack {
        let parts = SunanText.easyParts(it.easy)
        var p: [ListenPart] = [.say("\(st.title).")]
        p.append(.say(parts.result.map { "\(parts.cause)، وثمرتها: \($0)." } ?? "\(parts.cause)."))
        if let q = it.quran {
            p.append(.say("قال الله تعالى."))
            p.append(.ayat(surah: q.s, from: q.from, to: q.to))
        } else if let segs = it.text {
            let text = segs.map { s -> String in
                switch s {
                case .plain(let t): return t
                case .run(let t, _): return t
                }
            }.joined()
            p += speech(text)
        }
        let src = SunanText.sourceLine(it).replacingOccurrences(of: " · ", with: "، ")
        if !src.isEmpty { p.append(.say(src + ".")) }
        if let a = it.apply, !a.t.isEmpty { p += section("طريقة التطبيق", a.t) }
        return ListenTrack(title: parts.cause, subtitle: st.title, parts: p)
    }

    // MARK: text → parts

    /// A titled section: «العنوان.» then its text — nothing when the text is empty.
    static func section(_ title: String, _ text: String?) -> [ListenPart] {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return [] }
        return [.say("\(title).")] + speech(t)
    }

    /// The text for the voice; a quote between ﴿ ﴾ becomes the recitation of its ayah (QuranIndex), or is left out when
    /// its ayah cannot be told — the phone's voice never reads the Quran.
    static func speech(_ text: String) -> [ListenPart] {
        var out: [ListenPart] = []
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "﴿") {
            let before = clean(String(rest[..<open]))
            if !before.isEmpty { out.append(.say(before)) }
            let afterOpen = rest.index(after: open)
            guard let close = rest[afterOpen...].firstIndex(of: "﴾") else { rest = rest[afterOpen...]; break }
            if let hit = QuranIndex.find(String(rest[afterOpen..<close])) {
                out.append(.ayat(surah: hit.surah, from: hit.from, to: hit.to))
            }
            rest = rest[rest.index(after: close)...]
        }
        let tail = clean(String(rest))
        if !tail.isEmpty { out.append(.say(tail)) }
        return out
    }

    /// Without the page's marks: bold stars, headings, table bars, bullets, brackets of references, arrows.
    static func clean(_ s: String) -> String {
        var t = s
        for (a, b) in [("**", ""), ("__", ""), ("#", ""), ("|", "، "), ("←", "، "), ("→", "، "), ("•", ""),
                       ("[", ""), ("]", ""), ("«", ""), ("»", "")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        let lines = t.components(separatedBy: .newlines).map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            while l.hasPrefix("-") || l.hasPrefix("*") { l = String(l.dropFirst()).trimmingCharacters(in: .whitespaces) }
            return l
        }.filter { !$0.isEmpty }
        return lines.joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
