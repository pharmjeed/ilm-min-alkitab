import SwiftUI

/// «أرسل ملاحظة» (owner 2026-11-25: «اريد ان يرسلها من التطبيق نفسه وليس ان تنقله لموقع»): the website's
/// «اقتراح أو إضافة» form inside the app — kind, the note, optional name and e-mail — sent to the platform
/// (POST /api/app/v1/suggest), where it lands with the website's suggestions in the admin panel.
struct FeedbackView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "general"
    @State private var message = ""
    @State private var name = ""
    @State private var email = Account.shared.session?.email ?? ""
    @State private var sending = false
    @State private var error: String?
    @State private var sent = false
    @FocusState private var focused: Bool

    static let kinds: [(id: String, label: String)] = [("general", "ملاحظة عامة"), ("feature", "اقتراح ميزة"), ("content", "إضافة محتوى")]
    static let minChars = 10
    static let maxChars = 3000

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var ready: Bool { trimmed.count >= Self.minChars && !sending }

    var body: some View {
        let t = Theme(scheme)
        List {
            if sent {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle").font(.system(size: 44, weight: .light)).foregroundStyle(t.gold)
                        Text("وصلت ملاحظتك، جزاك الله خيرًا").font(AppFont.serif(24)).foregroundStyle(t.cream)
                        Text("يقرؤها صاحب المنصة بنفسه.").font(AppFont.sans(15)).foregroundStyle(t.muted)
                        Button { dismiss() } label: { Text("تم").frame(maxWidth: .infinity) }
                            .buttonStyle(PrimaryPill())
                            .padding(.top, 8)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .listRowBackground(t.surface)
            } else {
                Section {
                    Picker("نوع الملاحظة", selection: $kind) {
                        ForEach(Self.kinds, id: \.id) { k in Text(k.label).tag(k.id) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    head("نوع الملاحظة", t)
                }
                .listRowBackground(t.surface)

                Section {
                    TextField("", text: $message, prompt: Text("اكتب ملاحظتك أو اقتراحك هنا…").foregroundColor(t.muted), axis: .vertical)
                        .font(AppFont.sans(17)).foregroundStyle(t.cream)
                        .lineLimit(6...14)
                        .focused($focused)
                        .onChange(of: message) { _, v in if v.count > Self.maxChars { message = String(v.prefix(Self.maxChars)) } }
                } header: {
                    head("ملاحظتك", t)
                } footer: {
                    Text(trimmed.count < Self.minChars ? "اكتب \(Self.minChars) أحرف على الأقل." : "\(message.count) من \(Self.maxChars)")
                        .font(AppFont.sans(13)).foregroundStyle(t.muted)
                }
                .listRowBackground(t.surface)

                Section {
                    TextField("", text: $name, prompt: Text("الاسم (اختياري)").foregroundColor(t.muted))
                        .font(AppFont.sans(17)).foregroundStyle(t.cream)
                        .textContentType(.name)
                    TextField("", text: $email, prompt: Text("البريد (اختياري) لنردّ عليك").foregroundColor(t.muted))
                        .font(AppFont.sans(17)).foregroundStyle(t.cream)
                        .keyboardType(.emailAddress).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: {
                    head("للتواصل معك", t)
                }
                .listRowBackground(t.surface)

                Section {
                    Button { send() } label: {
                        HStack(spacing: 10) {
                            if sending { ProgressView().tint(t.bg) }
                            Text(sending ? "جارٍ الإرسال…" : "إرسال")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryPill())
                    .disabled(!ready)
                    .opacity(ready ? 1 : 0.5)
                    if let error {
                        Text(error).font(AppFont.sans(14)).foregroundStyle(t.neg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .multilineTextAlignment(.leading)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(t.bg.ignoresSafeArea())
        .navigationTitle("أرسل ملاحظة")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func head(_ s: String, _ t: Theme) -> some View {
        Text(s).font(AppFont.sans(14, .medium)).foregroundStyle(t.gold)
    }

    private func send() {
        guard ready else { return }
        sending = true
        error = nil
        focused = false
        let body: [String: String] = [
            "kind": kind,
            "message": trimmed,
            "reporter_name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "reporter_email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "website": "",
        ]
        Task { @MainActor in
            let r = await FeedbackSender.send(body)
            sending = false
            if r.ok { withAnimation { sent = true } } else { error = r.error }
        }
    }
}

/// POST {site}/api/app/v1/suggest → { ok } or { error } (Arabic, shown as-is).
enum FeedbackSender {
    private struct Response: Decodable {
        let ok: Bool?
        let error: String?
    }

    static func send(_ body: [String: String]) async -> (ok: Bool, error: String?) {
        var req = URLRequest(url: Site.url("/api/app/v1/suggest"))
        req.httpMethod = "POST"
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let r = try? JSONDecoder().decode(Response.self, from: data)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 500
            if status < 400, r?.ok == true { return (true, nil) }
            return (false, r?.error ?? "تعذّر الإرسال الآن. حاول مرة أخرى بعد قليل.")
        } catch {
            return (false, "تعذّر الإرسال: تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.")
        }
    }
}
