import CoreSpotlight
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// The iPhone's search (owner 2026-11-26 «بحث الجوال: ممتاز اعملها»): every name, every situation of «ماذا تشعر الآن؟»
/// and every state of the sunan appear when one types a word of them («كرب»، «رزق»…) and open their page. Re-indexed
/// whenever the content version changes.
enum SpotlightIndex {
    private static let stampKey = "spotlight.stamp"
    private static let schema = "2"   // 2: written again without «delete all» (builds 23–24 never finished it)

    private static let idsKey = "spotlight.ids"

    /// Returns how many items were indexed (0 when the index was already current or indexing failed).
    /// Items are written over by id (no «delete all» first: on the CI simulator that call never answered, and the
    /// iPhone showed nothing); ids that are gone are removed one by one. An item no longer expires after 30 days.
    @discardableResult
    static func refresh(force: Bool = false, log: (@MainActor (String) -> Void)? = nil) async -> Int {
        let stamp = [schema, PackStore.currentVersion(.names) ?? "", PackStore.currentVersion(.sunan) ?? ""].joined(separator: "|")
        guard force || UserDefaults.standard.string(forKey: stampKey) != stamp else { return 0 }
        await log?("يبني العناصر…")
        let items = await Task.detached(priority: .utility) { SpotlightIndex.build() }.value
        await log?("بُني \(items.count) عنصرًا")
        guard !items.isEmpty else { return 0 }
        let index = CSSearchableIndex.default()
        let ids = items.map(\.uniqueIdentifier)
        let gone = Set(UserDefaults.standard.stringArray(forKey: idsKey) ?? []).subtracting(ids)
        let ok = await within(30) { done in
            index.indexSearchableItems(items) { error in done(error == nil) }
        }
        await log?(ok == true ? "سُجّل في البحث" : ok == false ? "رفض البحث التسجيل" : "لم يُجب البحث خلال ٣٠ ثانية")
        guard ok == true else { return 0 }
        if !gone.isEmpty {
            index.deleteSearchableItems(withIdentifiers: Array(gone)) { _ in }
        }
        UserDefaults.standard.set(ids, forKey: idsKey)
        UserDefaults.standard.set(stamp, forKey: stampKey)
        return items.count
    }

    /// Runs a call that answers through a completion handler; nil when it does not answer within `seconds`.
    private static func within(_ seconds: Double, _ call: @escaping (@escaping (Bool) -> Void) -> Void) async -> Bool? {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool?, Never>) in
            let lock = NSLock()
            var resumed = false
            func finish(_ v: Bool?) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: v)
            }
            call { finish($0) }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { finish(nil) }
        }
    }

    /// CI only: the titles of this app's indexed items that a word finds (title or keywords), as the iPhone's search
    /// would match them — to see the index holds what it should.
    static func probe(_ word: String) async -> [String]? {
        await withCheckedContinuation { (cont: CheckedContinuation<[String]?, Never>) in
            let ctx = CSSearchQueryContext()
            ctx.fetchAttributes = ["title"]
            let q = CSSearchQuery(queryString: "title == \"*\(word)*\"cd || keywords == \"\(word)*\"cd", queryContext: ctx)
            let lock = NSLock()
            var found: [String] = []
            var resumed = false
            func finish(_ v: [String]?) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: v)
            }
            q.foundItemsHandler = { items in
                lock.lock()
                found += items.compactMap { $0.attributeSet.title }
                lock.unlock()
            }
            q.completionHandler = { _ in
                lock.lock()
                let out = found
                lock.unlock()
                finish(out)
            }
            q.start()
            DispatchQueue.global().asyncAfter(deadline: .now() + 8) { finish(nil) }
        }
    }

    private static func item(_ id: String, _ domain: String, title: String, text: String, keywords: [String]) -> CSSearchableItem {
        let a = CSSearchableItemAttributeSet(contentType: .text)
        a.title = title
        a.displayName = title
        a.contentDescription = text
        var all: [String] = keywords
        all.append(contentsOf: words(title))
        all.append(contentsOf: Array(words(text).prefix(12)))
        a.keywords = Array(Set(all)).sorted()
        let item = CSSearchableItem(uniqueIdentifier: id, domainIdentifier: domain, attributeSet: a)
        item.expirationDate = .distantFuture   // the default is 30 days; the index is written again only on a new version
        return item
    }

    private static func build() -> [CSSearchableItem] {
        var out: [CSSearchableItem] = []
        let names = NamesRepo.shared
        for n in names.names {
            out.append(item("name:\(n.id)", "names", title: n.name, text: NotificationText.body(n.excerpt, max: 160),
                            keywords: ["أسماء الله الحسنى", "اسم الله", "الأسماء الحسنى"]))
        }
        for d in names.doors {
            for s in names.situations(of: d) {
                out.append(item("situation:\(s.id)", "situations", title: s.label,
                                text: "\(s.situation) — الأسماء الحسنى التي تدعو بها", keywords: [d.label, "دعاء", "ماذا تشعر"]))
            }
        }
        if let ix = SunanRepo.shared.index {
            for st in ix.states {
                out.append(item("sunanState:\(st.id)", "sunan", title: st.title, text: st.summary ?? "السنن والأسباب",
                                keywords: st.keywords + ["سنن", "سنة"]))
            }
        }
        return out
    }

    /// Searchable words without marks and the attached «ال / و / ف / ب / ل», so «كرب» finds «الكرب».
    static func words(_ text: String) -> [String] {
        let marks = CharacterSet(charactersIn: "\u{064B}\u{064C}\u{064D}\u{064E}\u{064F}\u{0650}\u{0651}\u{0652}\u{0670}\u{0640}")
        let plain = String(String.UnicodeScalarView(text.unicodeScalars.filter { !marks.contains($0) }))
        var out: [String] = []
        for raw in plain.components(separatedBy: CharacterSet.letters.inverted) where raw.count >= 3 {
            var w = raw
            for p in ["وال", "فال", "بال", "لل", "ال"] where w.hasPrefix(p) && w.count - p.count >= 3 {
                w = String(w.dropFirst(p.count))
                break
            }
            out.append(w)
            if w != raw { out.append(raw) }
        }
        return out
    }

    static func open(_ id: String, _ nav: AppNav) {
        let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let n = Int(parts[1]) else { return }
        switch parts[0] {
        case "name": nav.openName(n)
        case "situation": nav.openPath([.names, .n(.situation(n))])
        case "sunanState": nav.openPath([.sunan, .s(.state(n))])
        default: break
        }
    }
}

/// CI only (`-route spotlight`): indexes now and shows what a few words find in the index.
struct SpotlightProbeView: View {
    @State private var lines: [String] = ["…"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines, id: \.self) { Text($0).font(AppFont.sans(15)).foregroundStyle(.white) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            lines = []
            let n = await SpotlightIndex.refresh(force: true) { lines.append($0) }
            lines.append("فُهرس الآن: \(n) عنصرًا")
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            for w in ["رزق", "كرب", "الرحمن", "غفور", "النوم"] {
                guard let hits = await SpotlightIndex.probe(w) else { lines.append("«\(w)»: لم يُجب البحث"); continue }
                lines.append("«\(w)»: \(hits.count) — " + hits.prefix(4).joined(separator: "، "))
            }
        }
    }
}
