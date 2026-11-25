import SwiftUI

/// «اسأل عن موقفك» of the sunan section (owner 2026-11-25) — the twin of the names' AskView: the visitor describes
/// their state in their own words, the AI (platform POST /api/sunan/ask) points at the closest of the owner's
/// states («الأحوال»), one or two to choose from, and the visitor opens it. Needs the internet.
struct SunanAskView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var q: String
    @State private var items: [SunanExchange] = []
    @State private var busy = false
    @FocusState private var focused: Bool
    private let initial: String

    static let suggested = ["أواجه مشكلة كبيرة", "عليّ ديون وما أقدر أسددها", "ليش دعائي ما يُستجاب؟", "أبي ربي يرزقني ولد"]

    init(initialQuestion: String = "") {
        initial = String(initialQuestion.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600))
        _q = State(initialValue: "")
    }

    var body: some View {
        let t = Theme(scheme)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(SunanText.title).font(AppFont.sans(14)).foregroundStyle(t.gold)
                    Text("اسأل عن موقفك").font(AppFont.serif(30)).foregroundStyle(t.cream)
                    Text("اكتب ما تمرّ به أو ما تحتاجه بلغتك، ونوصلك إلى أقرب حال، وفيها أسبابها من الكتاب والسنة.")
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
                            SunanExchangeView(item: it).id(it.id)
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
        .onAppear {
            // the words typed in the section's search box come with «اسأل عن موقفك»
            if items.isEmpty, initial.count >= 3 { ask(initial) }
        }
        .sunanScreen("اسأل عن موقفك", t)
    }

    private func inputBar(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $q, prompt: Text(items.isEmpty ? "اكتب ما تمرّ به بلغتك: مثلًا «عليّ ديون»" : "صِف حالًا أخرى…").foregroundColor(t.muted),
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
        let ex = SunanExchange(q: text)
        items.append(ex)
        Task { @MainActor in
            let result = await SunanAsk.ask(text)
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

struct SunanExchange: Identifiable, Equatable {
    enum Status { case loading, done }
    let id = UUID()
    let q: String
    var status: Status = .loading
    var matches: [SunanAskMatch] = []
    /// Shown as-is (e.g. the hourly limit). Absent on a plain failure.
    var error: String?
}

/// One state the AI pointed at (platform `app/api/sunan/ask/route.ts`).
struct SunanAskMatch: Decodable, Hashable {
    let stateId: Int
    let needId: Int
    let title: String
    let need: String
    let domain: String
    let href: String
    let items: Int
}

/// POST {site}/api/sunan/ask { question } → { matches } or { error } (429 = the visitor's limit).
enum SunanAsk {
    private struct Response: Decodable {
        let matches: [SunanAskMatch]?
        let error: String?
    }

    static func ask(_ question: String) async -> (matches: [SunanAskMatch], error: String?) {
        var req = URLRequest(url: Site.url("/api/sunan/ask"))
        req.httpMethod = "POST"
        req.timeoutInterval = 35
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["question": question])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let body = try? JSONDecoder().decode(Response.self, from: data)
            let ok = ((resp as? HTTPURLResponse)?.statusCode ?? 500) < 400
            if !ok { return ([], body?.error) }
            // the app's own pack must know the state (a newer server pack may have states this build lacks)
            let known = (body?.matches ?? []).filter { SunanRepo.shared.state($0.stateId) != nil }
            return (known, nil)
        } catch {
            // Offline or unreachable: no technical error — the section is one tap away.
            return ([], nil)
        }
    }
}

/// One question and where it leads.
private struct SunanExchangeView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let item: SunanExchange

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
                    SunanAskCard(matches: item.matches)
                } else {
                    Text(item.error ?? "لم أجد بين الأحوال ما يطابق كلامك.")
                        .font(AppFont.sans(16)).foregroundStyle(t.cream)
                    if item.error == nil {
                        Text("صِف حالك بكلمات أخرى، أو:").font(AppFont.sans(14)).foregroundStyle(t.muted).padding(.top, 4)
                    }
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        Button { nav.open(dest: .sunan) } label: { Text("ماذا تحتاج الآن؟") }
                            .buttonStyle(SecondaryPill(compact: true))
                        SunanLink(.search(query: String(item.q.prefix(120)))) {
                            Text("ابحث بالكلمات").font(AppFont.sans(15, .medium)).foregroundStyle(t.cream)
                                .padding(.horizontal, 14).frame(minHeight: 40)
                                .overlay(Capsule().stroke(t.line, lineWidth: 1))
                        }
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

private struct SunanAskCard: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let matches: [SunanAskMatch]

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 12) {
            Text(matches.count > 1 ? "لعلّ حالك إحدى هاتين — اختر الأقرب:" : "أقرب حالٍ لما وصفت:")
                .font(AppFont.sans(16)).foregroundStyle(t.cream)
            ForEach(matches, id: \.stateId) { m in
                SunanLink(.state(m.stateId)) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.need).font(AppFont.sans(12.5)).foregroundStyle(t.gold)
                            Text(m.title).font(AppFont.sans(18)).foregroundStyle(t.cream).lineSpacing(6)
                            if !m.domain.isEmpty {
                                Text(m.domain).font(AppFont.sans(14)).foregroundStyle(t.muted)
                            }
                        }
                        Spacer(minLength: 4)
                        Text("\(SunanText.count(m.items, SunanText.sunan)) ←").font(AppFont.sans(14)).foregroundStyle(t.gold).fixedSize()
                    }
                    .multilineTextAlignment(.leading)
                    .padding(16)
                    .background(t.bg.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.gold.opacity(0.4), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            HStack(spacing: 0) {
                Text("ليست حالك؟ صِفها بكلمات أخرى، أو ")
                Button { nav.open(dest: .sunan) } label: { Text("تصفّح الحاجات").foregroundStyle(t.gold) }
                    .buttonStyle(.plain)
                Text(".")
            }
            .font(AppFont.sans(14)).foregroundStyle(t.muted)
        }
    }
}
