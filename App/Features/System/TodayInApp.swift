import Foundation

extension Today.Content {
    /// «اليوم» from the content the app shows now (the active download, else the bundled snapshot).
    static var app: Today.Content {
        load(names: PackStore.shared.url(.names, "index.json"), day: PackStore.shared.url(.sunan, "day.json"))
    }
}

/// «مركز التحكم» (owner 2026-11-27): the controls' intents run in the app and open the day's name or sunnah — through
/// the same road as a tapped notification, so a cold start waits for the tab shell.
enum TodayControls {
    static func prepare() {
        TodayControlHook.open = { what in
            await MainActor.run {
                let c = Today.Content.app, now = Date()
                let router = NotificationRouter.shared
                if what == "sunnah", let s = c.sunnah(now) {
                    router.pending = .init(target: .sunnah(fp: s.fp, stateId: s.stateId))
                } else if let n = c.name(now) {
                    router.pending = .init(target: .name(n.id))
                }
            }
        }
    }
}

/// Links into the app from its widgets: `ilm://name/<id>` (the name page), `ilm://sunnah/<state>/<fp>` (the sunnah page),
/// `ilm://situation/<id>` and `ilm://state/<id>` (items of a collection of «محفوظاتي»).
enum DeepLink {
    static func open(_ url: URL, _ nav: AppNav) {
        guard url.scheme == "ilm" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host {
        case "name":
            if let id = parts.first.flatMap({ Int($0) }) { nav.openName(id) }
        case "sunnah":
            if parts.count >= 2, let state = Int(parts[0]) { nav.openSunnah(fp: parts[1], stateId: state) }
        case "situation":   // an item of a collection shown by the widget
            if let id = parts.first.flatMap({ Int($0) }) { nav.openPath([.names, .n(.situation(id))]) }
        case "state":
            if let id = parts.first.flatMap({ Int($0) }) { nav.openPath([.sunan, .s(.state(id))]) }
        default:
            break
        }
    }
}
