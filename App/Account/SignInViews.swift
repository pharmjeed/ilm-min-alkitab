import SwiftUI
import AuthenticationServices

/// ♡ on a verse card or a sunnah: saves into the optional account; signed out, it asks to sign in first
/// and saves right after.
struct FavoritePill: View {
    let key: SavedKey
    let item: String
    @State private var asking = Route.consumeAutoSaveSheet()

    var body: some View {
        let on = Account.shared.isSignedIn && SavedStore.shared.contains(key)
        Button {
            if Account.shared.isSignedIn {
                Task { await SavedStore.shared.toggle(key) }
            } else {
                asking = true
            }
        } label: {
            ActionPill(on: on) {
                Label { Text(on ? "في محفوظاتي" : "احفظ") } icon: { Image(systemName: on ? "heart.fill" : "heart") }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $asking) {
            SaveSignInSheet(item: item) { await SavedStore.shared.set(key, on: true) }
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
                    Text("المتابعة باستخدام «قوقل»").font(AppFont.sans(16, .medium)).foregroundStyle(Color(hex: 0x1F1F1F))
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
