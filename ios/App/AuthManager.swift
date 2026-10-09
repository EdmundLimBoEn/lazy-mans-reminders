import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Supabase

enum AuthNotice: Equatable {
    case checkInbox(email: String)
    case error(String)
}

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    lazy var pushRegistration = PushTokenRegistrar { [client] registration in
        try await client.from("device_tokens")
            .upsert(registration, onConflict: "token")
            .execute()
    }

    private struct LockScreenPrefs: Encodable {
        let userID: UUID
        let maxLines: Int
        let pointSize: Double

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case maxLines = "max_lines"
            case pointSize = "point_size"
        }
    }

    @Published private(set) var session: Session?
    @Published private(set) var isRestoringSession = true
    @Published private(set) var isAuthenticating = false
    @Published private(set) var notice: AuthNotice?

    let client = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )

    private var isEndingSession = false
    private var restorationTask: Task<Void, Never>?
    private var pendingAppleNonce: String?
    /// Safari cannot follow a 303 onto a custom scheme, so magic links land on HTTPS first.
    private let magicLinkRedirectURL = LMRWeb.iosAuthRedirect
    private let oauthRedirectURL = URL(string: "lazymansreminders://auth/callback")!

    init() {
        restorationTask = Task {
            do {
                session = try await client.auth.session
            } catch {
                // An offline refresh is not a sign-out. Keep the cached board and activity.
                session = client.auth.currentSession
            }
            await shareSession()
            isRestoringSession = false
            await registerLiveActivityTokens()
        }
        Task {
            await waitForRestoration()
            for await (event, nextSession) in await client.auth.authStateChanges {
                session = nextSession
                await shareSession(clearWhenSignedOut: event == .signedOut)
            }
        }
        Task { await observeSharedSessionRefresh() }
    }

    func waitForRestoration() async {
        await restorationTask?.value
    }

    func sendMagicLink(to email: String) async {
        isAuthenticating = true
        notice = nil
        defer { isAuthenticating = false }
        do {
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: magicLinkRedirectURL
            )
            notice = .checkInbox(email: email)
        } catch {
            notice = .error(error.localizedDescription)
        }
    }

    func signInWithPassword(email: String, password: String) async {
        guard !isAuthenticating, !isEndingSession, !Task.isCancelled,
              let credentials = PasswordSignInCredentials(email: email, password: password)
        else { return }
        isAuthenticating = true
        notice = nil
        defer { isAuthenticating = false }
        do {
            try Task.checkCancellation()
            session = try await client.auth.signIn(
                email: credentials.email,
                password: credentials.password
            )
            // The SDK has already persisted/emitted the session; finish sharing even if the view disappears.
            await shareSession()
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            notice = .error("Couldn’t sign in. Check your email and password, or use a sign-in link. If you’re offline, reconnect and try again.")
        }
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        pendingAppleNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        notice = nil
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            notice = .error(error.localizedDescription)
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                notice = .error("Apple did not return a usable identity token.")
                return
            }

            isAuthenticating = true
            defer { isAuthenticating = false }
            do {
                session = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idToken,
                        nonce: pendingAppleNonce
                    )
                )
                pendingAppleNonce = nil
                await shareSession()

                if let fullName = credential.fullName {
                    let parts = [fullName.givenName, fullName.middleName, fullName.familyName]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                    if !parts.isEmpty {
                        try? await client.auth.update(
                            user: UserAttributes(
                                data: [
                                    "full_name": .string(parts.joined(separator: " ")),
                                    "given_name": .string(fullName.givenName ?? ""),
                                    "family_name": .string(fullName.familyName ?? ""),
                                ]
                            )
                        )
                    }
                }
            } catch {
                notice = .error(error.localizedDescription)
            }
        }
    }

    /// Opens Google via the system browser (ASWebAuthenticationSession). No GoogleSignIn SDK required.
    func signInWithGoogle() async {
        isAuthenticating = true
        notice = nil
        defer { isAuthenticating = false }
        do {
            session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: oauthRedirectURL,
                queryParams: [("prompt", "select_account")]
            ) { session in
                session.prefersEphemeralWebBrowserSession = false
            }
            await shareSession()
        } catch {
            notice = .error(error.localizedDescription)
        }
    }

    func handle(url: URL) async {
        guard url.host != "board" else { return }
        do {
            session = try await client.auth.session(from: url)
            notice = nil
            await shareSession()
        } catch {
            notice = .error(error.localizedDescription)
        }
    }

    func clearNotice() {
        notice = nil
    }

    func signOut() async {
        isEndingSession = true
        defer { isEndingSession = false }
        await pushRegistration.unbind()
        if let token = pushRegistration.deviceToken {
            try? await client
                .from("device_tokens")
                .delete()
                .eq("token", value: token)
                .execute()
        }
        try? await client.auth.signOut()
        session = nil
        notice = nil
        await ReminderStore.shared.clearUserData()
        await ReminderBoardSync.clear()
    }

    /// Deletes the signed-in user's data and auth account via the `delete-account` Edge Function.
    func deleteAccount() async throws {
        isEndingSession = true
        defer { isEndingSession = false }
        try await client.functions.invoke("delete-account", options: AppleRevocation.invokeOptions)
        pushRegistration.bind(userID: nil)
        // Auth user is already gone; local sign-out may fail — clear client state either way.
        try? await client.auth.signOut()
        session = nil
        notice = nil
        await ReminderStore.shared.clearUserData()
        await ReminderBoardSync.clear()
    }

    func registerDevice(token: String) async {
        pushRegistration.recordDeviceToken(token)
        guard !isRestoringSession, !isEndingSession, session != nil else { return }
        await pushRegistration.flush()
    }

    func registerLiveActivityTokens() async {
        guard !isRestoringSession, !isEndingSession, session != nil else { return }
        await pushRegistration.flush()
    }

    /// Measures this phone’s Live Activity line budget and upserts `lock_screen_prefs`.
    func syncLockScreenPrefs() async {
        let maxLines = LockScreenLineBudget.refreshLocalCache()
        guard let userID = session?.user.id else { return }
        let prefs = LockScreenPrefs(
            userID: userID,
            maxLines: maxLines,
            pointSize: Double(LockScreenLineBudget.pointSize)
        )
        try? await client
            .from("lock_screen_prefs")
            .upsert(prefs, onConflict: "user_id")
            .execute()
    }

    private func shareSession(clearWhenSignedOut: Bool = false) async {
        guard !isEndingSession else { return }
        guard let session else {
            guard clearWhenSignedOut else { return }
            pushRegistration.bind(userID: nil)
            await ReminderStore.shared.clearUserData()
            await ReminderBoardSync.clear()
            return
        }
        try? await ReminderStore.shared.saveSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt),
            userID: session.user.id
        )
        pushRegistration.bind(userID: session.user.id)
        await pushRegistration.flush()
        await syncLockScreenPrefs()
    }

    /// Keep the Supabase Swift client in sync when ReminderStore rotates the
    /// refresh token from a background push (GoTrue rotation invalidates the old one).
    private func observeSharedSessionRefresh() async {
        for await notification in NotificationCenter.default.notifications(named: .didRefreshSharedSession) {
            guard
                let accessToken = notification.userInfo?["accessToken"] as? String,
                let refreshToken = notification.userInfo?["refreshToken"] as? String,
                !refreshToken.isEmpty
            else { continue }
            _ = try? await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
