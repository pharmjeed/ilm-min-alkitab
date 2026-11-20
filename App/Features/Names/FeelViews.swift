import SwiftUI

/// /feel — app/feel/page.tsx
struct FeelView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let t = Theme(scheme)
        ScrollView {
            VStack(spacing: 24) {
                FeelEntry(heading: true)
                Text("﴿وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا﴾ — لكل حالٍ من أحوالك أسماءٌ تدعو الله بها؛ اختر ما أنت فيه.")
                    .font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(16).padding(.bottom, 24)
        }
        .namesScreen("ماذا تشعر الآن؟", t)
    }
}

/// /feel/<door> — app/feel/[general]/page.tsx
struct DoorView: View {
    @Environment(\.colorScheme) private var scheme
    let doorId: Int
    private let repo = NamesRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let door = repo.door(doorId)
        ScrollView {
            if let door {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(door.label).font(AppFont.sans(14)).foregroundStyle(t.gold)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("أيُّ حالٍ أقرب إلى ما تعيشه؟").font(AppFont.serif(30)).foregroundStyle(t.cream)
                        let lead = door.lead ?? door.description
                        if !lead.isEmpty {
                            Text(lead).font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(8).padding(.top, 4)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .siteCard(t, padding: 20)

                    LazyVStack(spacing: 8) {
                        ForEach(repo.situations(of: door)) { s in
                            NamesLink(.situation(s.id)) { SituationRowView(situation: s) }
                        }
                    }
                }
                .padding(16).padding(.bottom, 24)
            }
        }
        .namesScreen(door?.label ?? "", t)
    }
}

/// /feel/<door>/<situation> — app/feel/[general]/[sub]/page.tsx
struct SituationView: View {
    @Environment(\.colorScheme) private var scheme
    let situationId: Int
    private let repo = NamesRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let sit = repo.situation(situationId)
        let door = sit.flatMap { repo.door($0.doorId) }
        ScrollView {
            if let sit, let door {
                VStack(alignment: .leading, spacing: 16) {
                    CrumbsView(trail: [Crumb("ماذا تشعر الآن؟", .feel), Crumb(door.label, .door(door.id))], current: sit.label)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(door.label).font(AppFont.sans(14)).foregroundStyle(t.gold)
                            if sit.innerLevel != nil, sit.innerType != nil {
                                NamesLink(.anfus(focus: repo.innerType(labelled: sit.innerType)?.slug)) {
                                    InnerMarkView(level: sit.innerLevel)
                                }
                            }
                        }
                        Text(sit.situation.isEmpty ? sit.label : sit.situation)
                            .font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                        if !sit.situation.isEmpty {
                            Text(sit.label).font(AppFont.sans(14)).foregroundStyle(t.muted)
                        }
                        (Text("ادعُ الله بهذه الأسماء — ") + Text("\(sit.names.count)").foregroundColor(t.gold) + Text(" اسمًا:"))
                            .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9))
                            .padding(.top, 12)
                    }
                    .multilineTextAlignment(.leading)
                    .siteCard(t, border: t.gold.opacity(0.4), padding: 20)

                    LazyVStack(spacing: 12) {
                        ForEach(Array(sit.names.enumerated()), id: \.offset) { i, n in
                            if let card = repo.card(n.id) {
                                let scoped = n.verses + n.hadiths > 0
                                NamesLink(scoped ? .nameInSituation(name: n.id, situation: sit.id) : .name(n.id)) {
                                    SituationNameRow(index: i + 1, card: card, entry: n)
                                }
                            }
                        }
                    }

                    Text("العدّادات تُحصي آياتِ هذا الموقف وأحاديثَه لكل اسم؛ ومن الأسماء ما دخل الموقف بشاهدٍ من السنة وحده.")
                        .font(AppFont.sans(12.5)).foregroundStyle(t.muted).lineSpacing(5)
                        .multilineTextAlignment(.leading)
                }
                .padding(16).padding(.bottom, 24)
            }
        }
        .namesScreen(sit?.label ?? "", t)
    }
}

private struct SituationNameRow: View {
    @Environment(\.colorScheme) private var scheme
    let index: Int
    let card: NameCard
    let entry: SituationName

    var body: some View {
        let t = Theme(scheme)
        let scoped = entry.verses + entry.hadiths > 0
        let label = scoped
            ? "\(Arabic.supportLabel(entry.verses, entry.hadiths)) هنا"
            : (card.positions > 0 ? Arabic.count(card.positions, Arabic.positions) : "")
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                (Text("\(index)  ").font(AppFont.sans(12.5)).foregroundColor(t.muted)
                    + Text(card.name).font(AppFont.serif(21)).foregroundColor(t.gold))
                Spacer(minLength: 4)
                Text(label).font(AppFont.sans(12.5)).foregroundStyle(t.muted).fixedSize()
            }
            if !card.excerpt.isEmpty {
                Text(card.excerpt).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8)
            }
        }
        .multilineTextAlignment(.leading)
        .siteCard(t, radius: 12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// /feel/<door>/<situation>/<id> — app/feel/[general]/[sub]/[id]/page.tsx: this situation's verses, then its hadiths.
struct NameInSituationView: View {
    @Environment(\.colorScheme) private var scheme
    let nameId: Int
    let situationId: Int
    private let repo = NamesRepo.shared

    var body: some View {
        let t = Theme(scheme)
        NameDetailLoader(id: nameId) { d in
            NameInSituationContent(detail: d, situationId: situationId)
        }
        .namesScreen(repo.card(nameId)?.name ?? "", t)
    }
}

private struct NameInSituationContent: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let detail: NameDetail
    let situationId: Int
    private let repo = NamesRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let d = detail
        let sit = repo.situation(situationId)
        let door = sit.flatMap { repo.door($0.doorId) }
        let scoped = d.situations.first { $0.situationId == situationId }
        let versesByI = Dictionary(d.verses.map { ($0.i, $0) }, uniquingKeysWith: { a, _ in a })
        let hadithsByI = Dictionary(d.hadiths.map { ($0.i, $0) }, uniquingKeysWith: { a, _ in a })
        let verses = (scoped?.verses ?? []).compactMap { e in versesByI[e.i].map { ScopedVerse(evidence: e, verse: $0) } }
        let direct = verses.filter { $0.evidence.strength == "direct" }
        let support = verses.filter { $0.evidence.strength != "direct" }
        let witnesses = (scoped?.hadiths ?? []).compactMap { e in hadithsByI[e.i].map { ScopedHadith(evidence: e, hadith: $0) } }
        let total = repo.card(d.id)?.positions ?? d.verses.count
        let summary = Arabic.supportLabel(verses.count, witnesses.count)
        let terms = Arabic.nameTerms(d.name)

        ScrollView {
            if let sit, let door {
                VStack(alignment: .leading, spacing: 0) {
                    CrumbsView(trail: [Crumb("ماذا تشعر الآن؟", .feel), Crumb(door.label, .door(door.id)), Crumb(sit.label, .situation(sit.id))],
                               current: d.name)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(sit.label).font(AppFont.sans(14)).foregroundStyle(t.gold)
                        Text(d.name).font(AppFont.serif(32)).foregroundStyle(t.gold).padding(.top, 4)
                        if !sit.situation.isEmpty {
                            Text(sit.situation).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8).padding(.top, 8)
                        }
                        Group {
                            if summary.isEmpty {
                                Text("لم تُخصَّص آيات أو أحاديث لهذا الاسم في هذا الموقف بعد.")
                            } else {
                                Text("لهذا الموقف من «\(d.name)»: \(summary)"
                                     + (total > verses.count ? " — ومواضعه في القرآن كلها \(Arabic.count(total, Arabic.positions))" : "")
                                     + ".")
                            }
                        }
                        .font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(8).padding(.top, 12)
                        NamesLink(.name(d.id)) {
                            Text("كل مواضع «\(d.name)» ←").font(AppFont.sans(14)).foregroundStyle(t.gold)
                        }
                        .padding(.top, 12)
                    }
                    .multilineTextAlignment(.leading)
                    .siteCard(t, border: t.gold.opacity(0.4), padding: 20)

                    if !verses.isEmpty {
                        Text("من القرآن").font(AppFont.serif(22)).foregroundStyle(t.cream).padding(.top, 24).padding(.bottom, 12)
                        evidenceVerses(direct, d: d, terms: terms)
                        if !support.isEmpty {
                            Text("وتؤيّده").font(AppFont.serif(22)).foregroundStyle(t.cream).padding(.top, 32).padding(.bottom, 12)
                            evidenceVerses(support, d: d, terms: terms)
                        }
                    }

                    if !witnesses.isEmpty {
                        Text("من السنة").font(AppFont.serif(22)).foregroundStyle(t.cream).padding(.top, 32).padding(.bottom, 12)
                        LazyVStack(spacing: 16) {
                            ForEach(witnesses) { x in
                                WitnessCardView(hadith: x.hadith, nameId: d.id, nameLabel: d.name,
                                                note: x.evidence.bridge, situation: x.evidence.headline,
                                                inside: .name(d.id, tab: .sunnah, focus: x.hadith.i))
                            }
                        }
                    }

                    if verses.isEmpty && witnesses.isEmpty {
                        HStack(spacing: 0) {
                            Text("افتح ")
                            NamesLink(.name(d.id)) { Text("صفحة «\(d.name)»").foregroundStyle(t.gold) }
                            Text(" لتقرأ مواضعه ومتى تدعو به.")
                        }
                        .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9))
                        .siteCard(t, padding: 20)
                        .padding(.top, 24)
                    }

                    Button { nav.open(.situation(sit.id)) } label: {
                        Text("→ بقية الأسماء عند \(sit.label)")
                            .font(AppFont.sans(14)).foregroundStyle(t.cream)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(t.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 32)
                }
                .padding(16).padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func evidenceVerses(_ list: [ScopedVerse], d: NameDetail, terms: [String]) -> some View {
        LazyVStack(spacing: 16) {
            ForEach(list) { x in
                VerseCardView(verse: x.verse, nameId: d.id, nameLabel: d.name, terms: terms,
                              note: x.evidence.bridge, situation: x.evidence.headline,
                              inside: .name(d.id, focus: x.verse.i))
            }
        }
    }
}

struct ScopedVerse: Identifiable {
    let evidence: ScopedEvidence
    let verse: Verse
    var id: Int { verse.i }
}

struct ScopedHadith: Identifiable {
    let evidence: ScopedEvidence
    let hadith: Hadith
    var id: Int { hadith.i }
}

/// /feel/anfus — app/feel/anfus/page.tsx
struct AnfusView: View {
    @Environment(\.colorScheme) private var scheme
    var focus: String?
    private let repo = NamesRepo.shared

    /// الأنفال 53, verbatim from the platform's data/quran.json (the page is named after it).
    private static let ayah = "ذَلِكَ بِأَنَّ اللَّهَ لَمْ يَكُ مُغَيِّرًا نِعْمَةً أَنْعَمَهَا عَلَى قَوْمٍ حَتَّى يُغَيِّرُوا مَا بِأَنْفُسِهِمْ وَأَنَّ اللَّهَ سَمِيعٌ عَلِيمٌ"

    var body: some View {
        let t = Theme(scheme)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ما بأنفسهم").font(AppFont.serif(30)).foregroundStyle(t.cream)
                        AyahTextView(text: Self.ayah, size: 22, color: t.gold).padding(.top, 12)
                        Text("[الأنفال: 53]").font(AppFont.sans(12.5)).foregroundStyle(t.muted).padding(.top, 4)
                        Text("حين يكون العلاج في قلبك لا في ظرفك")
                            .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).padding(.top, 16)
                        FlowLayout(spacing: 16, lineSpacing: 8) {
                            HStack(spacing: 6) { InnerMarkView(level: "صريح"); Text("الحال نفسها في قلبك.") }
                            HStack(spacing: 6) { InnerMarkView(level: "مشترك"); Text("ظرفٌ خارجي، وأثره في قلبك جزءٌ منه.") }
                        }
                        .font(AppFont.sans(14)).foregroundStyle(t.muted)
                        .padding(.top, 12)
                    }
                    .multilineTextAlignment(.leading)
                    .siteCard(t, border: t.gold.opacity(0.4), padding: 20)

                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(repo.inner) { g in
                            Button { withAnimation { proxy.scrollTo(g.slug, anchor: .top) } } label: { GoldChip(text: g.label) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 16)

                    ForEach(repo.inner) { g in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(g.label).font(AppFont.serif(26)).foregroundStyle(t.gold)
                            if !g.description.isEmpty {
                                Text(g.description).font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(6).padding(.top, 4)
                            }
                            VStack(spacing: 8) {
                                ForEach(g.situations, id: \.id) { ref in
                                    if let s = repo.situation(ref.id) {
                                        NamesLink(.situation(s.id)) {
                                            SituationRowView(situation: s, mark: ref.level, doorLabel: repo.door(s.doorId)?.label)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 12)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(.top, 32)
                        .id(g.slug)
                    }
                }
                .padding(16).padding(.bottom, 24)
            }
            .task {
                guard let focus else { return }
                try? await Task.sleep(nanoseconds: 350_000_000)
                withAnimation { proxy.scrollTo(focus, anchor: .top) }
            }
        }
        .namesScreen("ما بأنفسهم", t)
    }
}
