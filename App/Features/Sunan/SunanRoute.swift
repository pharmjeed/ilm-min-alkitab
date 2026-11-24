import SwiftUI

/// Pages of the sunan section — one per website route under `/sunan` (see ARCHITECTURE.md).
/// The section home `/sunan` itself is `HomeDestination.sunan`.
enum SunanRoute: Hashable {
    /// /sunan/<domain>
    case domain(Int)
    /// /sunan/<domain>/<need>
    case need(Int)
    /// /sunan/<domain>/<need>/<state>
    case state(Int)
    /// /sunan/item/<fp> — `stateId` is a lookup hint (every list knows it); nil ⇒ found through the fp map.
    case item(fp: String, stateId: Int? = nil)
    /// /sunan/search?q=…
    case search(query: String = "")
    /// /sunan/macro
    case macro
    /// /sunan/pairs
    case pairs
    /// /sunan/method
    case method
    /// /sunan/day — the three main categories only (owner 2026-11-24: category → sub-category → sunan)
    case day
    /// One main category («أولاً: اليوم والليلة») and its sub-categories (by period id) — app only
    case dayPeriod(Int)
    /// /sunan/day/<slug> (by time id)
    case dayTime(Int)
    /// /sunan/deeds
    case deeds
    /// /sunan/deeds/<slug> (by deed id)
    case deed(Int)
}

struct SunanRouteView: View {
    let route: SunanRoute
    var body: some View {
        switch route {
        case .domain(let id): SunanDomainView(domainId: id)
        case .need(let id): SunanNeedView(needId: id)
        case .state(let id): SunanStateView(stateId: id)
        case .item(let fp, let stateId): SunanItemPageView(fp: fp, stateId: stateId)
        case .search(let q): SunanSearchView(initialQuery: q)
        case .macro: SunanMacroView()
        case .pairs: SunanPairsView()
        case .method: SunanMethodView()
        case .day: SunanDayView()
        case .dayPeriod(let id): SunanDayPeriodView(periodId: id)
        case .dayTime(let id): SunanDayTimeView(timeId: id)
        case .deeds: SunanDeedsView()
        case .deed(let id): SunanDeedView(deedId: id)
        }
    }
}

/// `NavigationLink(value:)` to a sunan page.
struct SunanLink<Label: View>: View {
    let route: SunanRoute
    let label: Label
    init(_ route: SunanRoute, @ViewBuilder label: () -> Label) {
        self.route = route
        self.label = label()
    }
    var body: some View {
        NavigationLink(value: HomeDestination.s(route)) { label }
            .buttonStyle(.plain)
    }
}

/// Crumb of the section home («السنن والأسباب» → /sunan).
extension Crumb {
    static var sunanHome: Crumb { Crumb(SunanText.title, dest: .sunan) }
}
