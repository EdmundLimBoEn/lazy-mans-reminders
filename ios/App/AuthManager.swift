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

    @Published private(set) var session: Session?
    @Published var isLoading = true
    @Published var message: String?

    let client = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )

    private var pendingAppleNonce: String?
    private let authRedirectURL = URL(string: "lazymansreminders://auth/callback")!

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
    }

    func sendMagicLink(to email: String) async {
        isLoading = true
        message = nil
        do {
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: authRedirectURL
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
                redirectTo: authRedirectURL
            ) { session in
                session.prefersEphemeralWebBrowserSession = true
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
    }

    func registerDevice(token: String) async {
        guard let userID = session?.user.id else { return }
        #if DEBUG
        let environment = "development"
        #else
        let environment = "production"
        #endif
        let device = DeviceToken(token: token, userID: userID, environment: environment)
        try? await client
            .from("device_tokens")
            .upsert(device, onConflict: "token")
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
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
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
