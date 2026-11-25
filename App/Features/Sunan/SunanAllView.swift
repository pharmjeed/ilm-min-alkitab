import SwiftUI

/// «كل السنن» (owner 2026-11-25: «تصفّح السنن» shows every sunnah classified, the way «كل الأسماء» does): the
/// fifteen domains as category cards — number, title, its first needs, «افتح ←» — opening the domain's page; a
/// search inside the list shows the matching states instead.
struct SunanAllView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var q = ""
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let searching = !SunanRepo.searchWords(q).isEmpty
        let hits = searching ? repo.search(q) : []
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("كل السنن").font(AppFont.serif(30)).foregroundStyle(t.cream)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(t.muted)
                    TextField("", text: $q, prompt: Text("بحث داخل السنن (حال أو حاجة أو كلمة)…").foregroundColor(t.muted))
                        .font(AppFont.sans(15)).foregroundStyle(t.cream)
                        .submitLabel(.search)
                        .onChange(of: q) { _, v in if v.count > 120 { q = String(v.prefix(120)) } }
                    if !q.isEmpty {
                        Button { q = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(t.muted) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).frame(minHeight: 44)
                .background(t.surface, in: Capsule())
                .overlay(Capsule().stroke(t.line, lineWidth: 1))
                .padding(.top, 20)

                if searching {
                    if hits.isEmpty {
                        VStack(spacing: 8) {
                            Text("لا أحوال تطابق «\(q)».").font(AppFont.sans(16)).foregroundStyle(t.cream)
                            Text("جرّب كلمة أقصر أو أعمّ، أو اسأل عن موقفك بكلامك.").font(AppFont.sans(14)).foregroundStyle(t.muted)
                            SunanLink(.ask(question: q)) {
                                Text("اسأل عن موقفك").font(AppFont.sans(15, .medium)).foregroundStyle(t.bg)
                                    .padding(.horizontal, 14).frame(minHeight: 40)
                                    .background(t.gold, in: Capsule())
                            }
                            .padding(.top, 8)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .sunanRow(t, h: 24, v: 24)
                        .padding(.top, 16)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(hits) { h in
                                SunanLink(.state(h.state.id)) { StateRow(state: h.state, need: h.need) }
                            }
                        }
                        .padding(.top, 16)
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(repo.domains) { d in
                            SunanLink(.domain(d.id)) { DomainCategoryCard(domain: d) }
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(16).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .sunanScreen("كل السنن", t)
    }
}

/// One domain on «كل السنن» — like a category card of «كل الأسماء»: number, title, its first needs, «افتح ←».
private struct DomainCategoryCard: View {
    @Environment(\.colorScheme) private var scheme
    let domain: SunanDomain

    var body: some View {
        let t = Theme(scheme)
        let needs = SunanRepo.shared.needs(of: domain)
        let labels = needs.map { $0.short ?? $0.title }
        let first = labels.prefix(4).joined(separator: " · ") + (labels.count > 4 ? " …" : "")
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(domain.id)").font(AppFont.sans(14)).foregroundStyle(t.gold)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(t.gold.opacity(0.6), lineWidth: 1))
                Text(domain.title).font(AppFont.serif(22)).foregroundStyle(t.cream)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            Text(first).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6).lineLimit(2)
            Rectangle().fill(t.line).frame(height: 1)
            HStack {
                Spacer(minLength: 8)
                Text("افتح ←")
            }
            .font(AppFont.sans(14)).foregroundStyle(t.gold)
        }
        .multilineTextAlignment(.leading)
        .siteCard(t, radius: 16)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// A state in the search results: its title, its need and domain, how many sunan.
private struct StateRow: View {
    @Environment(\.colorScheme) private var scheme
    let state: SunanState
    let need: SunanNeed
    var body: some View {
        let t = Theme(scheme)
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title).font(AppFont.sans(16)).foregroundStyle(t.cream)
                Text("\(need.title) — \(SunanRepo.shared.domain(need.domainId)?.title ?? "")")
                    .font(AppFont.sans(12)).foregroundStyle(t.muted)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Text("\(SunanText.count(state.counts.items, SunanText.sunan)) ←").font(AppFont.sans(12)).foregroundStyle(t.gold).fixedSize()
        }
        .sunanRow(t)
    }
}
