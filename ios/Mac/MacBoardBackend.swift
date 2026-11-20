import Foundation
import Supabase

@MainActor
protocol MacBoardBackend {
    var hasSession: Bool { get }
    func refresh(performMaintenance: Bool) async throws -> [Reminder]
    func add(_ text: String) async throws -> [Reminder]
    func complete(_ id: UUID) async throws -> [Reminder]
    func signOut() async
}

@MainActor
final class MacSupabaseBoard: MacBoardBackend {
    let auth: AuthClient
    private let store = ReminderStore(defaults: .standard, credentials: MacSessionCredentials())

    init() {
        let url = AppConfig.supabaseURL
        let key = AppConfig.supabaseAnonKey
        auth = AuthClient(
            url: url.appending(path: "auth/v1"),
            headers: ["apikey": key, "Authorization": "Bearer \(key)"],
            storageKey: "sb-\(url.host!)-auth-token",
            localStorage: KeychainLocalStorage(service: "systems.edmundlim.notepad.mac-auth"),
            fetch: { request in
                var request = request
                request.timeoutInterval = 15
                return try await URLSession.shared.data(for: request)
            },
            autoRefreshToken: false
        )
    }

    var hasSession: Bool { auth.currentSession != nil }

    func refresh(performMaintenance: Bool) async throws -> [Reminder] {
        guard hasSession else {
            await store.clearUserData()
            return []
        }

        let session = try await auth.session
        // A still-valid JWT can outlive the account. Check with Auth while the board is open.
        do {
            _ = try await auth.user(jwt: session.accessToken)
        } catch let error as AuthError {
            if error.errorCode == .userBanned { throw MacSessionError.suspended }
            if case .api(_, _, _, let response) = error,
               [401, 403, 404].contains(response.statusCode) {
                throw MacSessionError.ended
            }
            throw error
        }
        try await prepareStore(for: session)
        return try await store.refresh(
            performMaintenance: performMaintenance, refreshAuthentication: false
        )
    }

    func add(_ text: String) async throws -> [Reminder] {
        let session = try await auth.session
        try await prepareStore(for: session)
        return try await store.create(text: text)
    }

    func complete(_ id: UUID) async throws -> [Reminder] {
        let session = try await auth.session
        try await prepareStore(for: session)
        return try await store.markDone(id: id)
    }

    func signOut() async {
        await store.clearUserData()
        // The SDK removes its local session before attempting the network request.
        try? await auth.signOut(scope: .local)
    }

    private func prepareStore(for session: Session) async throws {
        if await store.storedUserID() != session.user.id {
            await store.clearUserData()
        }
        try await store.saveSession(
            accessToken: session.accessToken, refreshToken: "",
            expiresAt: Date(timeIntervalSince1970: session.expiresAt), userID: session.user.id
        )
    }
}

enum MacSessionError: Error, Equatable {
    case ended
    case suspended
    case couldNotSave
    case invalidOAuthCallback
    case couldNotOpenBrowser
    case invalidAppleCredential
}

/// The store owns this copy of the access token. Only the SDK can rotate the session.
private final class MacSessionCredentials: SessionCredentialStorage {
    private var data: Data?

    func read() throws -> Data? { data }
    func write(_ data: Data) throws { self.data = data }
    func insertIfAbsent(_ data: Data) throws {
        if self.data == nil { self.data = data }
    }
    func delete() throws { data = nil }
}
