import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Supabase
import WidgetKit

@MainActor
final class AuthManager: ObservableObject {
    private struct DeviceToken: Encodable {
        let token: String
        let userID: UUID
        let environment: String

        enum CodingKeys: String, CodingKey {
            case token, environment
            case userID = "user_id"
        }
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
    @Published var isLoading = true
    @Published var message: String?

    let client = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )

    private var pendingAppleNonce: String?
    /// Safari cannot follow a 303 onto a custom scheme, so magic links land on HTTPS first.
    private let magicLinkRedirectURL = URL(string: "https://lmr.edmundlim.systems/auth/ios")!
    private let oauthRedirectURL = URL(string: "lazymansreminders://auth/callback")!

    init() {
        Task {
            session = try? await client.auth.session
            await shareSession()
            isLoading = false

            for await (_, nextSession) in await client.auth.authStateChanges {
                session = nextSession
                await shareSession()
            }
        }
        Task { await observeSharedSessionRefresh() }
    }

    func sendMagicLink(to email: String) async {
        isLoading = true
        message = nil
        do {
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: magicLinkRedirectURL
            )
            message = "Check your inbox for the sign-in link."
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        pendingAppleNonce = nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        message = nil
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            message = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                message = "Apple did not return a usable identity token."
                return
            }

            isLoading = true
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
                message = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Opens Google via the system browser (ASWebAuthenticationSession). No GoogleSignIn SDK required.
    func signInWithGoogle() async {
        isLoading = true
        message = nil
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
            message = error.localizedDescription
        }
        isLoading = false
    }

    func handle(url: URL) async {
        do {
            session = try await client.auth.session(from: url)
            await shareSession()
        } catch {
            message = error.localizedDescription
        }
    }

    func signOut() async {
        if let token = AppDelegate.latestDeviceToken {
            try? await client
                .from("device_tokens")
                .delete()
                .eq("token", value: token)
                .execute()
        }
        try? await client.auth.signOut()
        session = nil
        await ReminderStore.shared.clearUserData()
        WidgetCenter.shared.reloadAllTimelines()
        await ReminderLiveActivityController.sync(reminders: [])
    }

    /// Deletes the signed-in user's data and auth account via the `delete-account` Edge Function.
    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")
        // Auth user is already gone; local sign-out may fail — clear client state either way.
        try? await client.auth.signOut()
        session = nil
        message = nil
        await ReminderStore.shared.clearUserData()
        WidgetCenter.shared.reloadAllTimelines()
        await ReminderLiveActivityController.sync(reminders: [])
    }

    func registerDevice(token: String) async {
        guard let userID = session?.user.id else { return }
        #if DEBUG
        let environment = "development"
        #else
        let environment = "production"
        #endif
        let device = DeviceToken(token: token, userID: userID, environment: environment)
        for attempt in 0..<3 {
            do {
                try await client
                    .from("device_tokens")
                    .upsert(device, onConflict: "token")
                    .execute()
                return
            } catch {
                if attempt == 2 { return }
                try? await Task.sleep(nanoseconds: UInt64(400_000_000 * (attempt + 1)))
            }
        }
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

    private func shareSession() async {
        guard let session else {
            await ReminderStore.shared.clearUserData()
            WidgetCenter.shared.reloadAllTimelines()
            await ReminderLiveActivityController.sync(reminders: [])
            return
        }
        try? await ReminderStore.shared.saveSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
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
