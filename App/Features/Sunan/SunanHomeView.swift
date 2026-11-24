import SwiftUI

/// /sunan — app/sunan/page.tsx: header with the search → «برنامج اليوم والليلة» · «ماذا يجلب هذا العمل؟» →
/// «ماذا تحتاج الآن؟» (every domain of the pack, in order) → «وفي الأصول».
struct SunanHomeView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    @State private var query = ""
    private let repo = SunanRepo.shared

    private struct Way: Identifiable {
        let route: SunanRoute
        let title: String
        let lead: String
        let count: String
        var id: String { title }
    }

    private struct MoreLink: Identifiable {
        let route: SunanRoute
        let title: String
        let lead: String
        var id: String { title }
    }

    private static let more: [MoreLink] = [
        MoreLink(route: .macro, title: "السنن الكبرى", lead: "القوانين الجامعة: سببٌ ونتيجته كما تقرّرت في القرآن والسنة."),
        MoreLink(route: .pairs, title: "السنن المتقابلة", lead: "كل سنّةٍ وما يقابلها في المآل: سببٌ يوصل إلى الخير، وضدّه يوصل إلى ضدّه."),
        MoreLink(route: .method, title: "المنهج والحدود", lead: "كيف جُمعت هذه السنن، وما حدود الاستنباط فيها."),
    ]

    private var ways: [Way] {
        guard let ix = repo.index else { return [] }
        let st = ix.stats
        var out: [Way] = []
        if ix.extras?.day != nil {
            out.append(Way(route: .day, title: SunanText.dayTitle, lead: SunanText.dayLead,
                           count: SunanText.count(st.dayItems ?? 0, SunanText.sunan)))
        }
        if ix.extras?.deeds != nil {
            out.append(Way(route: .deeds, title: SunanText.deedsTitle, lead: SunanText.deedsLead,
                           count: "\(SunanText.count(st.deeds ?? 0, SunanText.deeds))، \(SunanText.count(st.deedItems ?? 0, SunanText.fruits)) وعاقبة"))
        }
        return out
    }

    var body: some View {
        let t = Theme(scheme)
        ScrollViewReader { proxy in
            ScrollView {
                if let ix = repo.index {
                    VStack(alignment: .leading, spacing: 0) {
                        header(t, ix.stats)

                        if !ways.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(ways) { w in
                                    SunanLink(w.route) { WayCard(title: w.title, lead: w.lead, count: w.count) }
                                }
                            }
                            .padding(.top, 32)
                        }

                        SunanHeading(text: "ماذا تحتاج الآن؟", size: 24).padding(.top, 32).id("domains")
                        LazyVStack(spacing: 12) {
                            ForEach(ix.domains) { d in
                                SunanLink(.domain(d.id)) { DomainCard(domain: d) }
                            }
                        }
                        .padding(.top, 16)

                        SunanHeading(text: "وفي الأصول", size: 24).padding(.top, 40)
                        VStack(spacing: 12) {
                            ForEach(Self.more) { m in
                                SunanLink(m.route) { MoreCard(title: m.title, lead: m.lead) }
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(16).padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .task {
                guard let anchor = Route.consumeSunanScroll(["domains"]) else { return }
                try? await Task.sleep(nanoseconds: 700_000_000)
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        .sunanScreen(SunanText.kicker, t)
    }

    private func header(_ t: Theme, _ st: SunanStats) -> some View {
        VStack(spacing: 0) {
            Text(SunanText.kicker).font(AppFont.sans(14)).foregroundStyle(t.gold)
            Text("لكل نتيجةٍ سبب").font(AppFont.serif(32)).foregroundStyle(t.cream).padding(.top, 4)
            Text(SunanText.lead).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(9)
                .padding(.top, 12)
            // owner 2026-11-24: the counts line gave way to the verse (whole, as in quran.json — الكهف 84)
            Text(SunanText.sababVerse).font(AppFont.amiri(22)).foregroundStyle(t.gold).lineSpacing(8)
                .padding(.top, 16)
            Text(SunanText.sababRef).font(AppFont.sans(12)).foregroundStyle(t.muted)
                .padding(.top, 4)
            SunanSearchField(text: $query) { nav.open(.search(query: query.trimmingCharacters(in: .whitespacesAndNewlines))) }
                .padding(.top, 24)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .sunanHeader(t, padding: 20)
    }
}

/// «برنامج اليوم والليلة» / «ماذا يجلب هذا العمل؟» cards (`border-gold/60 bg-gold/5`).
private struct WayCard: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let lead: String
    let count: String
    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AppFont.serif(26)).foregroundStyle(t.gold)
            Text(lead).font(AppFont.sans(14)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(7)
            Rectangle().fill(t.line).frame(height: 1).padding(.top, 4)
            HStack {
                Text(count)
                Spacer(minLength: 8)
                Text("افتح ←")
            }
            .font(AppFont.sans(14)).foregroundStyle(t.gold)
        }
        .multilineTextAlignment(.leading)
        .sunanRow(t, border: t.gold.opacity(0.6), fill: t.gold.opacity(0.05), h: 20, v: 20, radius: 16)
    }
}

/// One domain of «ماذا تحتاج الآن؟» — its number, title, «وصف المجال», and its needs' count.
private struct DomainCard: View {
    @Environment(\.colorScheme) private var scheme
    let domain: SunanDomain
    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 12) {
            Text("\(domain.id)").font(AppFont.sans(16)).foregroundStyle(t.gold)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(t.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 6) {
                Text(domain.title).font(AppFont.serif(24)).foregroundStyle(t.cream)
                if let d = domain.description, !d.isEmpty {
                    Text(d).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Rectangle().fill(t.line).frame(height: 1)
            HStack {
                Text(SunanText.count(domain.needIds.count, SunanText.needs))
                Spacer(minLength: 8)
                Text("افتح ←")
            }
            .font(AppFont.sans(14)).foregroundStyle(t.gold)
        }
        .multilineTextAlignment(.leading)
        .sunanRow(t, border: t.gold.opacity(0.35), h: 20, v: 20, radius: 16)
    }
}

/// «وفي الأصول» cards.
private struct MoreCard: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let lead: String
    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(AppFont.serif(20)).foregroundStyle(t.gold)
                Spacer(minLength: 8)
                Text("←").font(AppFont.sans(12)).foregroundStyle(t.gold)
            }
            Text(lead).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(7)
        }
        .multilineTextAlignment(.leading)
        .sunanRow(t, h: 20, v: 16)
    }
}
