import AuthenticationServices
import Foundation
import Supabase

@MainActor
final class AppleCredentialMonitor {
    struct LoginContext {
        let sessionID: UUID
        let provider: String

        init?(accessToken: String, provider: String) {
            guard let id = AppleCredentialMonitor.sessionID(accessToken: accessToken) else { return nil }
            sessionID = id
            self.provider = provider
        }

        func provider(accessToken: String) -> String? {
            AppleCredentialMonitor.sessionID(accessToken: accessToken) == sessionID ? provider : nil
        }
    }

    struct Identity: Equatable {
        let userID: UUID
        let identityID: UUID
        let subject: String
        let signedInAt: Date?

        static func from(user: User?, loginProvider: String? = nil) -> Identity? {
            guard let user else { return nil }
            if let loginProvider {
                guard loginProvider == "apple" else { return nil }
            } else {
                // Linked identity timestamps and app_metadata.provider do not identify
                // the current login. Preserve ambiguous restored alternate-provider sessions.
                guard !(user.identities ?? []).contains(where: { $0.provider.lowercased() != "apple" })
                else { return nil }
            }
            for identity in user.identities ?? [] {
                guard identity.provider.lowercased() == "apple",
                      identity.userId == user.id,
                      let subject = identity.identityData?["sub"]?.stringValue,
                      !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }
                return Identity(userID: user.id, identityID: identity.identityId,
                                subject: subject, signedInAt: user.lastSignInAt)
            }
            return nil
        }
    }

    struct VerifiedRevocation {
        fileprivate let identity: Identity
        fileprivate let revision: UUID
    }

    typealias Query = (String) async throws -> ASAuthorizationAppleIDProvider.CredentialState
    private let query: Query
    private var identity: Identity?
    private var revision = UUID()

    init(query: @escaping Query = { subject in
        try await withCheckedThrowingContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: subject) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }) {
        self.query = query
    }

    func update(user: User?, loginProvider: String? = nil) {
        let next = Identity.from(user: user, loginProvider: loginProvider)
        guard next != identity else { return }
        identity = next
        // A -> B -> A must also invalidate an outstanding callback for A.
        revision = UUID()
    }

    func verifiedRevocation() async -> VerifiedRevocation? {
        guard let identity else { return nil }
        let check = VerifiedRevocation(identity: identity, revision: revision)
        do {
            let state = try await query(identity.subject)
            guard state == .revoked || state == .notFound,
                  check.revision == revision, check.identity == self.identity
            else { return nil }
            return check
        } catch {
            // Retry on the next foreground/notification; offline is not revoked.
            return nil
        }
    }

    func isCurrent(_ check: VerifiedRevocation, user: User?, loginProvider: String? = nil) -> Bool {
        check.revision == revision && check.identity == identity
            && check.identity == Identity.from(user: user, loginProvider: loginProvider)
    }

    nonisolated static func sessionID(accessToken: String) -> UUID? {
        let parts = accessToken.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["session_id"] as? String else { return nil }
        return UUID(uuidString: value)
    }
}
