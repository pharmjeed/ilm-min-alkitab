import Foundation
import WidgetKit

/// Hands the home widget what «المزيد» › «أداة الشاشة الرئيسية» chose (owner 2026-11-26): «تلقائي», or a collection of
/// «محفوظاتي» described item by item (the widget has no sunan or situations data of its own).
@MainActor
enum WidgetShare {
    /// The chosen collection's id; "" = «تلقائي».
    static let key = "widget.collection"

    static func sync() async {
        let id = UserDefaults.standard.string(forKey: key) ?? ""
        let store = SavedStore.shared
        if id.isEmpty || !Account.shared.isSignedIn { return write(nil) }
        // not loaded yet (or offline): keep what the widget already has
        guard store.phase == .ready else { return }
        guard let col = store.collections.first(where: { $0.id == id }) else { return write(nil) }
        var items: [WidgetChoice.Item] = []
        for k in col.items {
            if let it = await item(k) { items.append(it) }
        }
        write(items.isEmpty ? nil : WidgetChoice(title: col.title, items: items))
    }

    private static func write(_ c: WidgetChoice?) {
        guard c != WidgetChoice.load() else { return }
        WidgetChoice.save(c)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func item(_ k: SavedKey) async -> WidgetChoice.Item? {
        let names = NamesRepo.shared
        switch k {
        case .name(let id):
            return WidgetChoice.Item(k: "name", id: id)
        case .position(let n, let s, let a):
            return WidgetChoice.Item(k: "position", id: n, s: s, a: a)
        case .sunnah(let fp):
            guard let v = try? await SunanStore.shared.item(fp: fp) else { return nil }
            // «السبب ← النتيجة»: what to do, and its result in green
            let parts = v.item.easy.components(separatedBy: "←")
            let todo = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let fruit = parts.dropFirst().joined(separator: "←").trimmingCharacters(in: .whitespacesAndNewlines)
            let meta = [v.item.grade, v.item.srcLabel ?? v.item.ref].compactMap { $0 }.filter { !$0.isEmpty }
            return WidgetChoice.Item(k: "sunnah", fp: fp, stateId: v.item.stateId, todo: todo,
                                     fruit: fruit.isEmpty ? nil : fruit, time: v.state.title,
                                     meta: meta.isEmpty ? nil : meta.joined(separator: " · "))
        case .situation(let id):
            guard let s = names.situation(id) else { return nil }
            return WidgetChoice.Item(k: "text", title: s.situation.isEmpty ? s.label : s.situation,
                                     sub: names.door(s.doorId)?.label, link: "ilm://situation/\(id)")
        case .state(let id):
            let sunan = SunanRepo.shared
            guard let st = sunan.state(id) else { return nil }
            return WidgetChoice.Item(k: "text", title: st.title, sub: st.summary ?? sunan.need(st.needId)?.title,
                                     link: "ilm://state/\(id)")
        }
    }
}
