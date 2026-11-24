import Foundation
import AuthenticationServices
import CryptoKit
import Observation
import Security

/// The platform's Supabase Auth (the same accounts as the website). The anon key is public by design
/// (it is in the website's pages too); RLS blocks it, and every saved item goes through the platform API.
enum AuthConfig {
    static let supabaseURL = URL(string: "https://yphppiyqmpigibrmbglh.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlwaHBwaXlxbXBpZ2licm1iZ2xoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0NDM2NjMsImV4cCI6MjEwMzAxOTY2M30.rRUP8DVOCIPom7ANGdjcUhiKERuP_N5LkQGYk0zhHWk"
    static let callbackScheme = "ilm"
    static let callbackURL = "ilm://auth-callback"
}

struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: String
    var email: String?
    var provider: String?
}

private struct TokenResponse: Decodable {
    struct User: Decodable {
        struct Meta: Decodable { let provider: String? }
        let id: String
        let email: String?
        let app_metadata: Meta?
    }
    let access_token: String
    let refresh_token: String
    let expires_in: Double?
    let expires_at: Double?
    let user: User

    var session: AuthSession {
        let exp = expires_at.map { Date(timeIntervalSince1970: $0) } ?? Date().addingTimeInterval(expires_in ?? 3600)
        return AuthSession(accessToken: access_token, refreshToken: refresh_token, expiresAt: exp,
                           userId: user.id, email: user.email, provider: user.app_metadata?.provider)
    }
}

enum AuthError: Error { case rejected(Int) }

/// The optional account (owner: asked for only when saving). Sign in with Apple natively (id token + nonce),
/// or Google through the web (PKCE, back to ilm://auth-callback). The session lives in the Keychain.
@MainActor @Observable
final class Account {
    static let shared = Account()

    private(set) var session: AuthSession?
    var busy = false
    var errorText: String?

    var isSignedIn: Bool { session != nil }
    var providerName: String {
        switch session?.provider {
        case "apple": return "آبل"
        case "google": return "قوقل"
        default: return ""
        }
    }

    private var appleNonce: String?
    private var refreshTask: Task<Void, Never>?

    private init() {
        if let data = Keychain.load(), let s = try? JSONDecoder().decode(AuthSession.self, from: data) {
            session = s
        }
    }

    // MARK: Apple

    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        errorText = nil
        let raw = Self.randomString(32)
        appleNonce = raw
        request.requestedScopes = [.email]
        request.nonce = Self.sha256Hex(raw)
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) async -> Bool {
        let failure = "تعذّر الدخول بحساب آبل. حاول مرة أخرى."
        switch result {
        case .failure(let error):
            if let e = error as? ASAuthorizationError, e.code == .canceled { return false }
            errorText = failure
            return false
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let data = cred.identityToken, let token = String(data: data, encoding: .utf8),
                  let nonce = appleNonce else {
                errorText = failure
                return false
            }
            return await exchange("id_token", ["provider": "apple", "id_token": token, "nonce": nonce], failure: failure)
        }
    }

    // MARK: Google (web sign-in through the platform's Supabase, PKCE)

    func googleRequest() -> (url: URL, verifier: String) {
        errorText = nil
        let verifier = Self.randomString(64)
        let challenge = Self.base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
        var c = URLComponents(url: AuthConfig.supabaseURL.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: AuthConfig.callbackURL),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        return (c.url!, verifier)
    }

    func completeGoogle(callback: URL, verifier: String) async -> Bool {
        let failure = "تعذّر الدخول بحساب قوقل. حاول مرة أخرى."
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            errorText = failure
            return false
        }
        return await exchange("pkce", ["auth_code": code, "code_verifier": verifier], failure: failure)
    }

    func failGoogle(_ error: Error) {
        if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin { return }
        errorText = "تعذّر الدخول بحساب قوقل. حاول مرة أخرى."
    }

    // MARK: session

    /// A valid access token (refreshed when it is about to expire), or nil when signed out.
    func accessToken() async -> String? {
        guard let s = session else { return nil }
        if s.expiresAt.timeIntervalSinceNow > 60 { return s.accessToken }
        if let running = refreshTask {
            await running.value
        } else {
            let t = Task { await self.refresh() }
            refreshTask = t
            await t.value
            refreshTask = nil
        }
        return session?.accessToken
    }

    private func refresh() async {
        guard let s = session else { return }
        do {
            setSession(try await Self.tokenRequest("refresh_token", ["refresh_token": s.refreshToken]))
        } catch AuthError.rejected(let code) where code == 400 || code == 401 {
            clearLocal() // the account was signed out elsewhere or deleted
        } catch {
            // offline: keep the session and try again later
        }
    }

    func signOut() async {
        if let token = session?.accessToken {
            var req = URLRequest(url: AuthConfig.supabaseURL.appendingPathComponent("auth/v1/logout"))
            req.httpMethod = "POST"
            req.setValue(AuthConfig.anonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
        }
        clearLocal()
    }

    /// Deletes the account and everything it saved (Apple requires deletion inside the app).
    func deleteAccount() async -> Bool {
        errorText = nil
        guard let token = await accessToken() else { return false }
        busy = true
        defer { busy = false }
        var req = URLRequest(url: Site.url("/api/app/v1/me"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (_, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 else {
            errorText = "تعذّر حذف الحساب. حاول مرة أخرى."
            return false
        }
        clearLocal()
        return true
    }

    private func exchange(_ grant: String, _ body: [String: String], failure: String) async -> Bool {
        busy = true
        defer { busy = false }
        do {
            setSession(try await Self.tokenRequest(grant, body))
            await SavedStore.shared.reload()
            return true
        } catch {
            errorText = failure
            return false
        }
    }

    private func setSession(_ s: AuthSession) {
        session = s
        if let d = try? JSONEncoder().encode(s) { Keychain.save(d) }
    }

    private func clearLocal() {
        session = nil
        Keychain.delete()
        SavedStore.shared.clear()
    }

    nonisolated private static func tokenRequest(_ grant: String, _ body: [String: String]) async throws -> AuthSession {
        var c = URLComponents(url: AuthConfig.supabaseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "grant_type", value: grant)]
        var req = URLRequest(url: c.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AuthConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw AuthError.rejected(code) }
        return try JSONDecoder().decode(TokenResponse.self, from: data).session
    }

    // MARK: helpers

    nonisolated static func randomString(_ length: Int) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { chars[Int($0) % chars.count] })
    }

    nonisolated static func sha256Hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func base64url(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// One Keychain item holding the session (this device only, available after the first unlock).
enum Keychain {
    private static let base: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "ilm.account",
        kSecAttrAccount as String: "session",
    ]

    static func save(_ data: Data) {
        SecItemDelete(base as CFDictionary)
        var q = base
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    static func load() -> Data? {
        var q = base
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    static func delete() { SecItemDelete(base as CFDictionary) }
}
