import Foundation

/// Reads content packs (contract: platform `lib/app-packs/types.ts`).
/// Bundled snapshot: the `packs` folder reference in the app bundle (`assets/packs/<section>/<file>.pack`).
/// Downloaded versions (sync, later): Application Support/packs/<section>/<version>/<file>.json, preferred when active.
enum PackSection: String { case names, sunan }

final class PackStore {
    static let shared = PackStore()
    private let decoder = JSONDecoder()
    private var cache: [String: Any] = [:]
    private let lock = NSLock()

    /// URL of a pack file, preferring a downloaded active version over the bundled snapshot.
    func url(_ section: PackSection, _ file: String) -> URL? {
        if let active = activeVersion(section) {
            let u = Self.downloadsRoot.appendingPathComponent("\(section.rawValue)/\(active)/\(file)")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        let base = (file as NSString).deletingPathExtension
        return Bundle.main.url(forResource: "packs", withExtension: nil)?
            .appendingPathComponent("\(section.rawValue)/\(base).pack")
    }

    func load<T: Decodable>(_ type: T.Type, _ section: PackSection, _ file: String) throws -> T {
        let key = "\(section.rawValue)/\(file)/\(String(describing: T.self))"
        lock.lock(); if let hit = cache[key] as? T { lock.unlock(); return hit }; lock.unlock()
        guard let u = url(section, file) else { throw PackError.missing(file) }
        let value = try decoder.decode(T.self, from: Data(contentsOf: u))
        lock.lock(); cache[key] = value; lock.unlock()
        return value
    }

    func clearCache() { lock.lock(); cache.removeAll(); lock.unlock() }

    // MARK: downloaded versions (filled by PackSync)
    static var downloadsRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("packs", isDirectory: true)
    }
    func activeVersion(_ section: PackSection) -> String? {
        UserDefaults.standard.string(forKey: "packs.active.\(section.rawValue)")
    }
}

enum PackError: Error { case missing(String) }
