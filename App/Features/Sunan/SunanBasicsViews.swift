import SwiftUI

/// /sunan/macro — app/sunan/macro/page.tsx: «السنن الكبرى» grouped by domain (sheet order of first appearance).
struct SunanMacroView: View {
    @Environment(\.colorScheme) private var scheme
    private let repo = SunanRepo.shared

    private struct DomainGroup: Identifiable {
        let id: Int
        let domain: String
        var list: [MacroSunnah]
    }

    private var groups: [DomainGroup] {
        var out: [DomainGroup] = []
        for m in repo.index?.macro ?? [] {
            if let i = out.firstIndex(where: { $0.domain == m.domain }) {
                out[i].list.append(m)
            } else {
                out.append(DomainGroup(id: out.count + 1, domain: m.domain, list: [m]))
            }
        }
        return out
    }

    var body: some View {
        let t = Theme(scheme)
        let groups = self.groups
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CrumbsView(trail: [.sunanHome], current: "السنن الكبرى")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SunanText.title).font(AppFont.sans(14)).foregroundStyle(t.gold)
                        Text("السنن الكبرى").font(AppFont.serif(30)).foregroundStyle(t.cream)
                        Text("\(SunanText.count(repo.index?.macro.count ?? 0, SunanText.sunan)) جامعة: سببٌ ونتيجته، بآياته من القرآن وشواهده من السنة.")
                            .font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(8).padding(.top, 4)
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(groups) { g in
                                Button { withAnimation { proxy.scrollTo("g\(g.id)", anchor: .top) } } label: {
                                    SunanChip(text: g.domain, size: 14)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 12)
                    }
                    .multilineTextAlignment(.leading)
                    .sunanHeader(t)

                    ForEach(groups) { g in
                        VStack(alignment: .leading, spacing: 12) {
                            SunanHeading(text: g.domain, size: 24)
                            ForEach(g.list) { m in MacroCard(macro: m) }
                        }
                        .padding(.top, 32)
                        .id("g\(g.id)")
                    }
                }
                .padding(16).padding(.bottom, 24)
            }
        }
        .sunanScreen("السنن الكبرى", t)
    }
}

private struct MacroCard: View {
    @Environment(\.colorScheme) private var scheme
    let macro: MacroSunnah
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let m = macro
        // some titles are already «السبب ← النتيجة»: colour them instead of repeating the line
        let titled = m.title.contains("←")
        let needs = m.needIds.compactMap { repo.need($0) }
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if titled {
                    Text(SunanText.easy(m.title, t))
                } else {
                    Text(m.title).foregroundStyle(t.cream)
                }
            }
            .font(AppFont.serif(21)).lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !titled, let cause = m.cause, let result = m.result {
                Text(SunanText.easy("\(cause) ← \(result)", t)).font(AppFont.sans(16)).lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            if !m.verses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(m.verses, id: \.self) { v in
                        AyahTextView(text: v.text, size: 21, reference: SunanText.nowrap("[\(Surahs.name(v.s)): \(v.a)]"))
                    }
                }
                .padding(.top, 12)
            }
            if let h = m.hadithText, !h.isEmpty {
                Text(h).font(AppFont.amiri(18.5)).foregroundStyle(t.cream).lineSpacing(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.top, 12)
            }
            if !m.hadithRefs.isEmpty && (m.hadithText ?? "").isEmpty {
                Text("من السنة: \(m.hadithRefs.joined(separator: " · "))").font(AppFont.sans(12)).foregroundStyle(t.muted).lineSpacing(5)
                    .padding(.top, 12)
            }
            if let note = m.note, !note.isEmpty {
                Text(note).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6).padding(.top, 12)
            }
            if !needs.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(needs) { n in
                        SunanLink(.need(n.id)) {
                            Text("\(n.title) ←").font(AppFont.sans(12)).foregroundStyle(t.muted)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .overlay(Capsule().stroke(t.line, lineWidth: 1))
                                .contentShape(Capsule())
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .multilineTextAlignment(.leading)
        .sunanRow(t, border: t.gold.opacity(0.35), h: 16, v: 16)
    }
}

/// /sunan/pairs — app/sunan/pairs/page.tsx: «السنن المتقابلة».
struct SunanPairsView: View {
    @Environment(\.colorScheme) private var scheme
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CrumbsView(trail: [.sunanHome], current: "السنن المتقابلة")
                VStack(alignment: .leading, spacing: 4) {
                    Text(SunanText.title).font(AppFont.sans(14)).foregroundStyle(t.gold)
                    Text("السنن المتقابلة").font(AppFont.serif(30)).foregroundStyle(t.cream)
                    Text("كل سنّةٍ وما يقابلها: سببٌ يوصل إلى الخير، وضدّه يوصل إلى ضدّه.")
                        .font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(8).padding(.top, 4)
                }
                .multilineTextAlignment(.leading)
                .sunanHeader(t)

                LazyVStack(spacing: 12) {
                    ForEach(repo.index?.pairs ?? []) { p in
                        VStack(spacing: 8) {
                            PairSide(text: p.positive, ref: p.positiveRef, edge: t.result.opacity(0.7), fill: t.result.opacity(0.05))
                            PairSide(text: p.negative, ref: p.negativeRef, edge: t.error.opacity(0.6), fill: t.error.opacity(0.05))
                        }
                        .sunanRow(t, h: 16, v: 16)
                    }
                }
                .padding(.top, 16)

                let notes = repo.index?.pairNotes ?? []
                if !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                            Text(SunanText.withQuran(n, size: 14)).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .sunanRow(t, h: 20, v: 16)
                    .padding(.top, 24)
                }
            }
            .padding(16).padding(.bottom, 24)
        }
        .sunanScreen("السنن المتقابلة", t)
    }
}

private struct PairSide: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    let ref: String?
    let edge: Color
    let fill: Color
    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(AppFont.sans(16)).foregroundStyle(t.cream).lineSpacing(8)
            if let ref, !ref.isEmpty { Text(ref).font(AppFont.sans(12)).foregroundStyle(t.muted) }
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill)
        .overlay(alignment: .leading) { Rectangle().fill(edge).frame(width: 2) }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// /sunan/method — app/sunan/method/page.tsx: «المنهج والحدود».
struct SunanMethodView: View {
    @Environment(\.colorScheme) private var scheme
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let all = repo.index?.methodology ?? []
        let first = all.first
        let title = first?.h == true ? first?.t ?? "المنهج والحدود" : "المنهج والحدود"
        let blocks = first?.h == true ? Array(all.dropFirst()) : all
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CrumbsView(trail: [.sunanHome], current: "المنهج والحدود")
                VStack(alignment: .leading, spacing: 4) {
                    Text("المنهج والحدود").font(AppFont.sans(14)).foregroundStyle(t.gold)
                    Text(title).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                }
                .multilineTextAlignment(.leading)
                .sunanHeader(t)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { i, b in
                        if b.h == true {
                            SunanHeading(text: b.t, size: 24, color: t.gold).padding(.top, i == 0 ? 0 : 24)
                        } else {
                            Text(SunanText.withQuran(b.t, size: 16)).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 12)
                        }
                    }
                }
                .multilineTextAlignment(.leading)
                .sunanHeader(t)
                .padding(.top, 16)
            }
            .padding(16).padding(.bottom, 24)
        }
        .sunanScreen("المنهج والحدود", t)
    }
}
