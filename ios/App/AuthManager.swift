import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Supabase
import UIKit

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

    @Published private(set) var session: Session? {
        didSet {
            appleCredentialMonitor.update(
                user: session?.user,
                sessionID: session.flatMap { AppleCredentialMonitor.sessionID(accessToken: $0.accessToken) },
                loginProvider: loginProvider(for: session)
            )
        }
    }
    @Published private(set) var isRestoringSession = true
    @Published private(set) var isAuthenticating = false
    @Published private(set) var notice: AuthNotice?

    private let client = AuthSessionClient()

    private let appleCredentialMonitor = AppleCredentialMonitor()
    private let authSessionGate = AuthSessionGate()
    private var knownLogin: AppleCredentialMonitor.LoginContext?
    private var authStateRegistration: (any AuthStateChangeListenerRegistration)?
    private var credentialObservers: Set<AnyCancellable> = []
    private var isEndingSession = false
    private var restorationTask: Task<Void, Never>?
    private var pendingAppleNonce: String?
    /// Safari cannot follow a 303 onto a custom scheme, so magic links land on HTTPS first.
    private let magicLinkRedirectURL = LMRWeb.iosAuthRedirect
    private let oauthRedirectURL = URL(string: "lazymansreminders://auth/callback")!

    init() {
        for name in [ASAuthorizationAppleIDProvider.credentialRevokedNotification,
                     UIApplication.didBecomeActiveNotification] {
            NotificationCenter.default.publisher(for: name)
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        await self?.waitForRestoration()
                        await self?.checkAppleCredential()
                    }
                }
                .store(in: &credentialObservers)
        }
        restorationTask = Task {
            await authSessionGate.acquire()
            defer { authSessionGate.release() }
            authStateRegistration = await client.auth.onAuthStateChange { [weak self] event, nextSession in
                // Never wait on the gate from an SDK event callback.
                Task { @MainActor [weak self] in
                    await self?.applyAuthEvent(event, nextSession: nextSession)
                }
            }
            do {
                session = try await client.auth.session
            } catch {
                // An offline refresh is not a sign-out. Keep the cached board and activity.
                session = client.auth.currentSession
            }
            await shareSession()
            isRestoringSession = false
            Task { await checkAppleCredential() }
        }
        Task { await observeSharedSessionRefresh() }
    }

    private func applyAuthEvent(_ event: AuthChangeEvent, nextSession: Session?) async {
        await authSessionGate.withLock {
            let current = client.auth.currentSession
            // An event queued before cleanup must not clear a newer callback's board.
            guard AuthSessionGate.matchesEvent(
                eventUserID: nextSession?.user.id, eventAccessToken: nextSession?.accessToken,
                currentUserID: current?.user.id, currentAccessToken: current?.accessToken
            ) else { return }
            session = current
            if event == .initialSession || event == .signedIn || event == .userUpdated {
                Task { await checkAppleCredential() }
            }
            await shareSession(clearWhenSignedOut: event == .signedOut)
        }
    }

    private func checkAppleCredential() async {
        guard !isRestoringSession, !isEndingSession, !isAuthenticating,
              let revocation = await appleCredentialMonitor.verifiedRevocation()
        else { return }
        await authSessionGate.cleanUp(if: {
            let current = client.auth.currentSession
            return !isEndingSession && !isAuthenticating
                && appleCredentialMonitor.isCurrent(
                    revocation, user: current?.user,
                    sessionID: current.flatMap { AppleCredentialMonitor.sessionID(accessToken: $0.accessToken) },
                    loginProvider: loginProvider(for: current)
                )
        }, operations: cleanupOperations)
    }

    func waitForRestoration() async {
        await restorationTask?.value
    }

    func sendMagicLink(to email: String) async {
        await waitForRestoration()
        await authSessionGate.acquire()
        defer { authSessionGate.release() }
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

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        pendingAppleNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        await waitForRestoration()
        await authSessionGate.acquire()
        defer { authSessionGate.release() }
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
            defer {
                isAuthenticating = false
                Task { await checkAppleCredential() }
            }
            do {
                let nextSession = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idToken,
                        nonce: pendingAppleNonce
                    )
                )
                installSession(nextSession, loginProvider: "apple")
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
        await waitForRestoration()
        await authSessionGate.acquire()
        defer { authSessionGate.release() }
        isAuthenticating = true
        notice = nil
        defer { isAuthenticating = false }
        do {
            let nextSession = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: oauthRedirectURL,
                queryParams: [("prompt", "select_account")]
            ) { session in
                session.prefersEphemeralWebBrowserSession = false
            }
            installSession(nextSession, loginProvider: "google")
            await shareSession()
        } catch {
            notice = .error(error.localizedDescription)
        }
    }

    func handle(url: URL) async {
        guard url.host != "board" else { return }
        await waitForRestoration()
        await authSessionGate.acquire()
        defer { authSessionGate.release() }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            session = try await client.auth.session(from: url)
            notice = nil
            await shareSession()
        } catch {
            notice = .error(error.localizedDescription)
        }
    }

    private func loginProvider(for session: Session?) -> String? {
        guard let session else { return nil }
        return knownLogin?.provider(accessToken: session.accessToken)
    }

    private func installSession(_ nextSession: Session, loginProvider: String) {
        knownLogin = AppleCredentialMonitor.LoginContext(accessToken: nextSession.accessToken,
                                                        provider: loginProvider)
        session = nextSession
    }

    func clearNotice() {
        notice = nil
    }

    func signOut() async {
        await waitForRestoration()
        await authSessionGate.cleanUp(operations: cleanupOperations)
    }

    private var cleanupOperations: AuthSessionGate.CleanupOperations {
        .init(
            setEndingSession: { self.isEndingSession = $0 },
            unbind: { await self.pushRegistration.unbind() },
            removeDeviceToken: {
                if let token = self.pushRegistration.deviceToken {
                    try? await self.client.from("device_tokens").delete().eq("token", value: token).execute()
                }
            },
            signOutSDK: { try? await self.client.auth.signOut() },
            clearPublishedSession: {
                self.knownLogin = nil
                self.session = nil
                self.notice = nil
            },
            clearUserData: { await ReminderStore.shared.clearUserData() },
            clearBoard: { await ReminderBoardSync.clear() }
        )
    }

    /// Deletes the signed-in user's data and auth account via the `delete-account` Edge Function.
    func deleteAccount(expected: AppleRevocation.DeletionIntent) async throws {
        await waitForRestoration()
        try await AppleRevocation.withValidatedDeletion(
            expected: expected, gate: authSessionGate,
            currentIdentity: { AppleRevocation.DeletionIntent(session: self.client.auth.currentSession) }
        ) {
            isEndingSession = true
            defer { isEndingSession = false }
            let result: AppleRevocation.DeletionResponse = try await client.functions.invoke(
                "delete-account", options: AppleRevocation.invokeOptions
            )
            guard result.ok else { throw AppleRevocation.DeletionError.invalidResponse }
            pushRegistration.bind(userID: nil)
            // Auth user is already gone; local sign-out may fail — clear client state either way.
            try? await client.auth.signOut()
            session = nil
            await ReminderStore.shared.clearUserData()
            await ReminderBoardSync.clear()
            notice = result.notice.map { .error($0) }
        }
    }

    func registerDevice(token: String) async {
        pushRegistration.recordDeviceToken(token)
        await waitForRestoration()
        await authSessionGate.withLock {
            guard !isEndingSession, session != nil else { return }
            await pushRegistration.flush()
        }
    }

    func registerLiveActivityTokens() async {
        await waitForRestoration()
        await authSessionGate.withLock {
            guard !isEndingSession, session != nil else { return }
            await pushRegistration.flush()
        }
    }

    /// Measures this phone’s Live Activity line budget and upserts `lock_screen_prefs`.
    func syncLockScreenPrefs() async {
        await waitForRestoration()
        await authSessionGate.withLock { await syncLockScreenPrefsWhileLocked() }
    }

    private func syncLockScreenPrefsWhileLocked() async {
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
        await syncLockScreenPrefsWhileLocked()
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
            await waitForRestoration()
            await authSessionGate.withLock {
                // A refresh posted before cleanup must never resurrect its signed-out account.
                guard let current = client.auth.currentSession,
                      JWTUserID.uuid(fromAccessToken: accessToken) == current.user.id,
                      await ReminderStore.shared.containsSession(accessToken: accessToken,
                                                                  refreshToken: refreshToken)
                else { return }
                _ = try? await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            }
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
