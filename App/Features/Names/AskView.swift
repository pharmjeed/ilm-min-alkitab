import SwiftUI

/// /ask — app/ask/page.tsx + components/ask/AskPanel.tsx: the visitor describes their state and is shown the
/// owner's situation for it (one, or two to choose from). Needs the internet; everything else is offline.
struct AskView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    @State private var q: String
    @State private var items: [Exchange] = []
    @State private var busy = false
    @FocusState private var focused: Bool

    static let suggested = ["أخاف من الفقر", "متضايق وما أدري وش أسوي", "كل مرة أتوب وأرجع للذنب", "أمي مريضة وخايف عليها"]

    init(initialQuestion: String = "") {
        _q = State(initialValue: String(initialQuestion.prefix(600)))
    }

    var body: some View {
        let t = Theme(scheme)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("اسأل عن موقفك").font(AppFont.serif(30)).foregroundStyle(t.cream)
                    Text("اكتب ما تمرّ به بلغتك، ونوصلك إلى أقرب حال، وفيها الأسماء التي يُدعى بها بآياتها وأحاديثها.")
                        .font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(6).padding(.top, 4)

                    if items.isEmpty {
                        Text("أمثلة:").font(AppFont.sans(14)).foregroundStyle(t.muted).padding(.top, 24)
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(Self.suggested, id: \.self) { s in
                                Button { ask(s) } label: {
                                    Text(s).font(AppFont.sans(14)).foregroundStyle(t.cream)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .overlay(Capsule().stroke(t.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }

                    VStack(spacing: 24) {
                        ForEach(items) { it in
                            ExchangeView(item: it).id(it.id)
                        }
                    }
                    .padding(.top, 24)
                }
                .multilineTextAlignment(.leading)
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: items) { _, list in
                if let last = list.last { withAnimation { proxy.scrollTo(last.id, anchor: .top) } }
            }
            .safeAreaInset(edge: .bottom) { inputBar(t) }
        }
        .namesScreen("اسأل عن موقفك", t)
    }

    private func inputBar(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $q, prompt: Text(items.isEmpty ? "اكتب ما تمرّ به بلغتك: مثلًا «أخاف من الفقر»" : "صِف حالًا أخرى…").foregroundColor(t.muted),
                      axis: .vertical)
                .font(AppFont.sans(16)).foregroundStyle(t.cream)
                .lineLimit(2...5)
                .focused($focused)
                .disabled(busy)
                .onChange(of: q) { _, v in if v.count > 600 { q = String(v.prefix(600)) } }
                .padding(.horizontal, 8).padding(.vertical, 4)
            HStack {
                Spacer()
                Button { ask(q) } label: { Text(busy ? "جارٍ البحث…" : "اسأل") }
                    .buttonStyle(PrimaryPill(compact: true))
                    .disabled(busy || q.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                    .opacity(busy || q.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 ? 0.5 : 1)
            }
        }
        .padding(12)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .padding(.horizontal, 12).padding(.bottom, 8)
    }

    private func ask(_ question: String) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3, !busy else { return }
        busy = true
        focused = false
        let ex = Exchange(q: text)
        items.append(ex)
        Task { @MainActor in
            let result = await InstantAsk.ask(text)
            if let i = items.firstIndex(where: { $0.id == ex.id }) {
                items[i].status = .done
                items[i].matches = result.matches
                items[i].error = result.error
            }
            busy = false
            q = ""
        }
    }
}

struct Exchange: Identifiable, Equatable {
    enum Status { case loading, done }
    let id = UUID()
    let q: String
    var status: Status = .loading
    var matches: [InstantMatch] = []
    /// Shown as-is (e.g. the hourly limit). Absent on a plain failure.
    var error: String?
}

struct InstantMatch: Decodable, Hashable {
    let general: String
    let label: String
    let situation: String?
    let href: String
    let count: Int
    let general_slug: String?
    let sub_slug: String?

    /// The app's own situation for the answer (slugs, else the href /feel/<door>/<sub>).
    var situationId: Int? {
        let repo = NamesRepo.shared
        if let g = general_slug, let s = sub_slug, let sit = repo.situation(doorSlug: g, subSlug: s) { return sit.id }
        let parts = href.split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        if parts.count >= 3, parts[0] == "feel" { return repo.situation(doorSlug: parts[1], subSlug: parts[2])?.id }
        return nil
    }
}

/// POST {site}/api/ask/instant { question } → { matches } or { error } (429 = the visitor's limit).
enum InstantAsk {
    private struct Response: Decodable {
        let matches: [InstantMatch]?
        let error: String?
    }

    static func ask(_ question: String) async -> (matches: [InstantMatch], error: String?) {
        var req = URLRequest(url: Site.url("/api/ask/instant"))
        req.httpMethod = "POST"
        req.timeoutInterval = 35
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["question": question])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let body = try? JSONDecoder().decode(Response.self, from: data)
            let ok = ((resp as? HTTPURLResponse)?.statusCode ?? 500) < 400
            if !ok { return ([], body?.error) }
            return (body?.matches ?? [], nil)
        } catch {
            // Offline or unreachable: like the website, no technical error — the content is one tap away.
            return ([], nil)
        }
    }
}

/// One question and where it leads (AskPanel exchange + components/ask/InstantCard.tsx).
private struct ExchangeView: View {
    @Environment(\.colorScheme) private var scheme
    let item: Exchange

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer(minLength: 32)
                Text(item.q).font(AppFont.sans(16)).foregroundStyle(t.cream)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(t.surface2, in: UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16))
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16).stroke(t.line, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 0) {
                if item.status == .loading {
                    Text("جارٍ البحث عن أقرب حال…").font(AppFont.sans(16)).foregroundStyle(t.muted)
                } else if !item.matches.isEmpty {
                    InstantCard(matches: item.matches)
                } else {
                    Text(item.error ?? "لم أجد بين الأحوال المكتوبة ما يطابق كلامك.")
                        .font(AppFont.sans(16)).foregroundStyle(t.cream)
                    if item.error == nil {
                        Text("صِف حالك بكلمات أخرى، أو:").font(AppFont.sans(14)).foregroundStyle(t.muted).padding(.top, 4)
                    }
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        NavigationLink(value: HomeDestination.n(.feel)) { Text("تصفّح كل الأحوال") }
                            .buttonStyle(SecondaryPill(compact: true))
                        NavigationLink(value: HomeDestination.n(.allNames(query: String(item.q.prefix(120))))) { Text("ابحث عنه في المنصة") }
                            .buttonStyle(SecondaryPill(compact: true))
                    }
                    .padding(.top, 12)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.surface, in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 4))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 4).stroke(t.gold.opacity(0.35), lineWidth: 1))
        }
    }
}

private struct InstantCard: View {
    @Environment(\.colorScheme) private var scheme
    let matches: [InstantMatch]

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 12) {
            Text(matches.count > 1 ? "لعلّ حالك إحدى هاتين — اختر الأقرب:" : "أقرب حالٍ لما وصفت:")
                .font(AppFont.sans(16)).foregroundStyle(t.cream)
            ForEach(matches, id: \.href) { m in
                let row = HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.general).font(AppFont.sans(12.5)).foregroundStyle(t.gold)
                        Text((m.situation ?? "").isEmpty ? m.label : (m.situation ?? "")).font(AppFont.sans(18)).foregroundStyle(t.cream).lineSpacing(6)
                        if !(m.situation ?? "").isEmpty {
                            Text(m.label).font(AppFont.sans(14)).foregroundStyle(t.muted)
                        }
                    }
                    Spacer(minLength: 4)
                    Text("\(Arabic.count(m.count, Arabic.names)) ←").font(AppFont.sans(14)).foregroundStyle(t.gold).fixedSize()
                }
                .multilineTextAlignment(.leading)
                .padding(16)
                .background(t.bg.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.gold.opacity(0.4), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 16))
                NamesLink(m.situationId.map { NamesRoute.situation($0) } ?? NamesRoute.feel) { row }
            }
            HStack(spacing: 0) {
                Text("ليست حالك؟ صِفها بكلمات أخرى، أو ")
                NamesLink(.feel) { Text("تصفّح كل الأحوال").foregroundStyle(t.gold) }
                Text(".")
            }
            .font(AppFont.sans(14)).foregroundStyle(t.muted)
        }
    }
}
