import SwiftUI
import AuthenticationServices

/// ♡ «احفظ» on a name, a situation, a sunan state, a verse or a sunnah. Signed in: saves it and opens
/// «أضِف إلى مجموعة» (owner 2026-11-24: collections in «محفوظاتي»). Signed out: asks to sign in first,
/// saves right after, then offers the collections.
struct FavoritePill: View {
    let key: SavedKey
    let item: String
    @State private var sheet: SaveSheet? = Route.consumeAutoSaveSheet() ? .signIn : nil
    @State private var thenCollections = false

    private enum SaveSheet: Identifiable {
        case signIn, collections
        var id: Int { self == .signIn ? 0 : 1 }
    }

    var body: some View {
        let on = Account.shared.isSignedIn && SavedStore.shared.contains(key)
        Button {
            if Account.shared.isSignedIn {
                if !on { Task { await SavedStore.shared.set(key, on: true) } }
                sheet = .collections
            } else {
                sheet = .signIn
            }
        } label: {
            ActionPill(on: on) {
                Label { Text(on ? "في محفوظاتي" : "احفظ") } icon: { Image(systemName: on ? "heart.fill" : "heart") }
            }
        }
        .buttonStyle(.plain)
        .sheet(item: $sheet, onDismiss: {
            if thenCollections {
                thenCollections = false
                sheet = .collections
            }
        }) { s in
            switch s {
            case .signIn:
                SaveSignInSheet(item: item) {
                    await SavedStore.shared.set(key, on: true)
                    thenCollections = true
                }
            case .collections:
                CollectionsSheet(key: key, item: item)
            }
        }
    }
}

/// «أضِف إلى مجموعة»: the item is in «محفوظاتي»; tick the collections it belongs to, or make a new one.
struct CollectionsSheet: View {
    let key: SavedKey
    let item: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var newTitle = ""
    @State private var creating = false
    @FocusState private var typing: Bool

    var body: some View {
        let t = Theme(scheme)
        let store = SavedStore.shared
        let saved = store.contains(key)
        let inside = store.collectionIds(containing: key)
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: saved ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(saved ? t.gold : t.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(saved ? "في «محفوظاتي»" : "ليس في «محفوظاتي»").font(AppFont.sans(16, .medium))
                            Text(item).font(AppFont.sans(14)).foregroundStyle(t.muted).lineLimit(2)
                        }
                    }
                }
                .listRowBackground(t.surface)

                Section {
                    ForEach(store.collections) { c in
                        Button {
                            Task { await store.collect(key, in: c.id, on: !inside.contains(c.id)) }
                        } label: {
                            HStack {
                                Image(systemName: inside.contains(c.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(inside.contains(c.id) ? t.gold : t.muted)
                                Text(c.title).font(AppFont.sans(17)).foregroundStyle(t.cream)
                                Spacer()
                                Text(Num.fmt(c.items.count)).font(AppFont.sans(14)).foregroundStyle(t.muted)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "plus").foregroundStyle(t.gold)
                        TextField("مجموعة جديدة…", text: $newTitle)
                            .font(AppFont.sans(17))
                            .focused($typing)
                            .submitLabel(.done)
                            .onSubmit { Task { await create() } }
                        if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("أنشئ") { Task { await create() } }
                                .font(AppFont.sans(16, .medium)).foregroundStyle(t.gold)
                                .disabled(creating)
                        }
                    }
                    if let e = store.lastError {
                        Text(e).font(AppFont.sans(14)).foregroundStyle(t.neg)
                    }
                } header: {
                    Text("أضِفه إلى مجموعة").font(AppFont.sans(14, .medium)).foregroundStyle(t.gold)
                } footer: {
                    Text("المجموعات تجمع ما تحفظه كما تحب: أدعية الصباح، أسماء الرحمة، سنن الرزق…")
                        .font(AppFont.sans(13)).foregroundStyle(t.muted)
                }
                .listRowBackground(t.surface)

                if saved {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                await store.set(key, on: false)
                                dismiss()
                            }
                        } label: {
                            Label("إزالة من «محفوظاتي»", systemImage: "heart.slash").font(AppFont.sans(16)).foregroundStyle(t.neg)
                        }
                    }
                    .listRowBackground(t.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(t.bg)
            .foregroundStyle(t.cream)
            .navigationTitle("احفظ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }.font(AppFont.sans(16, .bold)).foregroundStyle(t.gold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func create() async {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !creating else { return }
        creating = true
        defer { creating = false }
        if let c = await SavedStore.shared.createCollection(title) {
            newTitle = ""
            typing = false
            await SavedStore.shared.collect(key, in: c.id, on: true)
        }
    }
}

/// «سجّل الدخول لتحفظ» — the account is optional and only asked for when saving (or from «محفوظاتي» / «المزيد»).
struct SaveSignInSheet: View {
    /// What is being saved; nil when signing in from «محفوظاتي» or «المزيد».
    let item: String?
    var onSignedIn: (() async -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 14) {
            BrandMark(color: t.gold).frame(width: 40, height: 40).padding(.top, 8)
            Text(item == nil ? "سجّل الدخول" : "سجّل الدخول لتحفظ").font(AppFont.serif(26)).foregroundStyle(t.cream)
            Group {
                if let item {
                    Text("يُحفظ «\(item)» في حسابك، فتجده في «محفوظاتي» على أي جهازٍ تدخل منه.")
                } else {
                    Text("ما تحفظه يُحفظ في حسابك، فتجده في «محفوظاتي» على أي جهازٍ تدخل منه.")
                }
            }
            .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.85))
            .multilineTextAlignment(.center).lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)

            SignInButtons {
                await onSignedIn?()
                dismiss()
            }
            .padding(.top, 6)

            Button("ليس الآن") { dismiss() }
                .font(AppFont.sans(16)).foregroundStyle(t.gold)
                .frame(maxWidth: .infinity, minHeight: 44)
            Text("الحساب اختياري، والتطبيق كله متاحٌ دونه.")
                .font(AppFont.sans(13)).foregroundStyle(t.muted)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24).padding(.top, 12)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(t.surface)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

/// Sign in with Apple (the system button) and Google (the platform's web sign-in), then `onSuccess`.
struct SignInButtons: View {
    var onSuccess: () async -> Void
    @Environment(\.webAuthenticationSession) private var webAuth
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let account = Account.shared
        VStack(spacing: 10) {
            SignInWithAppleButton(.continue) { request in
                account.prepareApple(request)
            } onCompletion: { result in
                Task { if await account.completeApple(result) { await onSuccess() } }
            }
            .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await google() }
            } label: {
                HStack(spacing: 8) {
                    Text("G").font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: 0x4285F4))
                    Text("الاستمرار باستخدام «قوقل»").font(AppFont.sans(16, .medium)).foregroundStyle(Color(hex: 0x1F1F1F))
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x747775), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if account.busy {
                ProgressView().tint(t.gold).padding(.top, 4)
            }
            if let e = account.errorText {
                Text(e).font(AppFont.sans(14)).foregroundStyle(t.neg).multilineTextAlignment(.center)
            }
        }
        .disabled(account.busy)
    }

    private func google() async {
        let account = Account.shared
        let (url, verifier) = account.googleRequest()
        do {
            let callback = try await webAuth.authenticate(using: url, callbackURLScheme: AuthConfig.callbackScheme,
                                                          preferredBrowserSession: .shared)
            if await account.completeGoogle(callback: callback, verifier: verifier) { await onSuccess() }
        } catch {
            account.failGoogle(error)
        }
    }
}
