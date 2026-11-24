import SwiftUI

/// /sunan/<domain> — app/sunan/[domain]/page.tsx: «ما تعمله» then «ما تتجنّبه».
struct SunanDomainView: View {
    @Environment(\.colorScheme) private var scheme
    let domainId: Int
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let domain = repo.domain(domainId)
        ScrollView {
            if let domain {
                let needs = repo.needs(of: domain)
                let doNeeds = needs.filter { !$0.avoid }
                let avoidNeeds = needs.filter(\.avoid)
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SunanText.title).font(AppFont.sans(14)).foregroundStyle(t.gold)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(domain.title).font(AppFont.serif(30)).foregroundStyle(t.cream)
                        if let d = domain.description, !d.isEmpty {
                            Text(d).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8).padding(.top, 4)
                        }
                        Text("اختر الحاجة الأقرب إلى ما تريد، أو ما تخشى أن يكون سببًا لما أصابك.")
                            .font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(8).padding(.top, 4)
                    }
                    .multilineTextAlignment(.leading)
                    .sunanHeader(t)

                    if !doNeeds.isEmpty {
                        SunanHeading(text: "ما تعمله", size: 21).padding(.top, 24)
                        LazyVStack(spacing: 8) {
                            ForEach(doNeeds) { n in SunanLink(.need(n.id)) { NeedRowView(need: n, avoid: false) } }
                        }
                        .padding(.top, 12)
                    }

                    if !avoidNeeds.isEmpty {
                        SunanHeading(text: "ما تتجنّبه", size: 21).padding(.top, 32)
                        Text("أسبابٌ تجلب ضدّ ما تريد — لتعرف لماذا يحصل لك ما يحصل، وتجد علاجه.")
                            .font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(5)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 4)
                        LazyVStack(spacing: 8) {
                            ForEach(avoidNeeds) { n in SunanLink(.need(n.id)) { NeedRowView(need: n, avoid: true) } }
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(16).padding(.bottom, 24)
            }
        }
        .sunanScreen(domain?.title ?? "", t)
    }
}

private struct NeedRowView: View {
    @Environment(\.colorScheme) private var scheme
    let need: SunanNeed
    let avoid: Bool
    var body: some View {
        let t = Theme(scheme)
        HStack(alignment: .center, spacing: 12) {
            Text(need.title).font(AppFont.sans(16)).foregroundStyle(t.cream)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Text("\(SunanText.count(need.stateIds.count, SunanText.states)) · \(SunanText.count(need.counts.items, SunanText.sunan)) ←")
                .font(AppFont.sans(12)).foregroundStyle(t.gold).fixedSize()
        }
        .sunanRow(t, avoid: avoid)
    }
}

/// /sunan/<domain>/<need> — app/sunan/[domain]/[need]/page.tsx: the states of a need.
struct SunanNeedView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let needId: Int
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let need = repo.need(needId)
        let domain = need.flatMap { repo.domain($0.domainId) }
        ScrollView {
            if let need, let domain {
                let states = repo.states(of: need)
                let counterpart = need.avoid ? need.counterpartNeedId.flatMap { repo.need($0) } : nil
                VStack(alignment: .leading, spacing: 0) {
                    CrumbsView(trail: [.sunanHome, Crumb(domain.title, .domain(domain.id))], current: need.title)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(domain.title) · \(need.avoid ? "ما تتجنّبه" : "ما تعمله")").font(AppFont.sans(14)).foregroundStyle(t.gold)
                        Text(need.title).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                        Text("\(SunanText.count(need.counts.items, SunanText.sunan)) في \(SunanText.count(states.count, SunanText.states)) — أيُّ حالٍ أقرب إلى ما تعيشه؟")
                            .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(6)
                            .padding(.top, 8)
                        if let counterpart {
                            Button { nav.open(.need(counterpart.id)) } label: {
                                Text("علاجه في: «\(counterpart.title)» ←").font(AppFont.sans(14)).foregroundStyle(t.gold)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .sunanHeader(t, gold: !need.avoid, avoid: need.avoid)

                    LazyVStack(spacing: 8) {
                        ForEach(states) { s in SunanLink(.state(s.id)) { StateRowView(state: s) } }
                    }
                    .padding(.top, 16)
                }
                .padding(16).padding(.bottom, 24)
            }
        }
        .sunanScreen(need?.title ?? "", t)
    }
}

private struct StateRowView: View {
    @Environment(\.colorScheme) private var scheme
    let state: SunanState
    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(state.title).font(AppFont.sans(16)).foregroundStyle(t.cream)
                Spacer(minLength: 4)
                Text("\(SunanText.count(state.counts.items, SunanText.sunan)) ←").font(AppFont.sans(12)).foregroundStyle(t.gold).fixedSize()
            }
            if let summary = state.summary, !summary.isEmpty {
                Text(summary).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6).lineLimit(2)
            }
        }
        .multilineTextAlignment(.leading)
        .sunanRow(t)
    }
}

/// /sunan/<domain>/<need>/<state> — app/sunan/[domain]/[need]/[state]/page.tsx: the representatives, «ابدأ بهذه» first.
struct SunanStateView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let stateId: Int
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let state = repo.state(stateId)
        let need = state.flatMap { repo.need($0.needId) }
        let domain = need.flatMap { repo.domain($0.domainId) }
        ScrollView {
            if let state, let need, let domain {
                let remedyNeed = state.remedy.flatMap { repo.need($0.needId) }
                let remedyState = state.remedy?.stateId.flatMap { repo.state($0) }
                VStack(alignment: .leading, spacing: 0) {
                    CrumbsView(trail: [.sunanHome, Crumb(domain.title, .domain(domain.id)), Crumb(need.title, .need(need.id))],
                               current: state.title)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(need.title).font(AppFont.sans(14)).foregroundStyle(t.gold)
                        Text(state.title).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                        Text("\(SunanText.count(state.counts.items, SunanText.sunan))، المختار منها أولًا:")
                            .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9))
                            .padding(.top, 8)
                        if let remedyNeed {
                            Button {
                                if let remedyState { nav.open(.state(remedyState.id)) } else { nav.open(.need(remedyNeed.id)) }
                            } label: {
                                Text("علاجه في: «\(remedyNeed.title)»\(remedyState.map { " ← «\($0.title)»" } ?? "") ←")
                                    .font(AppFont.sans(14)).foregroundStyle(t.gold)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                        RunsLegend().padding(.top, 8)
                    }
                    .multilineTextAlignment(.leading)
                    .sunanHeader(t, gold: !need.avoid, avoid: need.avoid)

                    FavoritePill(key: .state(state.id), item: state.title)
                        .padding(.top, 12)

                    SunanLoader(key: "state-\(state.id)", load: { try await SunanStore.shared.stateItems(state.id) }) { items in
                        LazyVStack(spacing: 12) {
                            ForEach(Array(SunanText.starFirst(items).enumerated()), id: \.element.id) { i, it in
                                SunanLink(.item(fp: it.fp, stateId: it.stateId)) { SunanItemCardView(item: it, n: i + 1) }
                            }
                        }
                    }
                    .frame(minHeight: 120)
                    .padding(.top, 16)

                    SunanBackLink(text: "→ بقية الأحوال في «\(need.title)»") { nav.open(.need(need.id)) }
                        .padding(.top, 32)
                }
                .padding(16).padding(.bottom, 24)
            }
        }
        .sunanScreen(state?.title ?? "", t)
    }
}
