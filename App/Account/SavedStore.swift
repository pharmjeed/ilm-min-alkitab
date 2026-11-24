import Foundation
import Observation

/// What can be saved: a Quran position of a name (shared with the website's favorites) or a sunnah (its fp).
enum SavedKey: Hashable {
    case position(name: Int, surah: Int, ayah: Int)
    case sunnah(String)

    var target: [String: String] {
        switch self {
        case .position(let n, let s, let a): return ["position": "\(n):\(s):\(a)"]
        case .sunnah(let fp): return ["sunnah": fp]
        }
    }
}

/// «محفوظاتي»: the account's saved items (owner's rule: nothing is saved on the device alone).
/// Platform API: GET/POST /api/app/v1/me/saved with the account's access token.
@MainActor @Observable
final class SavedStore {
    static let shared = SavedStore()

    enum Phase { case idle, loading, ready, failed }

    /// "nameId:surah:ayah", newest first.
    private(set) var positions: [String] = []
    /// Sunnah fingerprints, newest first.
    private(set) var sunan: [String] = []
    private(set) var phase: Phase = .idle

    var isEmpty: Bool { positions.isEmpty && sunan.isEmpty }

    func contains(_ k: SavedKey) -> Bool {
        switch k {
        case .position(let n, let s, let a): return positions.contains("\(n):\(s):\(a)")
        case .sunnah(let fp): return sunan.contains(fp)
        }
    }

    func reload() async {
        guard let token = await Account.shared.accessToken() else { clear(); return }
        phase = .loading
        var req = URLRequest(url: Site.url("/api/app/v1/me/saved"))
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        struct Body: Decodable { let positions: [String]; let sunan: [String] }
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { phase = .failed; return }
            let b = try JSONDecoder().decode(Body.self, from: data)
            positions = b.positions
            sunan = b.sunan
            phase = .ready
        } catch {
            phase = .failed
        }
    }

    @discardableResult
    func toggle(_ k: SavedKey) async -> Bool { await set(k, on: !contains(k)) }

    /// Saves or removes one item; the change shows at once and is undone if the server refuses it.
    @discardableResult
    func set(_ k: SavedKey, on: Bool) async -> Bool {
        guard let token = await Account.shared.accessToken() else { return false }
        if contains(k) == on { return true }
        apply(k, on)
        var req = URLRequest(url: Site.url("/api/app/v1/me/saved"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [on ? "add" : "remove": k.target])
        if let (_, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 {
            return true
        }
        apply(k, !on)
        return false
    }

    func clear() {
        positions = []
        sunan = []
        phase = .idle
    }

    private func apply(_ k: SavedKey, _ on: Bool) {
        switch k {
        case .position(let n, let s, let a):
            let key = "\(n):\(s):\(a)"
            positions.removeAll { $0 == key }
            if on { positions.insert(key, at: 0) }
        case .sunnah(let fp):
            sunan.removeAll { $0 == fp }
            if on { sunan.insert(fp, at: 0) }
        }
    }
}
