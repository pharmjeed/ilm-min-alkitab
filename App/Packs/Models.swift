import Foundation

// Swift mirror of the pack contract (platform `lib/app-packs/types.ts`, PACK_SCHEMA = 1).
// Only the fields the app reads are declared; unknown keys are ignored by JSONDecoder.

// MARK: - NAMES: index (names/index.json)

struct NamesIndex: Decodable {
    let version: String
    /// ISO-8601 UTC — shown in «المزيد» as the content's date.
    let generatedAt: String?
    let stats: NamesStats
    let nameOfDay: NameOfDaySetting
    /// All names in Excel order (= id order). «اسم اليوم» indexes THIS array.
    let names: [NameCard]
    /// «ماذا تشعر الآن؟» doors in order (16).
    let doors: [Door]
    /// Situations in door order, then the order inside the door.
    let situations: [Situation]
    /// «ما بأنفسهم»: inner types in order, each with its situations (صريح before مشترك).
    let inner: [InnerType]
    /// Markdown pages of the website (about / methodology), may be empty.
    let pages: NamesPages?
    let chunks: [NamesChunkRef]
}

struct NamesPages: Decodable {
    let about: String?
    let methodology: String?
}

struct NamesStats: Decodable {
    let names: Int
    let positions: Int
    let hadiths: Int
    let doors: Int
    let situations: Int
}

struct NameOfDaySetting: Decodable {
    let mode: String // sequential_by_date | random_daily | fixed
    let fixedId: Int?
}

struct NameCard: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let compound: Bool
    /// meaningExcerpt(summary || when_pray || meaning, 240), as under each name in a situation list.
    let excerpt: String
    let positions: Int
    let surahs: Int
    let hadiths: Int
    let category: String?
}

struct Door: Decodable, Identifiable, Hashable {
    let id: Int
    let slug: String
    let label: String
    let description: String
    let lead: String?
    let covers: [String]?
    let situationIds: [Int]
}

struct Situation: Decodable, Identifiable, Hashable {
    let id: Int
    let doorId: Int
    let slug: String
    let label: String
    let situation: String
    let innerLevel: String?
    let innerType: String?
    let names: [SituationName]
}

struct SituationName: Decodable, Hashable {
    let id: Int
    let verses: Int
    let hadiths: Int
}

struct InnerType: Decodable, Identifiable, Hashable {
    let slug: String
    let label: String
    let description: String
    let situations: [InnerSituationRef]
    var id: String { slug }
}

struct InnerSituationRef: Decodable, Hashable {
    let id: Int
    let level: String
}

struct NamesChunkRef: Decodable {
    let file: String
    let ids: [Int]
}

// MARK: - NAMES: detail chunks (names/chunk-NN.json)

struct NamesChunk: Decodable {
    let names: [NameDetail]
}

struct NameDetail: Decodable, Identifiable {
    let id: Int
    let name: String
    let compound: Bool
    let meaning: String
    let teaches: String
    let whenRecall: String
    let whenPray: String
    let summary: String
    /// Visible Quran positions, renumbered 1..n in display order.
    let verses: [Verse]
    /// Visible hadith witnesses, renumbered 1..n.
    let hadiths: [Hadith]
    /// «بطاقة الاسم في السنة» — present ⇒ the «في السنة» tab is shown.
    let sunnah: SunnahNameCard?
    /// Situations this name belongs to, in the website's order, with the scoped evidence.
    let situations: [NameInSituation]
}

struct Verse: Decodable, Identifiable, Hashable {
    let i: Int
    let of: Int
    let s: Int
    let surah: String
    let a: Int
    let last: Int?
    let text: String
    let prev: NeighbourAyah?
    let next: NeighbourAyah?
    let context: String?
    let reason: String?
    let adds: String?
    let draft: Bool?
    let dorar: [DorarRef]?
    var id: Int { i }
}

struct NeighbourAyah: Decodable, Hashable {
    let a: Int
    let text: String
}

struct DorarRef: Decodable, Hashable {
    let id: String
    let label: String
}

struct Hadith: Decodable, Identifiable, Hashable {
    let i: Int
    let of: Int
    let text: String
    let narrator: String?
    let source: String?
    let ref: String?
    let grade: String?
    let judgment: String?
    let url: String?
    let nameForm: String?
    let scene: String?
    let reason: String?
    let adds: String?
    let draft: Bool?
    var id: Int { i }
}

struct SunnahNameCard: Decodable {
    let card: String?
    let teaches: String?
    let whenRecall: String?
    let whenPray: String?
    let duaItems: String?
    let summary: String?
}

struct NameInSituation: Decodable, Hashable {
    let situationId: Int
    let verses: [ScopedEvidence]
    let hadiths: [ScopedEvidence]
}

struct ScopedEvidence: Decodable, Hashable {
    let i: Int
    let strength: String // direct | support
    let headline: String?
    let bridge: String?
}

// MARK: - SUNAN: see SunanModels.swift

enum Content {
    static func names() -> NamesIndex? { try? PackStore.shared.load(NamesIndex.self, .names, "index.json") }
    static func sunan() -> SunanIndex? { try? PackStore.shared.load(SunanIndex.self, .sunan, "index.json") }
}
