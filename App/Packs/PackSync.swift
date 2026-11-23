import Foundation
import CryptoKit

// MARK: - Manifest (platform lib/app-packs/types.ts: AppManifest, SectionManifest, PackFileRef)

struct AppManifest: Decodable {
    struct Sections: Decodable {
        let names: SectionManifest?
        let sunan: SectionManifest?
    }
    let schema: Int
    let sections: Sections

    func section(_ s: PackSection) -> SectionManifest? {
        switch s {
        case .names: return sections.names
        case .sunan: return sections.sunan
        }
    }
}

struct SectionManifest: Decodable {
    let version: String
    let publishedAt: String?
    /// The oldest app PACK_SCHEMA able to read it.
    let schema: Int
    /// Every file of the section, "index.json" first.
    let files: [PackFileRef]
    var totalBytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
}

struct PackFileRef: Decodable {
    let file: String
    let bytes: Int64
    let sha256: String
}

enum PackSyncError: Error { case network, notPublished, mismatch, invalid }

// MARK: - Download (off the main actor; never touches the version in use)

/// A section is downloaded completely into a temporary folder, every file checked (size + sha256), the index decoded,
/// and only then moved into Application Support/packs/<section>/<version>/ in one step. Any failure leaves nothing behind.
enum PackDownloader {
    /// PACK_SCHEMA this app reads.
    static let supportedSchema = 1

    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.urlCache = nil
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = 30
        c.timeoutIntervalForResource = 900
        return URLSession(configuration: c)
    }()

    /// GET /api/app/v1/manifest — the exact URL (the server redirects any query string).
    static func fetchManifest() async throws -> AppManifest {
        let pair: (Data, URLResponse)
        do { pair = try await session.data(from: Site.url("/api/app/v1/manifest")) } catch { throw PackSyncError.network }
        let (data, resp) = pair
        guard let http = resp as? HTTPURLResponse else { throw PackSyncError.network }
        if http.statusCode == 404 { throw PackSyncError.notPublished }
        guard http.statusCode == 200 else { throw PackSyncError.network }
        do { return try JSONDecoder().decode(AppManifest.self, from: data) } catch { throw PackSyncError.invalid }
    }

    private static let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_".unicodeScalars)

    static func isSafeName(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 80 && !s.hasPrefix(".") && s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Downloads, verifies and installs one section version. `progress` gets the bytes done so far (any thread).
    static func download(_ s: PackSection, _ m: SectionManifest, progress: @escaping @Sendable (Int64) -> Void) async throws {
        let names = m.files.map(\.file)
        guard isSafeName(m.version), m.version.hasPrefix(s.rawValue + "-"),
              names.first == "index.json", Set(names).count == names.count,
              names.allSatisfy({ isSafeName($0) && $0.hasSuffix(".json") }) else { throw PackSyncError.invalid }
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("packsync-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) } // gone already after a successful move
        let files = m.files
        let version = m.version
        try await withThrowingTaskGroup(of: Int64.self) { group in
            var next = 0
            while next < min(4, files.count) {
                let f = files[next]
                group.addTask { try await PackDownloader.fetch(s, version, f, into: tmp) }
                next += 1
            }
            var done: Int64 = 0
            while let n = try await group.next() {
                done += n
                progress(done)
                if next < files.count {
                    let f = files[next]
                    group.addTask { try await PackDownloader.fetch(s, version, f, into: tmp) }
                    next += 1
                }
            }
        }
        try verifyIndex(s, version: version, files: Set(names), in: tmp)
        let dest = PackStore.versionDirectory(s, version)
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.moveItem(at: tmp, to: dest)
        PackStore.excludeFromBackup()
    }

    /// GET /api/app/v1/packs/<section>/<version>/<file> (exact URL), then size + sha256 before it is kept.
    private static func fetch(_ s: PackSection, _ version: String, _ f: PackFileRef, into dir: URL) async throws -> Int64 {
        let url = Site.url("/api/app/v1/packs/\(s.rawValue)/\(version)/\(f.file)")
        let pair: (URL, URLResponse)
        do { pair = try await session.download(from: url) } catch { throw PackSyncError.network }
        let (loc, resp) = pair
        let fm = FileManager.default
        defer { try? fm.removeItem(at: loc) }
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw PackSyncError.network }
        let attrs = try? fm.attributesOfItem(atPath: loc.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
        guard size == f.bytes, try sha256Hex(loc) == f.sha256.lowercased() else { throw PackSyncError.mismatch }
        try fm.moveItem(at: loc, to: dir.appendingPathComponent(f.file))
        return f.bytes
    }

    static func sha256Hex(_ url: URL) throws -> String {
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        var hasher = SHA256()
        while let chunk = try h.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// The new index must decode with this app's models, carry the manifest's version, and list only downloaded files.
    private static func verifyIndex(_ s: PackSection, version: String, files: Set<String>, in dir: URL) throws {
        var ok = false
        do {
            let data = try Data(contentsOf: dir.appendingPathComponent("index.json"))
            switch s {
            case .names:
                let ix = try JSONDecoder().decode(NamesIndex.self, from: data)
                ok = ix.version == version && !ix.names.isEmpty && ix.chunks.allSatisfy { files.contains($0.file) }
            case .sunan:
                let ix = try JSONDecoder().decode(SunanIndex.self, from: data)
                let needed = ix.chunks.map(\.file) + [ix.extras?.day?.file, ix.extras?.deeds?.file].compactMap { $0 }
                ok = ix.version == version && !ix.domains.isEmpty && needed.allSatisfy { files.contains($0) }
            }
        } catch {
            throw PackSyncError.invalid
        }
        if !ok { throw PackSyncError.invalid }
    }
}

// MARK: - Sync state (main actor)

/// Content updates from the platform: silently after the first frame of a launch (and when the app returns after
/// half a day), or from «المزيد» → «تحقّق من التحديث» with progress and an Arabic result.
/// A downloaded version replaces the current one right away when none of its section's pages is open; otherwise it
/// waits until they close (or the next launch). From «المزيد» it is applied at once (the open pages go back first).
@MainActor
final class PackSync: ObservableObject {
    static let shared = PackSync()

    enum Phase: Equatable {
        case idle
        case checking
        case downloading(Int)
        case done(String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    /// Bumped each time a downloaded version becomes active — screens showing counts or versions observe it.
    @Published private(set) var contentVersion = 0
    @Published private(set) var lastCheck: Date?
    weak var nav: AppNav?
    private var running = false
    private var checkedThisLaunch = false

    private init() {
        lastCheck = UserDefaults.standard.object(forKey: "packs.lastCheck") as? Date
    }

    var busy: Bool {
        switch phase {
        case .checking, .downloading: return true
        default: return false
        }
    }

    /// Launch (after the first frame) and returning to the app: silent; at most every 12 hours after the launch check.
    func autoCheck() async {
        guard !Route.isCI else { return }
        if checkedThisLaunch, let last = lastCheck, Date().timeIntervalSince(last) < 12 * 3600 { return }
        checkedThisLaunch = true
        await check(userInitiated: false)
    }

    func check(userInitiated: Bool) async {
        guard !running else { return }
        running = true
        defer { running = false }
        if userInitiated { phase = .checking }
        do {
            let manifest = try await PackDownloader.fetchManifest()
            lastCheck = Date()
            UserDefaults.standard.set(lastCheck, forKey: "packs.lastCheck")
            var todo: [(PackSection, SectionManifest)] = []
            var tooNew = false
            for s in PackSection.allCases {
                guard let m = manifest.section(s) else { continue }
                if m.schema > PackDownloader.supportedSchema { tooNew = true; continue }
                if m.version == (PackStore.readyVersion(s) ?? PackStore.currentVersion(s)) { continue }
                todo.append((s, m))
            }
            let total = max(Int64(1), todo.reduce(Int64(0)) { $0 + $1.1.totalBytes })
            var base: Int64 = 0
            if userInitiated && !todo.isEmpty { phase = .downloading(0) }
            for (s, m) in todo {
                let start = base
                try await PackDownloader.download(s, m) { done in
                    Task { @MainActor in PackSync.shared.progress(start + done, of: total) }
                }
                base += m.totalBytes
                PackStore.setReady(s, m.version)
            }
            let applied = await activateReady(force: userInitiated)
            if userInitiated {
                if !applied.isEmpty { phase = .done(SyncText.updated(applied)) }
                else { phase = .done(tooNew ? SyncText.tooNew : SyncText.upToDate) }
            } else {
                phase = .idle
            }
        } catch {
            _ = await activateReady(force: userInitiated) // a section finished before the failure is still good
            phase = userInitiated ? .failed(SyncText.failure(error as? PackSyncError ?? .network)) : .idle
        }
    }

    private func progress(_ done: Int64, of total: Int64) {
        guard case .downloading = phase else { return }
        phase = .downloading(min(99, Int(Double(done) * 100 / Double(total))))
    }

    /// Makes waiting versions active. Without `force`, a section whose pages are open keeps waiting.
    @discardableResult
    func activateReady(force: Bool) async -> [PackSection] {
        var applied: [PackSection] = []
        for s in PackSection.allCases {
            guard let v = PackStore.readyVersion(s) else { continue }
            if let nav, nav.uses(s) {
                if !force { continue }
                nav.leave(s)
            }
            PackStore.setActive(s, v)
            applied.append(s)
        }
        guard !applied.isEmpty else { return [] }
        PackStore.shared.clearCache()
        for s in applied {
            switch s {
            case .names: NamesRepo.reload()
            case .sunan: SunanRepo.reload()
            }
        }
        if applied.contains(.names) { await NameDetails.shared.reset() }
        if applied.contains(.sunan) { await SunanStore.shared.reset() }
        for s in applied {
            PackStore.deleteDownloads(s, keeping: Set([PackStore.activeVersion(s)].compactMap { $0 }))
        }
        contentVersion += 1
        if applied.contains(.names) { ReminderScheduler.shared.reschedule() }
        return applied
    }
}

/// Wording of «المزيد» → «المحتوى».
enum SyncText {
    static func title(_ s: PackSection) -> String {
        switch s {
        case .names: return "كنز الأسماء الحسنى"
        case .sunan: return "سر علم السنن والأسباب"
        }
    }
    static let upToDate = "لديك أحدث نسخة من المحتوى."
    static let tooNew = "في المنصة نسخة أحدث تحتاج إصدارًا أحدث من التطبيق."
    static func updated(_ s: [PackSection]) -> String {
        "تم التحديث: " + s.map { "«\(title($0))»" }.joined(separator: " و")
    }
    static func failure(_ e: PackSyncError) -> String {
        switch e {
        case .network: return "تعذّر الاتصال بالمنصة. تحقّق من الإنترنت ثم حاول مرة أخرى؛ وبقي المحتوى الحالي كما هو."
        case .notPublished: return "لا توجد تحديثات منشورة بعد."
        case .mismatch: return "وصل ملفٌ غير مطابق، فلم يُعتمد التحديث وبقي المحتوى الحالي كما هو."
        case .invalid: return "تعذّر قراءة التحديث، فبقي المحتوى الحالي كما هو."
        }
    }
    static func progress(_ phase: PackSync.Phase) -> String? {
        switch phase {
        case .checking: return "جارٍ التحقق…"
        case .downloading(let p): return "جارٍ تنزيل التحديث… \(p)%"
        default: return nil
        }
    }
}
