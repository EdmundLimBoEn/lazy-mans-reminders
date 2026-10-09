import AuthenticationServices
import Foundation
import Supabase
import UIKit

enum AppleRevocation {
    @TaskLocal static var pendingAuthorizationCode: String?

    struct DeletionIntent {
        let userID: UUID
        let accessToken: String
        let sessionID: UUID?

        init(userID: UUID, accessToken: String) {
            self.userID = userID
            self.accessToken = accessToken
            sessionID = AppleCredentialMonitor.sessionID(accessToken: accessToken)
        }

        init?(session: Session?) {
            guard let session else { return nil }
            self.init(userID: session.user.id, accessToken: session.accessToken)
        }

        func matches(_ current: DeletionIntent?) -> Bool {
            guard let current, userID == current.userID else { return false }
            if let sessionID { return sessionID == current.sessionID }
            // Legacy tokens cannot prove rotation belongs to the same login.
            return accessToken == current.accessToken
        }
    }

    struct DeletionResponse: Decodable {
        let ok: Bool
        let appleRevocation: String?

        var notice: String? {
            guard appleRevocation == "manual_required" else { return nil }
            return "Your account and reminder data were deleted. Apple access could not be revoked automatically. To finish, open Settings, tap your name, then Sign in with Apple, select Lazy Man’s Reminders, and tap Delete. Apple’s instructions: https://support.apple.com/102571"
        }
    }

    enum DeletionError: LocalizedError {
        case cancelled
        case invalidResponse
        case accountChanged

        var errorDescription: String? {
            switch self {
            case .cancelled:
                "Account deletion was cancelled. Your account has not been deleted."
            case .accountChanged:
                "Your signed-in account changed. No account was deleted. Review the current account and confirm deletion again."
            case .invalidResponse:
                "The server did not confirm account deletion. Please try again."
            }
        }
    }

    static var invokeOptions: FunctionInvokeOptions {
        guard let pendingAuthorizationCode, !pendingAuthorizationCode.isEmpty else {
            return FunctionInvokeOptions()
        }
        return FunctionInvokeOptions(body: requestBody(authorizationCode: pendingAuthorizationCode))
    }

    static func hasAppleIdentity(providers: [String]) -> Bool {
        providers.contains { $0.compare("apple", options: .caseInsensitive) == .orderedSame }
    }

    static func requestBody(authorizationCode: String) -> [String: String] {
        ["appleAuthorizationCode": authorizationCode]
    }

    @MainActor
    static func deleteAccount(using auth: AuthManager) async throws {
        let visibleSession = auth.session
        try await performDeletion(
            intendedIdentity: DeletionIntent(session: visibleSession),
            providers: visibleSession?.user.identities?.map(\.provider) ?? [],
            authorize: { try await requestAuthorizationCode() },
            delete: { try await auth.deleteAccount(expected: $0) }
        )
    }

    @MainActor
    static func performDeletion(
        intendedIdentity: DeletionIntent?,
        providers: [String],
        authorize: () async throws -> String?,
        delete: (DeletionIntent) async throws -> Void
    ) async throws {
        guard let intendedIdentity else { throw DeletionError.accountChanged }
        let code: String?
        if hasAppleIdentity(providers: providers) {
            code = try await authorize()
        } else {
            code = nil
        }
        guard let code else {
            try await delete(intendedIdentity)
            return
        }
        try await $pendingAuthorizationCode.withValue(code) {
            try await delete(intendedIdentity)
        }
    }

    @MainActor
    static func withValidatedDeletion(
        expected: DeletionIntent,
        gate: AuthSessionGate,
        currentIdentity: () -> DeletionIntent?,
        operation: () async throws -> Void
    ) async throws {
        try await gate.withLock {
            guard expected.matches(currentIdentity()) else { throw DeletionError.accountChanged }
            try await operation()
        }
    }

    @MainActor
    static func requestAuthorizationCode() async throws -> String? {
        try await AppleAuthorizationCodeController().run()
    }
}

@MainActor
private final class AppleAuthorizationCodeController: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<String?, Error>?
    private var controller: ASAuthorizationController?

    func run() async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first { $0.isKeyWindow } ?? windows.first ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let data = credential.authorizationCode,
            let code = String(data: data, encoding: .utf8)
        else {
            finish(nil)
            return
        }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        finish(trimmed.isEmpty ? nil : trimmed)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let error = error as? ASAuthorizationError, error.code == .canceled {
            finish(nil, error: AppleRevocation.DeletionError.cancelled)
        } else {
            // Unavailable Apple credentials must not prevent deletion of app data.
            finish(nil)
        }
    }

    private func finish(_ code: String?, error: Error? = nil) {
        guard let continuation else { return }
        self.continuation = nil
        controller = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume(returning: code)
        }
    }
}
