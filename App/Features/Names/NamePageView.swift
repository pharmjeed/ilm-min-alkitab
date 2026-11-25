import SwiftUI

/// /names/<id> — app/names/[id]/page.tsx + components/names/NamePageContent.tsx.
struct NamePageView: View {
    @Environment(\.colorScheme) private var scheme
    let nameId: Int
    var tab: NameTab?
    var focus: Int?

    var body: some View {
        let t = Theme(scheme)
        NameDetailLoader(id: nameId) { d in
            NamePageContent(detail: d, initialTab: tab, focus: focus)
        }
        .namesScreen(NamesRepo.shared.card(nameId)?.name ?? "", t)
    }
}

/// Names with more positions than this are browsed per surah (e.g. «الله»).
private let bigNameThreshold = 80
/// Inside a big name, a surah with more positions than this is split into parts.
private let partSize = 60

private struct SurahGroup: Identifiable {
    let no: Int
    let name: String
    var count: Int
    let first: Int
    var id: Int { no }
}

private struct NamePageContent: View {
    @Environment(\.colorScheme) private var scheme
    let detail: NameDetail
    let focus: Int?
    private let repo = NamesRepo.shared
    private let terms: [String]
    private let needs: [Int: [VerseNeed]]
    private let groups: [SurahGroup]
    private let big: Bool

    @State private var tab: NameTab
    @State private var surah: Int
    @State private var part: Int

    init(detail: NameDetail, initialTab: NameTab?, focus: Int?) {
        self.detail = detail
        self.focus = focus
        terms = Arabic.nameTerms(detail.name)
        needs = detail.directNeedsByVerse()
        var gs: [SurahGroup] = []
        for v in detail.verses {
            if let last = gs.last, last.no == v.s { gs[gs.count - 1].count += 1 } else { gs.append(SurahGroup(no: v.s, name: v.surah, count: 1, first: v.i)) }
        }
        groups = gs
        let card = NamesRepo.shared.card(detail.id)
        big = (card?.positions ?? detail.verses.count) > bigNameThreshold
        var start = initialTab ?? .verses
        if start == .sunnah && detail.sunnah == nil { start = .verses }
        _tab = State(initialValue: start)
        // a focused verse of a big name opens its surah and part
        var s = gs.first?.no ?? 0
        var p = 1
        if let f = focus, start == .verses, let v = detail.verses.first(where: { $0.i == f }) {
            s = v.s
            let inSurah = detail.verses.filter { $0.s == v.s }
            p = (inSurah.firstIndex(where: { $0.i == f }) ?? 0) / partSize + 1
        }
        _surah = State(initialValue: s)
        _part = State(initialValue: p)
    }

    private struct TabItem: Identifiable {
        let key: NameTab
        let label: String
        var count: Int? = nil
        var id: NameTab { key }
    }

    private var tabs: [TabItem] {
        var out = [TabItem(key: .verses, label: "الآيات", count: repo.card(detail.id)?.positions ?? detail.verses.count)]
        if detail.sunnah != nil { out.append(TabItem(key: .sunnah, label: "في السنة", count: detail.hadiths.count)) }
        out.append(TabItem(key: .teaches, label: "ماذا يعلّمني"))
        out.append(TabItem(key: .recall, label: "متى أستحضره"))
        out.append(TabItem(key: .pray, label: "متى أدعو به"))
        out.append(TabItem(key: .summary, label: "الزبدة"))
        return out
    }

    var body: some View {
        let t = Theme(scheme)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    NameHero(detail: detail).padding(.horizontal, 16).padding(.top, 8)
                    SituationChips(detail: detail).padding(.horizontal, 16).padding(.top, 24).id("chips")
                    Section {
                        tabContent(t, proxy: proxy)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                    } header: {
                        tabBar(t, proxy: proxy).padding(.top, 24)
                    }
                    PrevNext(id: detail.id).padding(.horizontal, 16).padding(.top, 40).padding(.bottom, 32)
                }
            }
            .task {
                if let f = focus {
                    // the outer stack is lazy: reach the tabs first so the cards exist, then the card itself
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    proxy.scrollTo("chips", anchor: .top)
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    proxy.scrollTo(tab == .sunnah ? "w\(f)" : "p\(f)", anchor: .top)
                } else if Route.scrollToTabs {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    proxy.scrollTo("chips", anchor: .top)
                    if Route.arg == "name1" {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        proxy.scrollTo("bigTop", anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: tabs (components/names/NameTabs.tsx)

    private func tabBar(_ t: Theme, proxy: ScrollViewProxy) -> some View {
        ScrollViewReader { tabsProxy in
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabs) { item in
                    let on = item.key == tab
                    Button { tab = item.key } label: {
                        HStack(spacing: 6) {
                            Text(item.label).font(AppFont.sans(14, on ? .medium : .regular))
                            if let c = item.count { Text("\(c)").font(AppFont.sans(12)).opacity(0.8) }
                        }
                        .foregroundStyle(on ? t.bg : t.muted)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(on ? t.gold : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .id(item.key)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .onAppear { tabsProxy.scrollTo(tab, anchor: .center) }
        .onChange(of: tab) { _, k in withAnimation { tabsProxy.scrollTo(k, anchor: .center) } }
        }
        .background(t.bg)
        .overlay(alignment: .bottom) { Rectangle().fill(t.line).frame(height: 1) }
    }

    @ViewBuilder
    private func tabContent(_ t: Theme, proxy: ScrollViewProxy) -> some View {
        switch tab {
        case .verses: versesPanel(t, proxy: proxy)
        case .sunnah: SunnahPanel(detail: detail)
        case .teaches: TextBlockView(text: detail.teaches)
        case .recall: TextBlockView(text: detail.whenRecall)
        case .pray: TextBlockView(text: detail.whenPray)
        case .summary: TextBlockView(text: detail.summary)
        }
    }

    // MARK: «الآيات»

    @ViewBuilder
    private func versesPanel(_ t: Theme, proxy: ScrollViewProxy) -> some View {
        if big {
            bigVerses(t)
        } else {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 16) {
                    ForEach(detail.verses) { v in verseCard(v).id("p\(v.i)") }
                }
                SurahIndexView(items: groups.map { (no: $0.no, name: $0.name, count: $0.count) }) { no in
                    if let g = groups.first(where: { $0.no == no }) {
                        withAnimation { proxy.scrollTo("p\(g.first)", anchor: .top) }
                    }
                }
            }
        }
    }

    private func verseCard(_ v: Verse) -> some View {
        VerseCardView(verse: v, nameId: detail.id, nameLabel: detail.name, terms: terms, needs: needs[v.i] ?? [])
    }

    /// Big names: one surah at a time (and parts of 60 inside long surahs), like /names/<id>/surah/<n>.
    @ViewBuilder
    private func bigVerses(_ t: Theme) -> some View {
        let card = repo.card(detail.id)
        let inSurah = detail.verses.filter { $0.s == surah }
        let nParts = max(1, Int((Double(inSurah.count) / Double(partSize)).rounded(.up)))
        let p = min(max(1, part), nParts)
        let shown = Array(inSurah[min((p - 1) * partSize, inSurah.count)..<min(p * partSize, inSurah.count)])
        let current = groups.first { $0.no == surah }
        let idx = groups.firstIndex { $0.no == surah } ?? 0

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                (Text("لهذا الاسم ")
                    + Text(Num.fmt(card?.positions ?? detail.verses.count)).foregroundColor(t.gold)
                    + Text(" موضعًا في ")
                    + Text("\(card?.surahs ?? groups.count)").foregroundColor(t.gold)
                    + Text(" سورة؛ تُعرض مواضعه سورةً سورة. المعروض الآن: ")
                    + Text(current?.name ?? "").bold()
                    + Text(" (\(inSurah.count) موضعًا")
                    + Text(nParts > 1 ? " — الجزء \(p) من \(nParts)، المواضع \(shown.first?.i ?? 0)–\(shown.last?.i ?? 0)" : "")
                    + Text("). اختر سورة أخرى من الفهرس."))
                    .font(AppFont.sans(14)).foregroundStyle(t.cream).lineSpacing(6)
            }
            .siteCard(t, radius: 12, border: t.gold.opacity(0.4), fill: t.gold.opacity(0.1))
            .id("bigTop")

            Menu {
                ForEach(groups) { g in
                    Button("\(g.no). \(g.name) (\(g.count))") { surah = g.no; part = 1 }
                }
            } label: {
                HStack {
                    Text("السور الواردة").font(AppFont.sans(12.5)).foregroundStyle(t.gold)
                    Spacer()
                    Text("\(current?.no ?? 0). \(current?.name ?? "")").font(AppFont.sans(15)).foregroundStyle(t.cream)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(t.muted)
                }
                .siteCard(t, radius: 12, padding: 12)
            }

            VStack(spacing: 16) {
                ForEach(shown) { v in verseCard(v).id("p\(v.i)") }
            }

            if nParts > 1 {
                FlowLayout(spacing: 4, lineSpacing: 4) {
                    ForEach(1...nParts, id: \.self) { k in
                        Button { part = k } label: {
                            Text("\(k)").font(AppFont.sans(14))
                                .foregroundStyle(k == p ? t.bg : t.muted)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(k == p ? t.gold : Color.clear, in: Capsule())
                                .overlay(Capsule().stroke(k == p ? t.gold : t.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HStack {
                if idx > 0 {
                    let g = groups[idx - 1]
                    Button("→ \(g.name) (\(g.count))") { surah = g.no; part = 1 }.buttonStyle(SecondaryPill(compact: true))
                }
                Spacer()
                if idx < groups.count - 1 {
                    let g = groups[idx + 1]
                    Button("\(g.name) (\(g.count)) ←") { surah = g.no; part = 1 }.buttonStyle(SecondaryPill(compact: true))
                }
            }
        }
    }
}

/// components/names/NameHero.tsx
private struct NameHero: View {
    @Environment(\.colorScheme) private var scheme
    let detail: NameDetail

    var body: some View {
        let t = Theme(scheme)
        let card = NamesRepo.shared.card(detail.id)
        VStack(alignment: .leading, spacing: 0) {
            (Text("الاسم رقم ") + Text("\(detail.id)"))
                .font(AppFont.sans(14)).foregroundStyle(t.gold)
            Text(detail.name).font(AppFont.serif(40)).foregroundStyle(t.cream).padding(.top, 8)
            if !detail.meaning.isEmpty {
                Text(Arabic.rich(detail.meaning, size: 19))
                    .font(AppFont.sans(19)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8)
                    .padding(.top, 16)
                    .textSelection(.enabled)
            }
            FlowLayout(spacing: 12, lineSpacing: 12) {
                Stat(value: Num.fmt(card?.positions ?? detail.verses.count), label: "موضعًا")
                Stat(value: "\(card?.surahs ?? 0)", label: "سورة")
                Stat(value: detail.compound ? "مركّب" : "مفرد", label: detail.compound ? "صيغة مركّبة" : "اسم مفرد")
            }
            .padding(.top, 24)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                FavoritePill(key: .name(detail.id), item: detail.name)
                SharePill(title: Arabic.nameTitle(detail.name), text: "\(detail.name) — مواضعه في القرآن ومتى يُدعى به",
                          url: Site.nameURL(detail.id),
                          card: ShareCard(kicker: "من أسماء الله الحسنى", headline: AttributedString(detail.name), headlineIsName: true,
                                          source: "مواضعه في القرآن، ومعناه، ومتى يُدعى به"))
                NavigationLink(value: HomeDestination.n(.ask(question: "ما الذي يعلّمني اسم \(detail.name) ومتى أدعو به؟"))) {
                    Text("اسأل عن هذا الاسم")
                }
                .buttonStyle(PrimaryPill(compact: true))
            }
            .padding(.top, 24)
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 20).padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            BrandMark(color: t.gold)
                .frame(width: 400, height: 400)
                .opacity(0.05)
                .offset(x: 140, y: -140)
        }
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.line, lineWidth: 1))
    }
}

private struct Stat: View {
    @Environment(\.colorScheme) private var scheme
    let value: String
    let label: String
    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            Text(value).font(AppFont.sans(20)).foregroundStyle(t.gold)
            Text(label).font(AppFont.sans(12)).foregroundStyle(t.muted)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(t.bg.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 1))
    }
}

/// components/feel/NameCategoryChips.tsx — «ادعُ به حين:» the situations this name belongs to.
private struct SituationChips: View {
    @Environment(\.colorScheme) private var scheme
    let detail: NameDetail
    private let repo = NamesRepo.shared

    var body: some View {
        let t = Theme(scheme)
        var seen = Set<Int>()
        let sits = detail.situations.compactMap { s -> Situation? in
            guard !seen.contains(s.situationId) else { return nil }
            seen.insert(s.situationId)
            return repo.situation(s.situationId)
        }
        return Group {
            if !sits.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ادعُ به حين:").font(AppFont.sans(12.5)).foregroundStyle(t.gold)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(sits) { s in
                            NamesLink(.situation(s.id)) { GoldChip(text: s.label) }
                        }
                    }
                }
                .siteCard(t, radius: 12)
            }
        }
    }
}

/// components/names/SurahIndex.tsx — «السور الواردة».
private struct SurahIndexView: View {
    @Environment(\.colorScheme) private var scheme
    let items: [(no: Int, name: String, count: Int)]
    let onSelect: (Int) -> Void

    var body: some View {
        let t = Theme(scheme)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("السور الواردة").font(AppFont.sans(12.5)).foregroundStyle(t.gold).padding(.horizontal, 8).padding(.bottom, 8)
                ForEach(items, id: \.no) { s in
                    Button { onSelect(s.no) } label: {
                        HStack {
                            (Text("\(s.no). ").font(AppFont.sans(12.5)).foregroundColor(t.muted)
                                + Text(s.name).font(AppFont.sans(15)).foregroundColor(t.cream))
                            Spacer()
                            Text("\(s.count)").font(AppFont.sans(12.5)).foregroundStyle(t.muted)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .siteCard(t, radius: 12, padding: 12)
        }
    }
}

/// components/names/NamePageContent.tsx PrevNext.
private struct PrevNext: View {
    @Environment(\.colorScheme) private var scheme
    let id: Int

    var body: some View {
        let t = Theme(scheme)
        let all = NamesRepo.shared.names
        let i = all.firstIndex { $0.id == id }
        VStack(spacing: 12) {
            if let i, i > 0 {
                let p = all[i - 1]
                NamesLink(.name(p.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("→ السابق · \(p.id)").font(AppFont.sans(12.5)).foregroundStyle(t.muted)
                        Text(p.name).font(AppFont.serif(21)).foregroundStyle(t.cream)
                    }
                    .siteCard(t, radius: 12)
                    .contentShape(Rectangle())
                }
            }
            if let i, i < all.count - 1 {
                let n = all[i + 1]
                NamesLink(.name(n.id)) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(n.id) · التالي ←").font(AppFont.sans(12.5)).foregroundStyle(t.muted)
                        Text(n.name).font(AppFont.serif(21)).foregroundStyle(t.cream)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .siteCard(t, radius: 12)
                    .contentShape(Rectangle())
                }
            }
        }
    }
}

/// components/sunnah/SunnahPanel.tsx — «في السنة»: the card, the witnesses, then the sunnah texts.
private struct SunnahPanel: View {
    @Environment(\.colorScheme) private var scheme
    let detail: NameDetail

    var body: some View {
        let t = Theme(scheme)
        let e = detail.sunnah
        let sections: [(String, String?)] = [
            ("ماذا يعلّمني هذا الاسم عن الله (من السنة)؟", e?.teaches),
            ("متى أستحضر الاسم؟", e?.whenRecall),
            ("متى أدعو به؟", e?.whenPray),
            ("بنود الدعاء بالمأثور", e?.duaItems),
            ("الزبدة", e?.summary),
        ]
        VStack(alignment: .leading, spacing: 32) {
            if let card = e?.card, !card.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("بطاقة الاسم في السنة").font(AppFont.sans(12.5)).foregroundStyle(t.gold)
                    TextBlockView(text: card)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("الشواهد — \(Arabic.count(detail.hadiths.count, Arabic.witnesses))").font(AppFont.serif(22)).foregroundStyle(t.cream)
                VStack(spacing: 16) {
                    ForEach(detail.hadiths) { h in
                        WitnessCardView(hadith: h, nameId: detail.id, nameLabel: detail.name).id("w\(h.i)")
                    }
                }
            }
            ForEach(Array(sections.enumerated()), id: \.offset) { _, s in
                if let text = s.1, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.0).font(AppFont.serif(22)).foregroundStyle(t.cream)
                        TextBlockView(text: text)
                    }
                }
            }
        }
        .multilineTextAlignment(.leading)
    }
}
