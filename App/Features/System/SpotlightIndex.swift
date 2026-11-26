import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// The iPhone's search (owner 2026-11-26 «بحث الجوال: ممتاز اعملها»): every name, every situation of «ماذا تشعر الآن؟»
/// and every state of the sunan appear when one types a word of them («كرب»، «رزق»…) and open their page. Re-indexed
/// whenever the content version changes.
enum SpotlightIndex {
    private static let stampKey = "spotlight.stamp"
    private static let schema = "1"

    static func refresh() async {
        let stamp = [schema, PackStore.currentVersion(.names) ?? "", PackStore.currentVersion(.sunan) ?? ""].joined(separator: "|")
        guard UserDefaults.standard.string(forKey: stampKey) != stamp else { return }
        let items = await Task.detached(priority: .utility) { SpotlightIndex.build() }.value
        guard !items.isEmpty else { return }
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteAllSearchableItems()
            try await index.indexSearchableItems(items)
            UserDefaults.standard.set(stamp, forKey: stampKey)
        } catch {}
    }

    private static func item(_ id: String, _ domain: String, title: String, text: String, keywords: [String]) -> CSSearchableItem {
        let a = CSSearchableItemAttributeSet(contentType: .text)
        a.title = title
        a.contentDescription = text
        a.keywords = Array(Set(keywords + words(title) + words(text).prefix(12))).sorted()
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
