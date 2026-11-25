import SwiftUI

/// /sunan/item/<fp> — app/sunan/item/[fp]/page.tsx.
struct SunanItemPageView: View {
    @Environment(\.colorScheme) private var scheme
    let fp: String
    let stateId: Int?

    var body: some View {
        let t = Theme(scheme)
        SunanLoader(key: fp, load: { try await SunanStore.shared.item(fp: fp, stateHint: stateId) }) { view in
            SunanItemContent(view: view)
        }
        .sunanScreen(SunanText.title, t)
    }
}

private struct SunanItemContent: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let view: SunanItemView
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let item = view.item
        let state = view.state
        let need = repo.need(state.needId)
        let domain = need.flatMap { repo.domain($0.domainId) }
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let need, let domain {
                        CrumbsView(trail: [.sunanHome, Crumb(domain.title, .domain(domain.id)), Crumb(need.title, .need(need.id)),
                                           Crumb(state.title, .state(state.id))],
                                   current: item.ref)
                            .padding(.bottom, 16)
                    }

                    header(t, item, state)

                    textSection(t, item).id("text").padding(.top, 24)

                    if !view.members.isEmpty {
                        SunanHeading(text: "بمعناها", size: 21).padding(.top, 32).id("more")
                        LazyVStack(spacing: 8) {
                            ForEach(view.members) { m in
                                SunanLink(.item(fp: m.fp, stateId: m.stateId)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(SunanText.easy(m.easy, t)).font(AppFont.sans(16)).lineSpacing(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(SunanText.sourceLine(m)).font(AppFont.sans(12)).foregroundStyle(t.muted)
                                    }
                                    .multilineTextAlignment(.leading)
                                    .sunanRow(t)
                                }
                            }
                        }
                        .padding(.top, 12)
                    }

                    let others = (item.otherNeedIds ?? []).compactMap { repo.need($0) }.filter { $0.id != need?.id }
                    if !others.isEmpty {
                        SunanHeading(text: "مداخل أخرى", size: 21).padding(.top, 32)
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(others) { n in
                                SunanLink(.need(n.id)) { SunanChip(text: n.title, size: 14) }
                            }
                        }
                        .padding(.top, 12)
                    }

                    SunanBackLink(text: "→ بقية السنن في «\(state.title)»") { nav.open(.state(state.id)) }
                        .padding(.top, 32)
                }
                .padding(16).padding(.bottom, 24)
            }
            .task {
                guard let anchor = Route.consumeSunanScroll(["legend", "more"]) else { return }
                try? await Task.sleep(nanoseconds: 700_000_000)
                proxy.scrollTo(anchor, anchor: anchor == "legend" ? .center : .top)
            }
        }
    }

    private func header(_ t: Theme, _ item: SunnahItem, _ state: SunanState) -> some View {
        let url = SunanText.itemURL(item.fp)
        return VStack(alignment: .leading, spacing: 0) {
            FlowLayout(spacing: 8, lineSpacing: 6) {
                Text(state.title).font(AppFont.sans(14)).foregroundStyle(t.gold)
                if item.isStar { StarBadge() }
                if item.isIjtihad { IjtihadBadge() }
            }
            Text(SunanText.easy(item.easy, t)).font(AppFont.serif(24)).lineSpacing(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            Text(SunanText.sourceLine(item)).font(AppFont.sans(12)).foregroundStyle(t.muted).padding(.top, 8)

            if let apply = item.apply {
                ApplyBox(apply: apply, titled: true).padding(.top, 16)
            }

            if let rep = view.rep {
                VStack(alignment: .leading, spacing: 2) {
                    Text("هذه السنّة بمعنى سنّةٍ مختارة:").foregroundStyle(t.muted)
                    SunanLink(.item(fp: rep.fp, stateId: rep.stateId)) {
                        Text(rep.easy).foregroundStyle(t.gold).underline(color: t.gold.opacity(0.4))
                    }
                }
                .font(AppFont.sans(14)).lineSpacing(6)
                .padding(.top, 16)
            }

            FlowLayout(spacing: 8, lineSpacing: 8) {
                FavoritePill(key: .sunnah(item.fp), item: item.easy)
                CopyPill(label: "نسخ", text: "\(item.easy) (\(item.ref))\n\(url.absoluteString)")
                SharePill(title: "\(item.easy) — \(SunanText.title)", text: "\(item.easy) (\(item.ref))", url: url,
                          card: SunanText.shareCard(item, state: state))
            }
            .padding(.top, 16)
        }
        .multilineTextAlignment(.leading)
        .sunanHeader(t, gold: true)
    }

    private func textSection(_ t: Theme, _ item: SunnahItem) -> some View {
        let isQuran = item.quran != nil
        let openFolds = Route.sunanOpenFolds
        return VStack(alignment: .leading, spacing: 12) {
            SunanHeading(text: isQuran ? "من القرآن" : "النص كاملًا", size: 21)
            VStack(alignment: .leading, spacing: 0) {
                if let q = item.quran {
                    QuranItemTextView(quran: q)
                } else if let segs = item.text, !segs.isEmpty {
                    HadithRunsView(segs: segs)
                }

                if !isQuran, let meta = metaLine(t, item) {
                    Text(meta).font(AppFont.sans(12)).foregroundStyle(t.muted).lineSpacing(5)
                        .tint(t.gold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                }
                RunsLegend().padding(.top, 12).id("legend")

                if let takhrij = item.takhrij, !takhrij.isEmpty {
                    SunanFold("التخريج", open: openFolds) { Text(takhrij) }
                }
                if let bab = item.bab, !bab.isEmpty {
                    SunanFold("باب الحديث", open: openFolds) { Text(bab) }
                }
                if let refs = item.otherRefs, !refs.isEmpty {
                    SunanFold("روايات أخرى", open: openFolds) { BulletList(lines: refs) }
                }
                if item.isIjtihad, let why = item.ijtihadWhy, !why.isEmpty {
                    SunanFold("لماذا هي اجتهاد؟", open: openFolds) { BulletList(lines: why) }
                }
            }
            .multilineTextAlignment(.leading)
            .sunanRow(t, border: isQuran ? t.gold.opacity(0.35) : Palette.emerald.opacity(0.5), h: 16, v: 16)
        }
    }

    /// «عن الراوي · المرجع · الدرجة · حكم المحدّث: …» · «دُمجت فيها N روايات» — «الحديث في الدرر السنية ↗».
    private func metaLine(_ t: Theme, _ item: SunnahItem) -> AttributedString? {
        var parts: [String] = []
        if let n = item.narrator, !n.isEmpty { parts.append("عن \(n)") }
        if !item.ref.isEmpty { parts.append(item.ref) }
        if let g = item.grade, !g.isEmpty { parts.append(g) }
        if let m = item.muhaddith, !m.isEmpty, m != item.grade, m != "[\(item.grade ?? "")]" { parts.append("حكم المحدّث: \(m)") }
        guard !parts.isEmpty else { return nil }
        var s = parts.joined(separator: " · ")
        if let merged = item.merged, merged > 1 { s += " · دُمجت فيها \(SunanText.count(merged, SunanText.narrations))" }
        var out = AttributedString(s)
        if let code = item.dorar, let u = SunanText.dorarURL(code) {
            var a = AttributedString("الحديث في الدرر السنية \(SunanText.outArrow)")
            a.link = u
            a.foregroundColor = t.gold
            out += AttributedString(" — ") + a
        }
        return out
    }
}
