import CoreSpotlight
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// The iPhone's search (owner 2026-11-26 «بحث الجوال: ممتاز اعملها»): every name, every situation of «ماذا تشعر الآن؟»
/// and every state of the sunan appear when one types a word of them («كرب»، «رزق»…) and open their page. Re-indexed
/// whenever the content version changes.
enum SpotlightIndex {
    private static let stampKey = "spotlight.stamp"
    private static let schema = "1"

    /// Returns how many items were indexed (0 when the index was already current or indexing failed).
    @discardableResult
    static func refresh(force: Bool = false) async -> Int {
        let stamp = [schema, PackStore.currentVersion(.names) ?? "", PackStore.currentVersion(.sunan) ?? ""].joined(separator: "|")
        guard force || UserDefaults.standard.string(forKey: stampKey) != stamp else { return 0 }
        let items = await Task.detached(priority: .utility) { SpotlightIndex.build() }.value
        guard !items.isEmpty else { return 0 }
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteAllSearchableItems()
            try await index.indexSearchableItems(items)
            UserDefaults.standard.set(stamp, forKey: stampKey)
            return items.count
        } catch {
            return 0
        }
    }

    /// CI only: the titles of this app's indexed items that a word finds (title or keywords), as the iPhone's search
    /// would match them — to see the index holds what it should.
    static func probe(_ word: String) async -> [String] {
        await withCheckedContinuation { (cont: CheckedContinuation<[String], Never>) in
            let ctx = CSSearchQueryContext()
            ctx.fetchAttributes = ["title"]
            let q = CSSearchQuery(queryString: "title == \"*\(word)*\"cd || keywords == \"\(word)*\"cd", queryContext: ctx)
            let lock = NSLock()
            var found: [String] = []
            q.foundItemsHandler = { items in
                lock.lock()
                found += items.compactMap { $0.attributeSet.title }
                lock.unlock()
            }
            q.completionHandler = { _ in
                lock.lock()
                let out = found
                lock.unlock()
                cont.resume(returning: out)
            }
            q.start()
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
        return CSSearchableItem(uniqueIdentifier: id, domainIdentifier: domain, attributeSet: a)
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
            let n = await SpotlightIndex.refresh(force: true)
            var out = ["فُهرس الآن: \(n) عنصرًا"]
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            for w in ["رزق", "كرب", "الرحمن", "غفور", "النوم"] {
                let hits = await SpotlightIndex.probe(w)
                out.append("«\(w)»: \(hits.count) — " + hits.prefix(4).joined(separator: "، "))
            }
            lines = out
        }
    }
}
