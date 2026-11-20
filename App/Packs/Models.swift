import Foundation

// Swift mirror of the pack contract (platform `lib/app-packs/types.ts`, PACK_SCHEMA = 1).
// Only the fields the app reads are declared; unknown keys are ignored by JSONDecoder.

struct NamesIndex: Decodable {
    let version: String
    let names: [NameCard]
    let doors: [Door]
}

struct NameCard: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let excerpt: String?
    let positions: Int
    let surahs: Int
    let hadiths: Int
}

struct Door: Decodable, Identifiable, Hashable {
    let id: Int
    let slug: String
    let label: String
    let description: String?
    let lead: String?
}

struct SunanIndex: Decodable {
    let version: String
    let stats: SunanStats
    let domains: [SunanDomain]
}

struct SunanStats: Decodable {
    let domains: Int
    let needs: Int
    let states: Int
    let items: Int
}

struct SunanDomain: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let needIds: [Int]
}

enum Content {
    static func names() -> NamesIndex? { try? PackStore.shared.load(NamesIndex.self, .names, "index.json") }
    static func sunan() -> SunanIndex? { try? PackStore.shared.load(SunanIndex.self, .sunan, "index.json") }
}
