import Foundation

/// Reads content packs (contract: platform `lib/app-packs/types.ts`).
/// Bundled snapshot: the `packs` folder reference in the app bundle (`assets/packs/<section>/<file>.pack`).
/// Downloaded versions (`PackSync`): Application Support/packs/<section>/<version>/<file>.json — the active one is used
/// for the WHOLE section (never mixed file by file with the bundle).
enum PackSection: String, CaseIterable { case names, sunan }

final class PackStore {
    static let shared = PackStore()
    private let decoder = JSONDecoder()
    private var cache: [String: Any] = [:]
    private let lock = NSLock()

    /// URL of a pack file: the active downloaded version when it is complete, else the bundled snapshot.
    func url(_ section: PackSection, _ file: String) -> URL? {
        if let dir = Self.activeDirectory(section) {
            return dir.appendingPathComponent(file)
        }
        let base = (file as NSString).deletingPathExtension
        return Self.bundleRoot?.appendingPathComponent("\(section.rawValue)/\(base).pack")
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

    // MARK: versions

    static var bundleRoot: URL? { Bundle.main.url(forResource: "packs", withExtension: nil) }

    static var downloadsRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("packs", isDirectory: true)
    }

    static func versionDirectory(_ s: PackSection, _ version: String) -> URL {
        downloadsRoot.appendingPathComponent("\(s.rawValue)/\(version)", isDirectory: true)
    }

    private static func key(_ kind: String, _ s: PackSection) -> String { "packs.\(kind).\(s.rawValue)" }

    /// The downloaded version in use (`packs.active.<section>`).
    static func activeVersion(_ s: PackSection) -> String? { UserDefaults.standard.string(forKey: key("active", s)) }
    /// A downloaded, verified version waiting to replace the active one (its pages were open when it arrived).
    static func readyVersion(_ s: PackSection) -> String? { UserDefaults.standard.string(forKey: key("ready", s)) }

    static func setActive(_ s: PackSection, _ version: String?) {
        let d = UserDefaults.standard
        if let version {
            d.set(version, forKey: key("active", s))
            if readyVersion(s) == version { d.removeObject(forKey: key("ready", s)) }
        } else {
            d.removeObject(forKey: key("active", s))
        }
    }

    static func setReady(_ s: PackSection, _ version: String?) {
        if let version { UserDefaults.standard.set(version, forKey: key("ready", s)) }
        else { UserDefaults.standard.removeObject(forKey: key("ready", s)) }
    }

    static func hasIndex(_ s: PackSection, _ version: String) -> Bool {
        FileManager.default.fileExists(atPath: versionDirectory(s, version).appendingPathComponent("index.json").path)
    }

    /// The active downloaded version's folder, when it is complete.
    static func activeDirectory(_ s: PackSection) -> URL? {
        guard let v = activeVersion(s), hasIndex(s, v) else { return nil }
        return versionDirectory(s, v)
    }

    static func isDownloaded(_ s: PackSection) -> Bool { activeDirectory(s) != nil }

    /// The version the app shows now: the active download, else the bundled snapshot.
    static func currentVersion(_ s: PackSection) -> String? {
        if isDownloaded(s), let v = activeVersion(s) { return v }
        return bundledVersion(s)
    }

    private static let bundled: [PackSection: String] = {
        var out: [PackSection: String] = [:]
        for s in PackSection.allCases {
            if let u = bundleRoot?.appendingPathComponent("\(s.rawValue)/index.pack"), let v = readVersion(u) { out[s] = v }
        }
        return out
    }()

    static func bundledVersion(_ s: PackSection) -> String? { bundled[s] }

    /// `"version"` is the third key of every index (`{"schema":1,"kind":…,"version":…`): read from the head, else decoded.
    private static func readVersion(_ url: URL) -> String? {
        if let h = try? FileHandle(forReadingFrom: url) {
            defer { try? h.close() }
            if let head = try? h.read(upToCount: 2048) {
                let s = String(decoding: head, as: UTF8.self)
                if let r = s.range(of: "\"version\":\"") {
                    let rest = s[r.upperBound...]
                    if let end = rest.firstIndex(of: "\"") { return String(rest[..<end]) }
                }
            }
        }
        struct V: Decodable { let version: String }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(V.self, from: data))?.version
    }

    /// Removes downloaded versions of a section except `keeping`.
    static func deleteDownloads(_ s: PackSection, keeping: Set<String>) {
        let fm = FileManager.default
        let dir = downloadsRoot.appendingPathComponent(s.rawValue, isDirectory: true)
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for u in items where !keeping.contains(u.lastPathComponent) { try? fm.removeItem(at: u) }
    }

    static func excludeFromBackup() {
        var root = downloadsRoot
        var rv = URLResourceValues()
        rv.isExcludedFromBackup = true
        try? root.setResourceValues(rv)
    }

    /// Runs once at launch, before any pack is read: a version that finished downloading while its pages were open
    /// becomes active now; a new app build (new bundled snapshot) drops older downloads (the next check fetches
    /// anything newer); incomplete folders and leftovers of an interrupted download are removed.
    static func prepareAtLaunch() {
        let d = UserDefaults.standard
        for s in PackSection.allCases {
            let bundleKey = key("bundle", s)
            if let b = bundledVersion(s), d.string(forKey: bundleKey) != b {
                setActive(s, nil)
                setReady(s, nil)
                d.set(b, forKey: bundleKey)
            }
            if let r = readyVersion(s) {
                if hasIndex(s, r) { setActive(s, r) }
                setReady(s, nil)
            }
            if let a = activeVersion(s), !hasIndex(s, a) { setActive(s, nil) }
            deleteDownloads(s, keeping: Set([activeVersion(s)].compactMap { $0 }))
        }
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(at: fm.temporaryDirectory, includingPropertiesForKeys: nil) {
            for u in items where u.lastPathComponent.hasPrefix("packsync-") { try? fm.removeItem(at: u) }
        }
    }
}

enum PackError: Error { case missing(String) }
