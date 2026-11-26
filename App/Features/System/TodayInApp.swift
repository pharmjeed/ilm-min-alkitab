import Foundation

extension Today.Content {
    /// «اليوم» from the content the app shows now (the active download, else the bundled snapshot).
    static var app: Today.Content {
        load(names: PackStore.shared.url(.names, "index.json"), day: PackStore.shared.url(.sunan, "day.json"))
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
