import SwiftUI

/// A situation a verse serves (the website's «directNeeds» of a position), derived from the name's scoped evidence.
struct VerseNeed: Hashable {
    let situationId: Int
    let headline: String?
    let bridge: String?
}

extension NameDetail {
    /// verse index → the situations where it is DIRECT evidence, in the name's situation order.
    func directNeedsByVerse() -> [Int: [VerseNeed]] {
        var out: [Int: [VerseNeed]] = [:]
        for s in situations {
            for e in s.verses where e.strength == "direct" {
                if out[e.i]?.contains(where: { $0.situationId == s.situationId }) == true { continue }
                out[e.i, default: []].append(VerseNeed(situationId: s.situationId, headline: e.headline, bridge: e.bridge))
            }
        }
        return out
    }
}

private struct CardSection: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let text: String
    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(AppFont.sans(16, .bold)).foregroundStyle(t.gold)
            Text(Arabic.rich(text, size: 16)).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8)
                .textSelection(.enabled)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// «جملة الربط» box: the precise state (bold gold) and the bridge sentence, with a gold edge at the start.
private struct BridgeBox<Extra: View>: View {
    @Environment(\.colorScheme) private var scheme
    let situation: String?
    let note: String?
    let extra: Extra
    init(situation: String?, note: String?, @ViewBuilder extra: () -> Extra) {
        self.situation = situation
        self.note = note
        self.extra = extra()
    }
    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 4) {
            if let situation, !situation.isEmpty {
                Text(situation).font(AppFont.sans(16, .bold)).foregroundStyle(t.gold).lineSpacing(6)
            }
            if let note, !note.isEmpty {
                Text(note).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.95)).lineSpacing(8)
            }
            extra
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.gold.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) { Rectangle().fill(t.gold.opacity(0.6)).frame(width: 2) }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// The «شرحٌ قيد المراجعة» badge (text_status = مسودة).
private struct DraftBadge: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let t = Theme(scheme)
        Text("شرحٌ قيد المراجعة").font(AppFont.sans(11)).foregroundStyle(t.muted)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .overlay(Capsule().stroke(t.line, lineWidth: 1))
    }
}

/// A neighbouring verse behind a «إظهار/إخفاء» pill (components/verses/VerseCard.tsx <details>).
private struct NeighbourAyahView: View {
    @Environment(\.colorScheme) private var scheme
    let ayah: NeighbourAyah
    let surah: String
    let isPrev: Bool
    @State private var open: Bool

    init(ayah: NeighbourAyah, surah: String, isPrev: Bool) {
        self.ayah = ayah
        self.surah = surah
        self.isPrev = isPrev
        _open = State(initialValue: isPrev) // the previous verse starts open, the next one closed
    }

    var body: some View {
        let t = Theme(scheme)
        let which = isPrev ? "السابقة" : "التالية"
        VStack(alignment: .leading, spacing: 4) {
            Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                Text(open ? "إخفاء الآية \(which) ▴" : "إظهار الآية \(which) ▾")
                    .font(AppFont.sans(14)).foregroundStyle(t.gold)
                    .padding(.horizontal, 12).frame(minHeight: 40)
                    .overlay(Capsule().stroke(t.gold.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            if open {
                AyahTextView(text: ayah.text, size: 18.5, color: t.muted, reference: "[\(surah): \(ayah.a)]",
                             referenceSize: 12.5, referenceColor: t.muted)
            }
        }
    }
}

/// components/verses/VerseCard.tsx — one position of a name in the Quran.
struct VerseCardView: View {
    @Environment(\.colorScheme) private var scheme
    let verse: Verse
    let nameId: Int
    let nameLabel: String
    let terms: [String]
    /// Bridge sentence and precise state (the name inside a situation).
    var note: String? = nil
    var situation: String? = nil
    /// «متى تستحضر الاسم هنا؟» (the full name page).
    var needs: [VerseNeed] = []
    /// «داخل صفحة الاسم» (the name inside a situation).
    var inside: NamesRoute? = nil

    var body: some View {
        let t = Theme(scheme)
        let v = verse
        let ayahs = v.last.map { "\(v.a)–\($0)" } ?? "\(v.a)"
        let ref = "[\(v.surah): \(ayahs)]"
        let link = Site.url("/names/\(nameId)#p\(v.i)")
        let copyText = "﴿\(v.text)﴾ \(ref)\nاسم الله «\(nameLabel)» — الموضع \(v.i) من \(v.of)\n\(link.absoluteString)"

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                (Text("الموضع ") + Text("\(v.i)").foregroundColor(t.gold) + Text(" من \(v.of)"))
                Spacer()
                if v.draft == true { DraftBadge() }
                Text("\(v.surah): \(ayahs)").foregroundStyle(t.gold)
            }
            .font(AppFont.sans(14)).foregroundStyle(t.muted)

            if (note ?? "").isEmpty == false || (situation ?? "").isEmpty == false {
                BridgeBox(situation: situation, note: note) { EmptyView() }.padding(.top, 12)
            }

            if let prev = v.prev {
                NeighbourAyahView(ayah: prev, surah: v.surah, isPrev: true).padding(.top, 12)
            }

            Group {
                if v.text.isEmpty {
                    Text("— نص الآية غير متوفر —").font(AppFont.sans(16)).foregroundStyle(t.neg)
                } else {
                    AyahTextView(text: v.text, terms: terms, size: 24, reference: ref)
                }
            }
            .padding(.top, 16)

            if let story = v.context, !story.isEmpty {
                CardSection(title: "القصة", text: story).padding(.top, 20)
            }
            if let next = v.next {
                NeighbourAyahView(ayah: next, surah: v.surah, isPrev: false).padding(.top, 12)
            }
            if let reason = v.reason, !reason.isEmpty {
                CardSection(title: "سبب ذكر الاسم", text: reason).padding(.top, 16)
            }
            if let adds = v.adds, !adds.isEmpty {
                CardSection(title: "ماذا يضيف هذا الموضع؟", text: adds).padding(.top, 16)
            }
            if let dorar = v.dorar, !dorar.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("أحاديث تشرح الآية").font(AppFont.sans(16, .bold)).foregroundStyle(t.gold)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(dorar, id: \.id) { h in
                            if let u = URL(string: "https://dorar.net/h/\(h.id)") {
                                Link(destination: u) {
                                    Text(h.label).font(AppFont.sans(14)).foregroundStyle(t.muted)
                                        .padding(.horizontal, 12).padding(.vertical, 4)
                                        .overlay(Capsule().stroke(t.line, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding(.top, 16)
            }
            if !needs.isEmpty {
                NeedsSection(needs: needs).padding(.top, 16)
            }

            Rectangle().fill(t.line).frame(height: 1).padding(.top, 20)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                FavoritePill(item: "\(nameLabel) — \(v.surah) \(v.a)")
                CopyPill(label: "نسخ الآية", text: copyText)
                SharePill(title: "\(nameLabel) — \(v.surah) \(v.a)", text: "﴿\(v.text)﴾ \(ref)", url: link)
                if let inside {
                    NamesLink(inside) { ActionPill { Text("داخل صفحة الاسم") } }
                }
            }
            .padding(.top, 12)
        }
        .multilineTextAlignment(.leading)
        .siteCard(t, radius: 12, border: t.gold.opacity(0.35))
    }
}

/// «متى تستحضر الاسم هنا؟» / «هذا الموضع تدعو به حين:» on the full name page.
private struct NeedsSection: View {
    @Environment(\.colorScheme) private var scheme
    let needs: [VerseNeed]
    private let repo = NamesRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let withHeadline = needs.filter { !($0.headline ?? "").isEmpty }
        let plain = needs.filter { ($0.headline ?? "").isEmpty }
        VStack(alignment: .leading, spacing: 8) {
            Text(withHeadline.isEmpty ? "هذا الموضع تدعو به حين:" : "متى تستحضر الاسم هنا؟")
                .font(AppFont.sans(16, .bold)).foregroundStyle(t.gold)
            ForEach(withHeadline, id: \.self) { n in
                if let sit = repo.situation(n.situationId) {
                    BridgeBox(situation: n.headline, note: n.bridge) {
                        NamesLink(.situation(sit.id)) {
                            GoldChip(text: "\(repo.door(sit.doorId)?.label ?? "") › \(sit.label)")
                        }
                        .padding(.top, 4)
                    }
                }
            }
            if !plain.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(plain, id: \.self) { n in
                        if let sit = repo.situation(n.situationId) {
                            NamesLink(.situation(sit.id)) { GoldChip(text: sit.label) }
                        }
                    }
                }
            }
        }
    }
}

/// components/sunnah/WitnessCard.tsx — one hadith witness of a name.
struct WitnessCardView: View {
    @Environment(\.colorScheme) private var scheme
    let hadith: Hadith
    let nameId: Int
    let nameLabel: String
    var note: String? = nil
    var situation: String? = nil
    var inside: NamesRoute? = nil
    @State private var open = false

    var body: some View {
        let t = Theme(scheme)
        let w = hadith
        let source = w.source ?? ""
        let doc = "\(source)\(w.ref.map { " (\($0))" } ?? "") — عن \(w.narrator ?? "") — الدرجة: \(w.grade ?? "")"
        let judgment = w.judgment.map { $0 != w.grade ? " — حكم المحدث: \($0)" : "" } ?? ""
        let link = Site.url("/names/\(nameId)?tab=sunnah#w\(w.i)")
        let copyText = "«\(w.text)»\n\(doc)\nاسم الله «\(nameLabel)» — الشاهد \(w.i) من \(w.of)\n\(link.absoluteString)"
        let form = w.nameForm ?? ""
        let terms = Arabic.nameTerms(form)
        let marked = Arabic.highlighted(w.text, terms: terms.isEmpty ? (form.isEmpty ? [] : [form]) : terms, mark: t.gold)
        let long = w.text.count > 260

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                (Text("الشاهد ") + Text("\(w.i)").foregroundColor(t.gold) + Text(" من \(w.of)"))
                Spacer()
                if w.draft == true { DraftBadge() }
                Text(w.grade ?? "").foregroundStyle(t.gold)
            }
            .font(AppFont.sans(14)).foregroundStyle(t.muted)

            if (note ?? "").isEmpty == false || (situation ?? "").isEmpty == false {
                BridgeBox(situation: situation, note: note) { EmptyView() }.padding(.top, 12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AttributedString("«") + marked + AttributedString("»"))
                    .font(AppFont.amiri(19.5)).foregroundStyle(t.cream).lineSpacing(10)
                    .lineLimit(open || !long ? nil : 6)
                    .textSelection(.enabled)
                if long {
                    Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                        Text(open ? "إظهار أقل ▴" : "إظهار المزيد ▾").font(AppFont.sans(14)).foregroundStyle(t.gold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 16)

            docLine(t, doc + judgment, url: w.url).padding(.top, 12)

            if let scene = w.scene, !scene.isEmpty {
                CardSection(title: "المشهد (القصة)", text: scene).padding(.top, 20)
            }
            if let reason = w.reason, !reason.isEmpty {
                CardSection(title: "لماذا جاء الاسم هنا؟", text: reason).padding(.top, 16)
            }
            if let adds = w.adds, !adds.isEmpty {
                CardSection(title: "ماذا يضيف هذا الشاهد؟", text: adds).padding(.top, 16)
            }

            Rectangle().fill(t.line).frame(height: 1).padding(.top, 20)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                CopyPill(label: "نسخ الحديث", text: copyText)
                SharePill(title: "\(nameLabel) — \(source)", text: "«\(String(w.text.prefix(280)))» \(doc)", url: link)
                if let inside {
                    NamesLink(inside) { ActionPill { Text("داخل صفحة الاسم") } }
                }
            }
            .padding(.top, 12)
        }
        .multilineTextAlignment(.leading)
        .siteCard(t, radius: 12, border: Palette.emerald.opacity(0.5))
    }

    private func docLine(_ t: Theme, _ text: String, url: String?) -> some View {
        var s = AttributedString(text)
        if let url, let u = URL(string: url) {
            var a = AttributedString("الحديث في الدرر السنية ↗")
            a.link = u
            a.foregroundColor = t.gold
            s += AttributedString(" — ") + a
        }
        return Text(s).font(AppFont.sans(12.5)).foregroundStyle(t.muted).lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
