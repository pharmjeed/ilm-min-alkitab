import Foundation

// Swift mirror of the sunan part of the pack contract (platform `lib/app-packs/types.ts`, PACK_SCHEMA = 1).
// Only the fields the app reads are declared; unknown keys are ignored by JSONDecoder.

// MARK: - SUNAN: index (sunan/index.json)

struct SunanIndex: Decodable {
    let version: String
    let stats: SunanStats
    let domains: [SunanDomain]
    let needs: [SunanNeed]
    let states: [SunanState]
    /// «ابدأ بهذه» representatives in sheet order (fp → state without loading chunks).
    let stars: [SunanStar]
    let macro: [MacroSunnah]
    let pairs: [OpposingPair]
    let pairNotes: [String]
    let methodology: [MethodBlock]
    let chunks: [SunanChunkRef]
    let extras: SunanExtras?
}

struct SunanStats: Decodable {
    let domains: Int
    let needs: Int
    let states: Int
    let items: Int
    let dayItems: Int?
    let deeds: Int?
    let deedItems: Int?
}

struct SunanDomain: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let needIds: [Int]
}

struct SunanNeed: Decodable, Identifiable {
    let id: Int
    let domainId: Int
    let title: String
    /// "do" «ما تعمله» | "avoid" «ما تتجنّبه»
    let kind: String
    let counterpartNeedId: Int?
    let stateIds: [Int]
    let counts: SunanNeedCounts
    var avoid: Bool { kind == "avoid" }
}

struct SunanNeedCounts: Decodable {
    let items: Int
}

struct SunanState: Decodable, Identifiable {
    let id: Int
    let needId: Int
    let title: String
    let summary: String?
    let keywords: [String]
    let remedy: SunanRemedy?
    /// Representatives in sheet order (the reader guide).
    let itemIds: [String]
    let counts: SunanStateCounts
    /// File of the chunk holding this state's items, e.g. "need-12-2.json".
    let chunk: String
}

struct SunanRemedy: Decodable {
    let needId: Int
    let stateId: Int?
}

struct SunanStateCounts: Decodable {
    let items: Int
}

struct SunanStar: Decodable {
    let id: String
    let fp: String
    let stateId: Int
    let easy: String
}

struct MacroSunnah: Decodable, Identifiable {
    let id: Int
    let title: String
    let cause: String?
    let result: String?
    let domain: String
    let needIds: [Int]
    let verses: [MacroVerse]
    let hadithRefs: [String]
    let hadithText: String?
    let note: String?
}

/// `[surah, ayah, text]`.
struct MacroVerse: Decodable, Hashable {
    let s: Int
    let a: Int
    let text: String
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        s = try c.decode(Int.self)
        a = try c.decode(Int.self)
        text = try c.decode(String.self)
    }
}

struct OpposingPair: Decodable, Identifiable {
    let id: Int
    let positive: String
    let positiveRef: String?
    let negative: String
    let negativeRef: String?
}

struct MethodBlock: Decodable {
    let t: String
    let h: Bool?
}

struct SunanChunkRef: Decodable {
    let file: String
    let needId: Int
    let stateIds: [Int]
}

struct SunanExtras: Decodable {
    let day: SunanFileRef?
    let deeds: SunanFileRef?
}

struct SunanFileRef: Decodable {
    let file: String
}

// MARK: - SUNAN: item chunks (sunan/need-NN[-p].json)

struct SunanChunk: Decodable {
    let needId: Int
    let items: [SunnahItem]
}

struct SunnahItem: Decodable, Identifiable {
    let id: String
    /// Stable fingerprint across versions (the website's /sunan/item/<fp>).
    let fp: String
    let stateId: Int
    /// «السبب ← النتيجة».
    let easy: String
    let ijtihad: Bool?
    let ijtihadWhy: [String]?
    let star: Bool?
    let apply: SunnahApply?
    /// Members of a «بمعناها» group: the representative's id.
    let repOf: String?
    /// Representatives: member ids in sheet order.
    let similar: [String]?
    let otherNeedIds: [Int]?
    let ref: String
    let srcLabel: String?
    let quran: SunnahQuran?
    /// «النص كاملاً» with cause / result runs.
    let text: [SunanSeg]?
    let grade: String?
    let narrator: String?
    let muhaddith: String?
    let takhrij: String?
    let bab: String?
    let dorar: String?
    let merged: Int?
    let otherRefs: [String]?

    var isStar: Bool { star == true }
    var isIjtihad: Bool { ijtihad == true }
}

/// «طريقة التطبيق»: k = say «قل» | time «الوقت» | count «العدد» | read «اقرأ» (unknown kinds: no label).
struct SunnahApply: Decodable, Hashable {
    let k: String
    let t: String
}

struct SunnahQuran: Decodable {
    let s: Int
    let from: Int
    let to: Int
    /// "ayah (n) ayah (n)…" verbatim.
    let text: String
    /// [start, end, 1 | 2] in UTF-16 code units of `text`, end exclusive.
    let hl: [[Int]]
}

/// `string | [text, 1 = cause | 2 = result]`.
enum SunanSeg: Decodable {
    case plain(String)
    case run(String, Int)

    init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self = .plain(s)
            return
        }
        var c = try decoder.unkeyedContainer()
        let t = try c.decode(String.self)
        let k = try c.decode(Int.self)
        self = .run(t, k)
    }
}

// MARK: - SUNAN: «برنامج اليوم والليلة» (sunan/day.json)

struct SunanDayFile: Decodable {
    let periods: [SunanDayPeriod]
}

struct SunanDayPeriod: Decodable, Identifiable {
    let id: Int
    let title: String
    let times: [SunanDayTime]
}

struct SunanDayTime: Decodable, Identifiable {
    let id: Int
    let slug: String
    let title: String
    let items: [SunanDayItem]
}

struct SunanDayItem: Decodable {
    let itemId: String
    let fp: String
    let stateId: Int
    let star: Bool?
    let todo: String
    let fruit: String?
    let apply: SunnahApply?
    let grade: String?
    let srcLabel: String?
    let needIds: [Int]?
}

// MARK: - SUNAN: «ماذا يجلب هذا العمل؟» (sunan/deeds.json)

struct SunanDeedsFile: Decodable {
    let deeds: [SunanDeed]
}

struct SunanDeed: Decodable, Identifiable {
    let id: Int
    let slug: String
    let title: String
    /// "good" «عمل صالح» | "sin" «ذنب»
    let kind: String
    let fruitsCount: Int
    let needsCount: Int
    let highlights: String?
    let items: [SunanDeedItem]
    var sin: Bool { kind == "sin" }
}

struct SunanDeedItem: Decodable {
    let itemId: String
    let fp: String
    let stateId: Int
    let needId: Int
    let fruit: String
    let easy: String
    let ijtihad: Bool?
    let grade: String?
    let srcLabel: String?
}
