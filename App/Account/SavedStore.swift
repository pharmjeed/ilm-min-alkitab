import Foundation
import Observation

/// What can be saved (and put into collections): a name, a names-section situation, a sunan state,
/// a Quran position of a name (shared with the website's favorites) or a sunnah (its fp).
enum SavedKey: Hashable {
    case name(Int)
    case situation(Int)
    case state(Int)
    case position(name: Int, surah: Int, ayah: Int)
    case sunnah(String)

    var kind: String {
        switch self {
        case .name: return "name"
        case .situation: return "situation"
        case .state: return "state"
        case .position: return "position"
        case .sunnah: return "sunnah"
        }
    }

    var ref: String {
        switch self {
        case .name(let id), .situation(let id), .state(let id): return String(id)
        case .position(let n, let s, let a): return "\(n):\(s):\(a)"
        case .sunnah(let fp): return fp
        }
    }

    var body: [String: String] { ["kind": kind, "ref": ref] }

    init?(kind: String, ref: String) {
        switch kind {
        case "name": guard let i = Int(ref) else { return nil }; self = .name(i)
        case "situation": guard let i = Int(ref) else { return nil }; self = .situation(i)
        case "state": guard let i = Int(ref) else { return nil }; self = .state(i)
        case "sunnah": self = .sunnah(ref)
        case "position":
            let p = ref.split(separator: ":").compactMap { Int($0) }
            guard p.count == 3 else { return nil }
            self = .position(name: p[0], surah: p[1], ayah: p[2])
        default: return nil
        }
    }
}

struct SavedCollection: Identifiable, Hashable {
    let id: String
    var title: String
    /// Newest first.
    var items: [SavedKey]
}

/// «محفوظاتي»: the account's saved items and collections (owner's rule: nothing is saved on the device alone).
/// Platform API: /api/app/v1/me/saved and /api/app/v1/me/collections with the account's access token.
@MainActor @Observable
final class SavedStore {
    static let shared = SavedStore()

    enum Phase { case idle, loading, ready, failed }

    /// Every saved item, newest first within its kind.
    private(set) var names: [SavedKey] = []
    private(set) var situations: [SavedKey] = []
    private(set) var states: [SavedKey] = []
    private(set) var positions: [SavedKey] = []
    private(set) var sunan: [SavedKey] = []
    private(set) var collections: [SavedCollection] = []
    private(set) var phase: Phase = .idle

    var isEmpty: Bool { names.isEmpty && situations.isEmpty && states.isEmpty && positions.isEmpty && sunan.isEmpty }

    func contains(_ k: SavedKey) -> Bool { list(of: k).contains(k) }

    func collectionIds(containing k: SavedKey) -> Set<String> {
        Set(collections.filter { $0.items.contains(k) }.map(\.id))
    }

    // MARK: loading

    func reload() async {
        guard let token = await Account.shared.accessToken() else { clear(); return }
        phase = .loading
        struct Item: Decodable { let kind: String; let ref: String }
        struct Col: Decodable { let id: String; let title: String; let items: [Item] }
        struct Body: Decodable {
            let positions: [String]
            let sunan: [String]
            let names: [String]?
            let situations: [String]?
            let states: [String]?
            let collections: [Col]?
        }
        do {
            let (data, resp) = try await URLSession.shared.data(for: request("/api/app/v1/me/saved", token: token))
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { phase = .failed; return }
            let b = try JSONDecoder().decode(Body.self, from: data)
            positions = b.positions.compactMap { SavedKey(kind: "position", ref: $0) }
            sunan = b.sunan.map { .sunnah($0) }
            names = (b.names ?? []).compactMap { SavedKey(kind: "name", ref: $0) }
            situations = (b.situations ?? []).compactMap { SavedKey(kind: "situation", ref: $0) }
            states = (b.states ?? []).compactMap { SavedKey(kind: "state", ref: $0) }
            collections = (b.collections ?? []).map { c in
                SavedCollection(id: c.id, title: c.title, items: c.items.compactMap { SavedKey(kind: $0.kind, ref: $0.ref) })
            }
            phase = .ready
        } catch {
            phase = .failed
        }
    }

    // MARK: saving

    @discardableResult
    func toggle(_ k: SavedKey) async -> Bool { await set(k, on: !contains(k)) }

    /// Saves or removes one item; the change shows at once and is undone if the server refuses it.
    /// Removing also takes it out of every collection.
    @discardableResult
    func set(_ k: SavedKey, on: Bool) async -> Bool {
        if contains(k) == on { return true }
        let before = collections
        apply(k, on)
        if !on { for i in collections.indices { collections[i].items.removeAll { $0 == k } } }
        let ok = await post("/api/app/v1/me/saved", [on ? "add" : "remove": k.body])
        if !ok {
            apply(k, !on)
            collections = before
        }
        return ok
    }

    /// Puts an item into a collection or takes it out (putting it in also saves it).
    @discardableResult
    func collect(_ k: SavedKey, in collectionId: String, on: Bool) async -> Bool {
        guard let i = collections.firstIndex(where: { $0.id == collectionId }) else { return false }
        let wasSaved = contains(k)
        let before = collections[i].items
        collections[i].items.removeAll { $0 == k }
        if on {
            collections[i].items.insert(k, at: 0)
            if !wasSaved { apply(k, true) }
        }
        let ok = await post("/api/app/v1/me/saved", ["collect": k.body, "collection": collectionId, "on": on])
        if !ok {
            if let j = collections.firstIndex(where: { $0.id == collectionId }) { collections[j].items = before }
            if on && !wasSaved { apply(k, false) }
        }
        return ok
    }

    // MARK: collections

    /// Creates a collection; returns it, or nil (with the reason in `lastError`).
    func createCollection(_ title: String) async -> SavedCollection? {
        lastError = nil
        let clean = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !clean.isEmpty else { return nil }
        guard let token = await Account.shared.accessToken() else { return nil }
        var req = request("/api/app/v1/me/collections", token: token)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["create": String(clean.prefix(60))])
        struct Resp: Decodable { struct C: Decodable { let id: String; let title: String }; let collection: C }
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else {
            lastError = "تعذّر إنشاء المجموعة. تحقّق من الاتصال."
            return nil
        }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200, let r = try? JSONDecoder().decode(Resp.self, from: data) else {
            lastError = code == 409 ? "بلغتَ الحد الأعلى للمجموعات (50)." : "تعذّر إنشاء المجموعة."
            return nil
        }
        let c = SavedCollection(id: r.collection.id, title: r.collection.title, items: [])
        collections.append(c)
        return c
    }

    @discardableResult
    func renameCollection(_ id: String, to title: String) async -> Bool {
        let clean = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !clean.isEmpty, let i = collections.firstIndex(where: { $0.id == id }) else { return false }
        let old = collections[i].title
        collections[i].title = String(clean.prefix(60))
        let ok = await post("/api/app/v1/me/collections", ["rename": id, "title": collections[i].title])
        if !ok, let j = collections.firstIndex(where: { $0.id == id }) { collections[j].title = old }
        return ok
    }

    /// Deletes a collection; its items stay in «محفوظاتي».
    @discardableResult
    func deleteCollection(_ id: String) async -> Bool {
        let before = collections
        collections.removeAll { $0.id == id }
        let ok = await post("/api/app/v1/me/collections", ["delete": id])
        if !ok { collections = before }
        return ok
    }

    private(set) var lastError: String?

    func clear() {
        names = []; situations = []; states = []; positions = []; sunan = []
        collections = []
        phase = .idle
    }

    // MARK: plumbing

    private func list(of k: SavedKey) -> [SavedKey] {
        switch k {
        case .name: return names
        case .situation: return situations
        case .state: return states
        case .position: return positions
        case .sunnah: return sunan
        }
    }

    private func apply(_ k: SavedKey, _ on: Bool) {
        func edit(_ a: inout [SavedKey]) {
            a.removeAll { $0 == k }
            if on { a.insert(k, at: 0) }
        }
        switch k {
        case .name: edit(&names)
        case .situation: edit(&situations)
        case .state: edit(&states)
        case .position: edit(&positions)
        case .sunnah: edit(&sunan)
        }
    }

    private func request(_ path: String, token: String) -> URLRequest {
        var req = URLRequest(url: Site.url(path))
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func post(_ path: String, _ body: [String: Any]) async -> Bool {
        guard let token = await Account.shared.accessToken() else { return false }
        var req = request(path, token: token)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }
}
