import Combine
import Foundation
import Supabase

/// A single operation at a time owns auth and board updates. The SDK retains
/// credentials in its Keychain; the store receives an in-memory access token
/// without a refresh token so it cannot race the SDK's token rotation.
@MainActor
final class MacReminderModel: ObservableObject {
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var isSignedIn = false
    @Published private(set) var isBusy = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var codeEmail: String?

    let isDemo: Bool
    private let client: AuthSessionClient?
    private let store: ReminderStore?
#if DEBUG
    private var demoStore: MacDemoStore?
#endif

    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            isDemo = true
            client = nil
            store = nil
            let demo = MacDemoStore()
            demoStore = demo
            reminders = demo.reminders
            isSignedIn = true
            hasLoaded = true
            return
        }
#endif
        isDemo = false
        client = AuthSessionClient()
        store = ReminderStore(defaults: .standard, credentials: MacSessionCredentials())
    }

    func refresh() async {
        guard !isDemo, !isBusy, let client, let store else { return }
        await perform {
            guard client.auth.currentSession != nil else {
                await self.clearBoard(resetCode: false)
                return
            }
            try await self.prepareSession()
            self.reminders = try await store.refresh(
                performMaintenance: false, refreshAuthentication: false
            )
        }
    }

    func sendCode(email: String) async {
        guard !isBusy, let client else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        await perform {
            // Existing accounts only; the hosted email template must include
            // {{ .Token }}. No hosted template or redirect is changed here.
            try await client.auth.signInWithOTP(email: email, shouldCreateUser: false)
            self.codeEmail = email
        }
    }

    func verifyCode(_ code: String) async {
        guard !isBusy, let client, let codeEmail else { return }
        await perform {
            _ = try await client.auth.verifyOTP(
                email: codeEmail,
                token: code.trimmingCharacters(in: .whitespacesAndNewlines), type: .email
            )
            self.codeEmail = nil
            try await self.loadBoard()
        }
    }

    func useDifferentEmail() {
        guard !isBusy else { return }
        codeEmail = nil
        errorMessage = nil
    }

    func signIn(email: String, password: String) async {
        guard !isBusy, let client else { return }
        await perform {
            _ = try await client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password
            )
            self.codeEmail = nil
            try await self.loadBoard()
        }
    }

    /// Returns true only after acknowledgement, so a failed add keeps the draft.
    func add(_ text: String) async -> Bool {
        guard !isBusy else { return false }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.unicodeScalars.count <= 500,
              !ReminderBoardLimits.isAtCapacity(reminders.count) else { return false }
#if DEBUG
        if var demo = demoStore {
            demo.add(text)
            demoStore = demo
            reminders = demo.reminders
            return true
        }
#endif
        guard let store else { return false }
        var saved = false
        await perform {
            try await self.prepareSession()
            self.reminders = try await store.create(text: text)
            saved = true
        }
        return saved
    }

    func complete(_ reminder: Reminder) async {
        guard !isBusy else { return }
#if DEBUG
        if var demo = demoStore {
            demo.complete(reminder.id)
            demoStore = demo
            reminders = demo.reminders
            return
        }
#endif
        guard let store else { return }
        await perform {
            try await self.prepareSession()
            self.reminders = try await store.markDone(id: reminder.id)
        }
    }

    func signOut() async {
        guard !isBusy, let client else { return }
        await perform {
            try await client.auth.signOut(scope: .local)
            await self.clearBoard()
        }
    }

    private func loadBoard() async throws {
        guard let store else { return }
        try await prepareSession()
        reminders = try await store.refresh(performMaintenance: false, refreshAuthentication: false)
    }

    private func prepareSession() async throws {
        guard let client, let store else { return }
        let session = try await client.auth.session
        if await store.storedUserID() != session.user.id {
            reminders = []
            await store.clearUserData()
        }
        try await store.saveSession(
            accessToken: session.accessToken, refreshToken: "",
            expiresAt: Date(timeIntervalSince1970: session.expiresAt), userID: session.user.id
        )
        isSignedIn = true
    }

    private func clearBoard(resetCode: Bool = true) async {
        reminders = []
        isSignedIn = false
        if resetCode { codeEmail = nil }
        await store?.clearUserData()
    }

    private func perform(_ operation: () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false; hasLoaded = true }
        do {
            try await operation()
        } catch {
            // A transient network error preserves the visible board; a removed
            // SDK session must also remove all local reminder data.
            if client?.auth.currentSession == nil { await clearBoard(resetCode: false) }
            if error is CancellationError { return }
            errorMessage = "[PLACEHOLDER - Edmund to write]"
        }
    }
}

/// Owned exclusively by ReminderStore's actor; never persisted to preferences.
private final class MacSessionCredentials: SessionCredentialStorage {
    private var data: Data?
    func read() throws -> Data? { data }
    func write(_ data: Data) throws { self.data = data }
    func insertIfAbsent(_ data: Data) throws { if self.data == nil { self.data = data } }
    func delete() throws { data = nil }
}

#if DEBUG
/// No defaults, Keychain, configuration reads, SDK clients, or network requests.
private struct MacDemoStore {
    private let userID = UUID()
    private(set) var reminders: [Reminder] = []

    init() {
        for _ in 0..<3 { add("[PLACEHOLDER - Edmund to write]") }
    }

    mutating func add(_ text: String) {
        reminders.append(Reminder(
            id: UUID(), userID: userID, text: text,
            sortOrder: (reminders.map(\.sortOrder).max() ?? -1) + 1,
            isDone: false, createdAt: Date()
        ))
    }

    mutating func complete(_ id: UUID) {
        reminders.removeAll { $0.id == id }
    }
}
#endif
