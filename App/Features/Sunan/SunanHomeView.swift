import SwiftUI

/// /sunan — app/sunan/page.tsx: header with the search →
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
                        header(t, ix.stats) {
                            withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo("domains", anchor: .top) }
                        }

                        DomainsEntry(domains: ix.domains).padding(.top, 32).id("domains")

                        // owner 2026-11-25: «برنامج اليوم والليلة» and «ماذا يجلب هذا العمل؟» under «ماذا تحتاج الآن؟»
                        if !ways.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(ways) { w in
                                    SunanLink(w.route) { WayCard(title: w.title, lead: w.lead, count: w.count) }
                                }
                            }
                            .padding(.top, 32)
                        }

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

    private func header(_ t: Theme, _ st: SunanStats, browse: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            // owner 2026-11-24: the title «لكل نتيجةٍ سبب» removed; 2026-11-25: the kicker removed too, and the lead
            // moved under the verses
            // owner 2026-11-24: the counts line gave way to the verses (whole, as in quran.json — الكهف 84-85,
            // joined with « * » like consecutive verses in content.json)
            Text(SunanText.sababVerse).font(AppFont.amiri(22)).foregroundStyle(t.gold).lineSpacing(8)
            Text(SunanText.sababRef).font(AppFont.sans(12)).foregroundStyle(t.muted)
                .padding(.top, 4)
            Text(SunanText.lead).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(9)
                .padding(.top, 16)
            SunanSearchField(text: $query, button: false) { ask() }
                .padding(.top, 24)
            // owner 2026-11-25: two gold buttons side by side, as in the names section — «تصفّح السنن» goes down to
            // «ماذا تحتاج الآن؟», «اسأل عن موقفك» opens the AI page (with what was typed, if anything) — owner
            // 2026-11-25: «اجعله بالذكاء الاصطناعي مثل قسم الأسماء ويرشد إلى الحالة الأقرب»
            HStack(spacing: 12) {
                Button(action: browse) { Text("تصفّح السنن") }.buttonStyle(PrimaryPill())
                Button(action: ask) { Text("اسأل عن موقفك") }.buttonStyle(PrimaryPill())
            }
            .padding(.top, 16)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .sunanHeader(t, padding: 20)
    }

    private func ask() {
        nav.open(.ask(question: query.trimmingCharacters(in: .whitespacesAndNewlines)))
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

/// «ماذا تحتاج الآن؟» the way «ماذا تشعر الآن؟» is shown in the names section (owner 2026-11-25): the question in a
/// card, then the domains as a rail to swipe sideways, with dots under it.
private struct DomainsEntry: View {
    @Environment(\.colorScheme) private var scheme
    let domains: [SunanDomain]
    @State private var active: Int?

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            Text("ماذا تحتاج الآن؟")
                .font(AppFont.serif(32)).foregroundStyle(t.cream)
                .multilineTextAlignment(.center)
            Text("اختر حاجتك، ونصل بك إلى أسبابها من الكتاب والسنة")
                .font(AppFont.sans(14)).foregroundStyle(t.muted)
                .multilineTextAlignment(.center).padding(.top, 8)
            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(domains) { d in
                            SunanLink(.domain(d.id)) { DomainCard(domain: d) }
                                .containerRelativeFrame(.horizontal) { w, _ in min(320, w * 0.78) }
                                .frame(maxHeight: .infinity)
                                .id(d.id)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollTargetLayout()
                    .padding(.vertical, 4)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $active)
                .padding(.horizontal, -20)
                .contentMargins(.horizontal, 20, for: .scrollContent)

                HStack(spacing: 6) {
                    ForEach(domains) { d in
                        let on = (active ?? domains.first?.id) == d.id
                        Capsule()
                            .fill(on ? t.gold : t.line)
                            .frame(width: on ? 20 : 6, height: 6)
                            .onTapGesture { withAnimation { active = d.id } }
                    }
                }
                .animation(.easeOut(duration: 0.2), value: active)
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 20).padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.line, lineWidth: 1))
    }
}

/// One domain of «ماذا تحتاج الآن؟» — its number, title, «وصف المجال», and its needs' count (like a door of
/// «ماذا تشعر الآن؟», with the gold edge at its end).
private struct DomainCard: View {
    @Environment(\.colorScheme) private var scheme
    let domain: SunanDomain
    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 12) {
            Text("\(domain.id)").font(AppFont.sans(16)).foregroundStyle(t.gold)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(t.line, lineWidth: 1))
            Text(domain.title).font(AppFont.serif(26)).foregroundStyle(t.cream)
            if let d = domain.description, !d.isEmpty {
                Text(d).font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(5)
            }
            // owner 2026-11-25: the needs as chips, like the covers of «ماذا تشعر الآن؟» («اسم مختصر» of each need)
            let chips = SunanRepo.shared.needs(of: domain).compactMap(\.short)
            if !chips.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(chips, id: \.self) { c in
                        Text(c)
                            .font(AppFont.sans(13)).foregroundStyle(t.gold.opacity(0.9))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(t.gold.opacity(0.05), in: Capsule())
                            .overlay(Capsule().stroke(t.gold.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Rectangle().fill(t.line).frame(height: 1)
                // owner 2026-11-25: the needs' count removed
                HStack {
                    Spacer(minLength: 8)
                    Text("افتح ←")
                }
                .font(AppFont.sans(14)).foregroundStyle(t.gold)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .trailing) {
            LinearGradient(colors: [t.gold, t.gold.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.gold.opacity(0.35), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
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
