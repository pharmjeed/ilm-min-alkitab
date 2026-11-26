import Foundation

/// Read-side of the names pack: the index with lookups (main thread, small) and the detail chunks
/// (decoded off the main thread by `NameDetails`, cached per chunk).
final class NamesRepo {
    /// Replaced (not mutated) when a downloaded version becomes active (`PackSync`).
    static var shared: NamesRepo { lock.lock(); defer { lock.unlock() }; return current }
    private static let lock = NSLock()
    private static var current = NamesRepo()
    static func reload() {
        let fresh = NamesRepo()
        lock.lock(); current = fresh; lock.unlock()
    }

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
        return names[Today.nameIndex(mode: ix.nameOfDay.mode, fixedIndex: nil, count: names.count, date: date)]
    }
}


enum NamesPackError: Error { case unknownName(Int) }

/// Name details live in chunk files (chunk-01 is «الله» alone, 2.7 MB): decoded once per chunk, off the main thread.
actor NameDetails {
    static let shared = NameDetails()
    private var chunks: [String: Task<[Int: NameDetail], Error>] = [:]

    /// A new version became active: chunk files keep their names across versions, so forget what was decoded.
    func reset() { chunks.removeAll() }

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
