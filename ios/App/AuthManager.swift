import Combine
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
                redirectTo: URL(string: "lazymansreminders://auth/callback")
            )
            message = "Check your inbox for the sign-in link."
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
            return
        }
        try? await ReminderStore.shared.saveSession(
            accessToken: session.accessToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }
}
