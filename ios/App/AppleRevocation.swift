import AuthenticationServices
import Foundation
import Supabase
import UIKit

enum AppleRevocation {
    @TaskLocal static var pendingAuthorizationCode: String?

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
        let providers = auth.session?.user.identities?.map(\.provider) ?? []
        let code: String?
        if hasAppleIdentity(providers) {
            code = await requestAuthorizationCode()
        } else {
            code = nil
        }
        guard let code else {
            try await auth.deleteAccount()
            return
        }
        try await $pendingAuthorizationCode.withValue(code) {
            try await auth.deleteAccount()
        }
    }

    @MainActor
    static func requestAuthorizationCode() async -> String? {
        await AppleAuthorizationCodeController().run()
    }
}

@MainActor
private final class AppleAuthorizationCodeController: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<String?, Never>?
    private var controller: ASAuthorizationController?

    func run() async -> String? {
        await withCheckedContinuation { continuation in
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

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError _: Error) {
        finish(nil)
    }

    private func finish(_ code: String?) {
        guard let continuation else { return }
        self.continuation = nil
        controller = nil
        continuation.resume(returning: code)
    }
}
