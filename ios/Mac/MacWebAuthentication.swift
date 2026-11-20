import AppKit
import AuthenticationServices

@MainActor
final class MacWebAuthentication: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let redirectURL = URL(string: "lazymansreminders://auth/callback")!
    private let window: NSWindow

    init(window: NSWindow) {
        self.window = window
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window
    }

    func open(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: Self.redirectURL.scheme
            ) { [self] callback, error in
                // The presentation context provider is weak. Keep it and its anchor alive.
                withExtendedLifetime(self) {
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let callback, NativeAuthCallback(url: callback) != nil {
                        continuation.resume(returning: callback)
                    } else {
                        continuation.resume(throwing: MacSessionError.invalidOAuthCallback)
                    }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: MacSessionError.couldNotOpenBrowser)
            }
        }
    }
}
