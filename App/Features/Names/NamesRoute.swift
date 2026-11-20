import SwiftUI

/// Pages of the names section — one per website route (see ARCHITECTURE.md «Names section = the website»).
enum NamesRoute: Hashable {
    /// /feel
    case feel
    /// /feel/<door>
    case door(Int)
    /// /feel/<door>/<situation>
    case situation(Int)
    /// /feel/<door>/<situation>/<id>
    case nameInSituation(name: Int, situation: Int)
    /// /names/<id>?tab=…#p<focus>
    case name(Int, tab: NameTab? = nil, focus: Int? = nil)
    /// /names
    case allNames(query: String = "")
    /// /feel/anfus#<type>
    case anfus(focus: String? = nil)
    /// /ask?q=…
    case ask(question: String = "")
}

/// Tabs of the name page, in the website's order (components/names/NamePageContent.tsx).
enum NameTab: String, Hashable, CaseIterable {
    case verses, sunnah, teaches, recall, pray, summary
}

struct NamesRouteView: View {
    let route: NamesRoute
    var body: some View {
        switch route {
        case .feel: FeelView()
        case .door(let id): DoorView(doorId: id)
        case .situation(let id): SituationView(situationId: id)
        case .nameInSituation(let name, let situation): NameInSituationView(nameId: name, situationId: situation)
        case .name(let id, let tab, let focus): NamePageView(nameId: id, tab: tab, focus: focus)
        case .allNames(let query): AllNamesView(initialQuery: query)
        case .anfus(let focus): AnfusView(focus: focus)
        case .ask(let question): AskView(initialQuestion: question)
        }
    }
}

/// `NavigationLink(value:)` to a names page.
struct NamesLink<Label: View>: View {
    let route: NamesRoute
    let label: Label
    init(_ route: NamesRoute, @ViewBuilder label: () -> Label) {
        self.route = route
        self.label = label()
    }
    var body: some View {
        NavigationLink(value: HomeDestination.n(route)) { label }
            .buttonStyle(.plain)
    }
}
