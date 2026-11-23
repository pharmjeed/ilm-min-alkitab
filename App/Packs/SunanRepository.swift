import Foundation

/// Read-side of the sunan pack: the index with lookups and the state search (main thread, ~1 MB decoded once),
/// mirroring the website's `lib/sunan/view.ts`. Item chunks, «برنامج اليوم والليلة» and «ماذا يجلب هذا العمل؟»
/// are decoded off the main thread by `SunanStore`.
final class SunanRepo {
    /// Replaced (not mutated) when a downloaded version becomes active (`PackSync`).
    static var shared: SunanRepo { lock.lock(); defer { lock.unlock() }; return current }
    private static let lock = NSLock()
    private static var current = SunanRepo()
    static func reload() {
        let fresh = SunanRepo()
        lock.lock(); current = fresh; lock.unlock()
    }

    let index: SunanIndex?
    private let domainsById: [Int: SunanDomain]
    private let needsById: [Int: SunanNeed]
    private let statesById: [Int: SunanState]
    private let starStateByFp: [String: Int]

    private init() {
        let ix = Content.sunan()
        index = ix
        domainsById = Dictionary((ix?.domains ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        needsById = Dictionary((ix?.needs ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        statesById = Dictionary((ix?.states ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        starStateByFp = Dictionary((ix?.stars ?? []).map { ($0.fp, $0.stateId) }, uniquingKeysWith: { a, _ in a })
    }

    var domains: [SunanDomain] { index?.domains ?? [] }

    func domain(_ id: Int) -> SunanDomain? { domainsById[id] }
    func need(_ id: Int) -> SunanNeed? { needsById[id] }
    func state(_ id: Int) -> SunanState? { statesById[id] }
    func needs(of d: SunanDomain) -> [SunanNeed] { d.needIds.compactMap { needsById[$0] } }
    func states(of n: SunanNeed) -> [SunanState] { n.stateIds.compactMap { statesById[$0] } }
    /// The state of a «ابدأ بهذه» item, known from the index alone.
    func starState(fp: String) -> Int? { starStateByFp[fp] }

    // MARK: search (lib/sunan/view.ts searchStates)

    private struct Hay { let title, need, keywords, summary: String }
    private var hayCache: [Int: Hay]?

    private func haystacks() -> [Int: Hay] {
        if let h = hayCache { return h }
        var m: [Int: Hay] = [:]
        for s in index?.states ?? [] {
            m[s.id] = Hay(title: Arabic.normalize(s.title),
                          need: Arabic.normalize(need(s.needId)?.title ?? ""),
                          keywords: Arabic.normalize(s.keywords.joined(separator: " ")),
                          summary: Arabic.normalize(s.summary ?? ""))
        }
        hayCache = m
        return m
    }

    /// Query → normalized words (anything not a letter, digit or space becomes a space; words under two letters dropped).
    static func searchWords(_ q: String) -> [String] {
        var cleaned = String.UnicodeScalarView()
        for c in q.unicodeScalars {
            switch c.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
                 .decimalNumber, .letterNumber, .otherNumber:
                cleaned.append(c)
            default:
                cleaned.append(Arabic.isSpace(c) ? c : " ")
            }
        }
        return Arabic.normalize(String(cleaned))
            .split(separator: " ")
            .map(String.init)
            .filter { $0.utf16.count >= 2 }
    }

    struct StateHit: Identifiable {
        let state: SunanState
        let need: SunanNeed
        let score: Int
        var id: Int { state.id }
    }

    /// States whose title, need title, «كلمات البحث» or «الخلاصة» contain every word of the query;
    /// ranked title > keywords > need title > summary (+5 for the whole phrase in the title), then sheet order.
    func search(_ q: String, limit: Int = 60) -> [StateHit] {
        let words = Self.searchWords(q)
        guard !words.isEmpty else { return [] }
        let phrase = words.joined(separator: " ")
        let hay = haystacks()
        func has(_ h: String, _ w: String) -> Bool { h.range(of: w, options: .literal) != nil }
        var hits: [StateHit] = []
        for state in index?.states ?? [] {
            guard let h = hay[state.id] else { continue }
            var score = 0
            var all = true
            for w in words {
                let s = has(h.title, w) ? 4 : has(h.keywords, w) ? 3 : has(h.need, w) ? 2 : has(h.summary, w) ? 1 : 0
                if s == 0 { all = false; break }
                score += s
            }
            if !all { continue }
            if words.count > 1 && has(h.title, phrase) { score += 5 }
            if let n = need(state.needId) { hits.append(StateHit(state: state, need: n, score: score)) }
        }
        hits.sort { $0.score != $1.score ? $0.score > $1.score : $0.state.id < $1.state.id }
        return Array(hits.prefix(limit))
    }
}

/// One decoded chunk with its lookups.
struct SunanChunkData {
    let items: [SunnahItem]
    let byId: [String: SunnahItem]
    let byFp: [String: SunnahItem]
    init(_ items: [SunnahItem]) {
        self.items = items
        byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        byFp = Dictionary(items.map { ($0.fp, $0) }, uniquingKeysWith: { a, _ in a })
    }
}

/// The website's ItemView (lib/sunan/site.ts getItemByFp).
struct SunanItemView {
    let item: SunnahItem
    let state: SunanState
    /// For a «بمعناها» member: its representative.
    let rep: SunnahItem?
    /// For a representative: its members in sheet order.
    let members: [SunnahItem]
}

enum SunanPackError: Error { case unknownState(Int), unknownItem(String), missingExtra(String) }

/// Chunks (≤ ~0.9 MB each), day.json and deeds.json: decoded once, off the main thread, cached.
actor SunanStore {
    static let shared = SunanStore()

    private var chunks: [String: Task<SunanChunkData, Error>] = [:]
    private var fpMap: Task<[String: String], Error>?
    private var dayTask: Task<SunanDayFile, Error>?
    private var deedsTask: Task<SunanDeedsFile, Error>?

    /// A new version became active: chunk files keep their names across versions, so forget what was decoded.
    func reset() {
        chunks.removeAll()
        fpMap = nil
        dayTask = nil
        deedsTask = nil
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ file: String) throws -> T {
        guard let url = PackStore.shared.url(.sunan, file) else { throw PackError.missing(file) }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    func chunk(_ file: String) async throws -> SunanChunkData {
        let task: Task<SunanChunkData, Error>
        if let running = chunks[file] {
            task = running
        } else {
            task = Task.detached(priority: .userInitiated) {
                SunanChunkData(try Self.decode(SunanChunk.self, file).items)
            }
            chunks[file] = task
        }
        do {
            return try await task.value
        } catch {
            chunks[file] = nil // a later visit may retry
            throw error
        }
    }

    /// The state's representatives in sheet order (lib/sunan/site.ts getStateItems).
    func stateItems(_ stateId: Int) async throws -> [SunnahItem] {
        guard let state = SunanRepo.shared.state(stateId) else { throw SunanPackError.unknownState(stateId) }
        let data = try await chunk(state.chunk)
        return state.itemIds.compactMap { id in data.byId[id].flatMap { $0.stateId == stateId ? $0 : nil } }
    }

    /// fp → chunk file over every chunk (built lazily, once, from a minimal decode).
    private func chunkFile(forFp fp: String) async throws -> String? {
        let task: Task<[String: String], Error>
        if let running = fpMap {
            task = running
        } else {
            let files = SunanRepo.shared.index?.chunks.map(\.file) ?? []
            task = Task.detached(priority: .userInitiated) {
                struct FpOnly: Decodable { let items: [Row] }
                struct Row: Decodable { let fp: String }
                var map: [String: String] = [:]
                for f in files {
                    for r in try Self.decode(FpOnly.self, f).items { map[r.fp] = f }
                }
                return map
            }
            fpMap = task
        }
        do {
            return try await task.value[fp]
        } catch {
            fpMap = nil
            throw error
        }
    }

    /// An item by its stable fp. `stateHint` (known from every list in the app) avoids building the fp map.
    func item(fp: String, stateHint: Int? = nil) async throws -> SunanItemView {
        let repo = SunanRepo.shared
        var found: SunanChunkData?
        if let sid = stateHint ?? repo.starState(fp: fp), let st = repo.state(sid) {
            let d = try await chunk(st.chunk)
            if d.byFp[fp] != nil { found = d }
        }
        if found == nil, let file = try await chunkFile(forFp: fp) {
            found = try await chunk(file)
        }
        guard let data = found, let item = data.byFp[fp], let state = repo.state(item.stateId) else {
            throw SunanPackError.unknownItem(fp)
        }
        let rep = item.repOf.flatMap { data.byId[$0] }
        let members = (item.similar ?? []).compactMap { data.byId[$0] }
        return SunanItemView(item: item, state: state, rep: rep, members: members)
    }

    func day() async throws -> SunanDayFile {
        if let t = dayTask { return try await t.value }
        guard let file = SunanRepo.shared.index?.extras?.day?.file else { throw SunanPackError.missingExtra("day") }
        let t = Task.detached(priority: .userInitiated) { try Self.decode(SunanDayFile.self, file) }
        dayTask = t
        do { return try await t.value } catch { dayTask = nil; throw error }
    }

    func deeds() async throws -> SunanDeedsFile {
        if let t = deedsTask { return try await t.value }
        guard let file = SunanRepo.shared.index?.extras?.deeds?.file else { throw SunanPackError.missingExtra("deeds") }
        let t = Task.detached(priority: .userInitiated) { try Self.decode(SunanDeedsFile.self, file) }
        deedsTask = t
        do { return try await t.value } catch { deedsTask = nil; throw error }
    }
}
