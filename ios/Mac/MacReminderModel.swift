import AppKit
import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Supabase

@MainActor
final class MacReminderModel: ObservableObject {
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var isSignedIn = false
    @Published private(set) var isBusy = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var hasBoard = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var codeEmail: String?

    let isDemo: Bool
    private let backend: any MacBoardBackend
    private let auth: AuthClient?
    private var pendingAppleNonce: String?

    convenience init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            self.init(demo: .board)
            return
        }
#endif
        let backend = MacSupabaseBoard()
        self.init(backend: backend, auth: backend.auth)
    }

    init(backend: any MacBoardBackend, auth: AuthClient? = nil, isDemo: Bool = false) {
        self.backend = backend
        self.auth = auth
        self.isDemo = isDemo
    }

#if DEBUG
    convenience init(demo: MacDemoBoard.State) {
        let backend = MacDemoBoard(demo)
        self.init(backend: backend, isDemo: true)
        isSignedIn = backend.hasSession
        reminders = backend.reminders
        hasLoaded = true
        hasBoard = isSignedIn
    }
#endif

    var isFull: Bool { ReminderBoardLimits.isAtCapacity(reminders.count) }

    func refresh(performMaintenance: Bool = true) async {
        guard !isDemo, !isBusy else { return }
        await perform(failure: "Could not load reminders.") {
            try await self.loadBoard(performMaintenance: performMaintenance)
        }
    }

    func sendCode(email: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isBusy, let auth, !email.isEmpty else { return }
        await perform(failure: "Could not send a code.") {
            try await auth.signInWithOTP(email: email, shouldCreateUser: false)
            self.codeEmail = email
        }
    }

    func verifyCode(_ code: String) async {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isBusy, let auth, let codeEmail, !code.isEmpty else { return }
        await signIn {
            _ = try await auth.verifyOTP(email: codeEmail, token: code, type: .email)
        }
    }

    func useDifferentEmail() {
        guard !isBusy else { return }
        codeEmail = nil
        errorMessage = nil
    }

    func signIn(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isBusy, let auth, !email.isEmpty, !password.isEmpty else { return }
        await signIn {
            _ = try await auth.signIn(email: email, password: password)
        }
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        guard !isBusy, !isDemo else { return }
        let nonce = UUID().uuidString + UUID().uuidString
        request.requestedScopes = [.email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }.joined()
        pendingAppleNonce = nonce
        errorMessage = nil
        isBusy = true
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        guard let auth, let nonce = pendingAppleNonce else { return }
        pendingAppleNonce = nil
        await signIn {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let idToken = String(data: data, encoding: .utf8) else {
                throw MacSessionError.invalidAppleCredential
            }
            _ = try await auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
        }
    }

    func signInWithGoogle(window: NSWindow?) async {
        guard !isBusy, let auth else { return }
        await signIn {
            guard let window else { throw MacSessionError.couldNotOpenBrowser }
            let browser = MacWebAuthentication(window: window)
            _ = try await auth.signInWithOAuth(
                provider: .google, redirectTo: MacWebAuthentication.redirectURL,
                queryParams: [("prompt", "select_account")],
                launchFlow: { url in try await browser.open(url) }
            )
        }
    }

    func addIssue(for text: String) -> ReminderStore.StoreError? {
        if isFull { return .atCapacity }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .emptyText }
        if trimmed.unicodeScalars.count > 500 { return .tooLong }
        return nil
    }

    /// A draft is cleared only after the server acknowledges the add.
    func add(_ text: String) async -> Bool {
        guard isSignedIn, hasBoard, !isBusy else { return false }
        if let issue = addIssue(for: text) {
            errorMessage = Self.message(for: issue, fallback: "Could not add reminder.")
            return false
        }
        var saved = false
        await perform(failure: "Could not add reminder.") {
            self.reminders = try await self.backend.add(text.trimmingCharacters(in: .whitespacesAndNewlines))
            saved = true
        }
        return saved
    }

    func complete(_ reminder: Reminder) async {
        guard isSignedIn, hasBoard, !isBusy else { return }
        await perform(failure: "Could not complete reminder.") {
            self.reminders = try await self.backend.complete(reminder.id)
        }
    }

    func signOut() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        await endSession()
    }

    private func signIn(_ authenticate: () async throws -> Void) async {
        await perform(failure: "Could not sign in.") {
            try await authenticate()
            self.codeEmail = nil
            guard self.backend.hasSession else { throw MacSessionError.couldNotSave }
            try await self.loadBoard(performMaintenance: true, reportLoadFailure: true)
        }
    }

    private func loadBoard(performMaintenance: Bool, reportLoadFailure: Bool = false) async throws {
        isSignedIn = backend.hasSession
        do {
            reminders = try await backend.refresh(performMaintenance: performMaintenance)
            hasBoard = isSignedIn
        } catch {
            if reportLoadFailure, !Self.endsSession(error), !Self.isCancellation(error) {
                errorMessage = Self.message(for: error, fallback: "Could not load reminders.")
                return
            }
            throw error
        }
    }

    private func endSession() async {
        isSignedIn = false
        reminders = []
        hasBoard = false
        codeEmail = nil
        await backend.signOut()
    }

    private func perform(failure: String, _ operation: () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer {
            isBusy = false
            hasLoaded = true
        }
        do {
            try await operation()
        } catch {
            if Self.endsSession(error), isSignedIn { await endSession() }
            errorMessage = Self.message(for: error, fallback: failure)
        }
    }

    private static func endsSession(_ error: Error) -> Bool {
        if let error = error as? MacSessionError {
            return error == .ended || error == .suspended
        }
        if let error = error as? AuthError {
            return [.sessionNotFound, .userNotFound, .userBanned, .invalidJWT,
                    .sessionExpired, .refreshTokenNotFound, .refreshTokenAlreadyUsed].contains(error.errorCode)
        }
        if let error = error as? ReminderStore.StoreError {
            switch error {
            case .signedOut, .requestFailed(401): return true
            default: break
            }
        }
        return false
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
            || (error as? ASAuthorizationError)?.code == .canceled
            || (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
    }

    private static func message(for error: Error, fallback: String) -> String? {
        if isCancellation(error) { return nil }
        switch (error as? URLError)?.code {
        case .notConnectedToInternet, .networkConnectionLost: return "You’re offline."
        case .timedOut: return "The connection timed out."
        default: break
        }
        if let error = error as? ReminderStore.StoreError {
            switch error {
            case .atCapacity, .tooLong: return error.errorDescription
            case .emptyText: return nil
            default: break
            }
        }
        if let error = error as? AuthError {
            switch error.errorCode {
            case .invalidCredentials: return "Email or password is incorrect."
            case .otpExpired: return "That code is invalid or expired."
            default: break
            }
        }
        if (error as? AuthError)?.errorCode == .userBanned || (error as? MacSessionError) == .suspended {
            return "This account is suspended."
        }
        switch error as? MacSessionError {
        case .couldNotSave: return "Could not save your sign-in."
        case .couldNotOpenBrowser: return "Could not open sign-in."
        default: break
        }
        if endsSession(error) { return "Sign in again to continue." }
        return fallback
    }
}
