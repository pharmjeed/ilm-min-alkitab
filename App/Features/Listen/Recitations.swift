import Foundation

/// The ayat in Mishary Alafasy's voice (owner 2026-11-27), one file per ayah, kept on the phone once fetched — so what
/// was heard plays again without the internet, and «نزّل التلاوات» keeps them all ahead of time. The files are the
/// app's own copy, compressed strongly (owner chose it by ear: «الاقوى مقبول جدا» — HE-AAC 16 kbps mono, about a quarter of everyayah's 64 kbps; the 4164 ayat of the names ≈ 195 MB) in the
/// public repository pharmjeed/ilm-recitations, served by GitHub Pages; everyayah.com's own file when it is missing.
enum Recitations {
    private static let base = URL(string: "https://pharmjeed.github.io/ilm-recitations/a16/")!
    private static let fallback = URL(string: "https://everyayah.com/data/Alafasy_64kbps/")!

    static var dir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recitations", isDirectory: true)
        if !FileManager.default.fileExists(atPath: d.path) {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            var v = URLResourceValues()
            v.isExcludedFromBackup = true
            var u = d
            try? u.setResourceValues(v)
        }
        return d
    }

    static func id(_ s: Int, _ a: Int) -> String { String(format: "%03d%03d", s, a) }
    /// The compressed copy (.m4a), or the original (.mp3) fetched when the copy was missing.
    static func local(_ s: Int, _ a: Int, _ ext: String = "m4a") -> URL { dir.appendingPathComponent("\(id(s, a)).\(ext)") }

    /// What is on the phone for the ayah.
    static func stored(_ s: Int, _ a: Int) -> URL? {
        for ext in ["m4a", "mp3"] {
            let u = local(s, a, ext)
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    static func has(_ s: Int, _ a: Int) -> Bool { stored(s, a) != nil }

    /// The file of the ayah, fetched first when it is not on the phone yet; nil without the internet.
    static func file(_ s: Int, _ a: Int) async -> URL? {
        if let u = stored(s, a) { return u }
        if let u = await fetch(base.appendingPathComponent("\(id(s, a)).m4a"), to: local(s, a, "m4a")) { return u }
        return await fetch(fallback.appendingPathComponent("\(id(s, a)).mp3"), to: local(s, a, "mp3"))
    }

    private static func fetch(_ from: URL, to: URL) async -> URL? {
        guard let (tmp, res) = try? await URLSession.shared.download(from: from),
              (res as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        try? FileManager.default.removeItem(at: to)
        do { try FileManager.default.moveItem(at: tmp, to: to) } catch { return nil }
        return to
    }

    /// How many ayat are on the phone, and their size in megabytes.
    static func stored() -> (count: Int, megabytes: Int) {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let bytes = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        return (files.count, bytes / 1_000_000)
    }

    static func removeAll() {
        try? FileManager.default.removeItem(at: dir)
    }
}

/// «نزّل التلاوات»: every ayah the player recites — the names' positions (with the ayah before and after) and the
/// sunan's ayat — fetched four at a time, the ones already on the phone skipped.
@MainActor
final class RecitationDownload: ObservableObject {
    static let shared = RecitationDownload()
    @Published private(set) var running = false
    @Published private(set) var done = 0
    @Published private(set) var total = 0
    @Published private(set) var failed = 0
    private var task: Task<Void, Never>?

    func start() {
        guard !running else { return }
        running = true
        done = 0
        failed = 0
        total = 0
        task = Task {
            let all = await Self.allAyat()
            let missing = all.filter { !Recitations.has($0.0, $0.1) }
            total = missing.count
            var i = 0
            while i < missing.count, !Task.isCancelled {
                let batch = missing[i..<min(i + 4, missing.count)]
                await withTaskGroup(of: Bool.self) { g in
                    for (s, a) in batch { g.addTask { await Recitations.file(s, a) != nil } }
                    for await ok in g {
                        if ok { done += 1 } else { failed += 1 }
                    }
                }
                i += 4
            }
            running = false
        }
    }

    func cancel() {
        task?.cancel()
        running = false
    }

    /// Every (surah, ayah) of the player's tracks, in the order they are heard.
    private static func allAyat() async -> [(Int, Int)] {
        var seen = Set<Int>()
        var out: [(Int, Int)] = []
        func add(_ s: Int, _ a: Int) {
            if seen.insert(s * 1000 + a).inserted { out.append((s, a)) }
        }
        for card in NamesRepo.shared.names {
            guard let d = try? await NameDetails.shared.detail(card.id) else { continue }
            for v in d.verses {
                if let p = v.prev { add(v.s, p.a) }
                for a in v.a...max(v.a, v.last ?? v.a) { add(v.s, a) }
                if let n = v.next { add(v.s, n.a) }
            }
        }
        for st in ListenPlan.sunanStates {
            guard let items = try? await SunanStore.shared.stateItems(st.id) else { continue }
            for it in items {
                if let q = it.quran { for a in q.from...max(q.from, q.to) { add(q.s, a) } }
            }
        }
        return out
    }
}
