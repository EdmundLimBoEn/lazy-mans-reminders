import AuthenticationServices
import Foundation
import Supabase

@MainActor
final class AppleCredentialMonitor {
    struct Identity: Equatable {
        let userID: UUID
        let identityID: UUID
        let subject: String
        let signedInAt: Date?

        static func from(user: User?) -> Identity? {
            guard let user else { return nil }
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

    func update(user: User?) {
        let next = Identity.from(user: user)
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

    func isCurrent(_ check: VerifiedRevocation, user: User?) -> Bool {
        check.revision == revision && check.identity == identity
            && check.identity == Identity.from(user: user)
    }
}
