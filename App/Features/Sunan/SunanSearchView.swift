import SwiftUI

/// /sunan/search?q=… — app/sunan/search/page.tsx: states matching the query (title, need, keywords, summary).
struct SunanSearchView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    @State private var text: String
    @State private var q: String
    private let repo = SunanRepo.shared

    init(initialQuery: String = "") {
        let start = String(initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        _text = State(initialValue: start)
        _q = State(initialValue: start)
    }

    var body: some View {
        let t = Theme(scheme)
        let hits = repo.search(q)
        let tooShort = !q.isEmpty && SunanRepo.searchWords(q).isEmpty
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SunanText.title).font(AppFont.sans(14)).foregroundStyle(t.gold)
                    Text("ابحث عن حالك").font(AppFont.serif(30)).foregroundStyle(t.cream)
                    SunanSearchField(text: $text) { q = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)) }
                        .padding(.top, 16)
                    Text("يبحث في عناوين الأحوال والحاجات وخلاصاتها وكلماتها — بلا تشكيل وبأي رسم للهمزة.")
                        .font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(5)
                        .padding(.top, 8)
                }
                .multilineTextAlignment(.leading)
                .sunanHeader(t)

                if tooShort {
                    Text("اكتب حرفين على الأقل.").font(AppFont.sans(16)).foregroundStyle(t.muted).padding(.top, 24)
                }
                if !q.isEmpty && !tooShort && hits.isEmpty {
                    VStack(spacing: 8) {
                        Text("لا أحوال تطابق «\(q)».").font(AppFont.sans(16)).foregroundStyle(t.cream)
                        Text("جرّب كلمة أقصر أو أعمّ، أو اسأل عن موقفك بكلامك، أو ابدأ من الحاجات.").font(AppFont.sans(14)).foregroundStyle(t.muted)
                        HStack(spacing: 8) {
                            // owner 2026-11-25: words that match nothing go to the AI, which finds the closest state
                            Button { nav.open(.ask(question: q)) } label: { Text("اسأل عن موقفك") }
                                .buttonStyle(PrimaryPill(compact: true))
                            Button { nav.open(dest: .sunan) } label: { Text("ماذا تحتاج الآن؟") }
                                .buttonStyle(SecondaryPill(compact: true))
                        }
                        .padding(.top, 8)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .sunanRow(t, h: 24, v: 24)
                    .padding(.top, 24)
                }

                if !hits.isEmpty {
                    (Text("أحوال تطابق «\(q)» ") + Text("\(hits.count)").font(AppFont.sans(16)).foregroundColor(t.gold))
                        .font(AppFont.serif(21)).foregroundStyle(t.cream)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 24)
                    LazyVStack(spacing: 8) {
                        ForEach(hits) { h in
                            SunanLink(.state(h.state.id)) { HitRow(hit: h) }
                        }
                    }
                    .padding(.top, 12)
                }
            }
            .padding(16).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .sunanScreen("البحث", t)
    }
}

private struct HitRow: View {
    @Environment(\.colorScheme) private var scheme
    let hit: SunanRepo.StateHit
    var body: some View {
        let t = Theme(scheme)
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.state.title).font(AppFont.sans(16)).foregroundStyle(t.cream)
                Text("\(hit.need.title) — \(SunanRepo.shared.domain(hit.need.domainId)?.title ?? "")")
                    .font(AppFont.sans(12)).foregroundStyle(t.muted)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Text("\(SunanText.count(hit.state.counts.items, SunanText.sunan)) ←").font(AppFont.sans(12)).foregroundStyle(t.gold).fixedSize()
        }
        .sunanRow(t)
    }
}
