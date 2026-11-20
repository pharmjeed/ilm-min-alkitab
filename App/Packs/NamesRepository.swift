import Foundation

/// Read-side of the names pack: the index with lookups (main thread, small) and the detail chunks
/// (decoded off the main thread by `NameDetails`, cached per chunk).
final class NamesRepo {
    static let shared = NamesRepo()

    let index: NamesIndex?
    private let cardsById: [Int: NameCard]
    private let doorsById: [Int: Door]
    private let situationsById: [Int: Situation]
    private let situationsBySlug: [String: Situation]

    private init() {
        let ix = Content.names()
        index = ix
        cardsById = Dictionary((ix?.names ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        doorsById = Dictionary((ix?.doors ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        situationsById = Dictionary((ix?.situations ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var bySlug: [String: Situation] = [:]
        let doorSlug = Dictionary((ix?.doors ?? []).map { ($0.id, $0.slug) }, uniquingKeysWith: { a, _ in a })
        for s in ix?.situations ?? [] {
            bySlug["\(doorSlug[s.doorId] ?? "")|\(s.slug)"] = s
        }
        situationsBySlug = bySlug
    }

    var names: [NameCard] { index?.names ?? [] }
    var doors: [Door] { index?.doors ?? [] }
    var inner: [InnerType] { index?.inner ?? [] }

    func card(_ id: Int) -> NameCard? { cardsById[id] }
    func door(_ id: Int) -> Door? { doorsById[id] }
    func situation(_ id: Int) -> Situation? { situationsById[id] }
    func situations(of door: Door) -> [Situation] { door.situationIds.compactMap { situationsById[$0] } }
    /// «اسأل عن موقفك» answers carry the platform slugs (general_slug / sub_slug).
    func situation(doorSlug: String, subSlug: String) -> Situation? { situationsBySlug["\(doorSlug)|\(subSlug)"] }

    /// The inner type a situation belongs to on «ما بأنفسهم» (for the mark's link).
    func innerType(labelled label: String?) -> InnerType? {
        guard let label else { return nil }
        return inner.first { $0.label == label }
    }

    // MARK: «اسم اليوم» — same rule as the website (lib/content/daily.ts pickNameOfDay)

    static func dayNumber(_ date: Date = Date()) -> Int {
        Int((date.timeIntervalSince1970 * 1000 / 86_400_000).rounded(.down))
    }

    func nameOfDay(_ date: Date = Date()) -> NameCard? {
        guard let ix = index, !ix.names.isEmpty else { return nil }
        let names = ix.names
        if ix.nameOfDay.mode == "fixed", let fixed = ix.nameOfDay.fixedId {
            return names.first { $0.id == fixed } ?? names[0]
        }
        let d = Self.dayNumber(date)
        if ix.nameOfDay.mode == "random_daily" {
            var r = Mulberry32(seed: UInt32(truncatingIfNeeded: Int64(d) * 7919))
            return names[Int((r.next() * Double(names.count)).rounded(.down))]
        }
        return names[((d % names.count) + names.count) % names.count]
    }
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

enum NamesPackError: Error { case unknownName(Int) }

/// Name details live in chunk files (chunk-01 is «الله» alone, 2.7 MB): decoded once per chunk, off the main thread.
actor NameDetails {
    static let shared = NameDetails()
    private var chunks: [String: Task<[Int: NameDetail], Error>] = [:]

    func detail(_ id: Int) async throws -> NameDetail {
        guard let ref = NamesRepo.shared.index?.chunks.first(where: { $0.ids.contains(id) }) else {
            throw NamesPackError.unknownName(id)
        }
        let task: Task<[Int: NameDetail], Error>
        if let running = chunks[ref.file] {
            task = running
        } else {
            let file = ref.file
            task = Task.detached(priority: .userInitiated) {
                guard let url = PackStore.shared.url(.names, file) else { throw PackError.missing(file) }
                let data = try Data(contentsOf: url)
                let chunk = try JSONDecoder().decode(NamesChunk.self, from: data)
                return Dictionary(chunk.names.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            }
            chunks[ref.file] = task
        }
        do {
            let map = try await task.value
            guard let d = map[id] else { throw NamesPackError.unknownName(id) }
            return d
        } catch {
            chunks[ref.file] = nil // a later visit may retry
            throw error
        }
    }
}
