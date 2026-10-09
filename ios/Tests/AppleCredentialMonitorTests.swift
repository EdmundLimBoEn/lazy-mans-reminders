import AuthenticationServices
import Supabase
import XCTest
@testable import LazyMansReminders

@MainActor
final class AppleCredentialMonitorTests: XCTestCase {
    private let sessionID = UUID()
    private func user(id: UUID = UUID(), provider: String = "apple",
                      subject: AnyJSON? = .string("apple-subject"),
                      identityID: UUID = UUID()) -> User {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        return User(id: id, appMetadata: [:], userMetadata: [:], aud: "authenticated",
                    createdAt: now, updatedAt: now,
                    identities: [UserIdentity(id: "provider-id", identityId: identityID,
                                              userId: id, identityData: subject.map { ["sub": $0] } ?? [:],
                                              provider: provider, createdAt: now,
                                              lastSignInAt: now, updatedAt: now)])
    }

    func testDecodesSupabaseAppleSubjectAsJSONstring() throws {
        let accountID = UUID()
        let payload = """
        {"id":"provider-id","identity_id":"\(UUID().uuidString)",
         "user_id":"\(accountID.uuidString)","provider":"apple",
         "identity_data":{"sub":"opaque-apple-sub"}}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let identity = try decoder.decode(UserIdentity.self, from: payload)
        var account = user(id: accountID)
        account.identities = [identity]
        XCTAssertEqual(AppleCredentialMonitor.Identity.from(user: account, sessionID: sessionID)?.subject, "opaque-apple-sub")
    }

    func testVerifiedRevokedAndNotFoundPermitCurrentAccountCleanup() async throws {
        for state in [ASAuthorizationAppleIDProvider.CredentialState.revoked, .notFound] {
            var queried: [String] = []
            let monitor = AppleCredentialMonitor { subject in
                queried.append(subject)
                return state
            }
            let account = user()
            monitor.update(user: account, sessionID: sessionID)
            let result = await monitor.verifiedRevocation()
            let check = try XCTUnwrap(result)
            XCTAssertTrue(monitor.isCurrent(check, user: account, sessionID: sessionID))
            XCTAssertEqual(queried, ["apple-subject"])
        }
    }

    func testAuthorizedAndTransferredPreserveSession() async {
        for state in [ASAuthorizationAppleIDProvider.CredentialState.authorized, .transferred] {
            let monitor = AppleCredentialMonitor { _ in state }
            monitor.update(user: user(), sessionID: sessionID)
            let result = await monitor.verifiedRevocation()
            XCTAssertNil(result)
        }
    }

    func testTransientErrorPreservesSessionAndAllowsRetry() async {
        var attempts = 0
        let monitor = AppleCredentialMonitor { _ in
            attempts += 1
            if attempts == 1 { throw URLError(.notConnectedToInternet) }
            return .revoked
        }
        monitor.update(user: user(), sessionID: sessionID)
        let first = await monitor.verifiedRevocation()
        let retry = await monitor.verifiedRevocation()
        XCTAssertNil(first)
        XCTAssertNotNil(retry)
        XCTAssertEqual(attempts, 2)
    }

    func testNonAppleMissingAndMalformedSubjectsNeverQueryApple() async {
        var calls = 0
        let monitor = AppleCredentialMonitor { _ in
            calls += 1
            return .revoked
        }
        let accounts: [User?] = [nil, user(provider: "email"), user(provider: "google"),
                                 user(subject: nil), user(subject: .integer(42)),
                                 user(subject: .string("  "))]
        for account in accounts {
            monitor.update(user: account, sessionID: sessionID)
            let result = await monitor.verifiedRevocation()
            XCTAssertNil(result)
        }
        XCTAssertEqual(calls, 0)
    }

    func testAppleAmongLinkedIdentitiesUsesSubjectRatherThanSupabaseIDs() async {
        var account = user(provider: "email")
        account.identities?.append(contentsOf: user(id: account.id, subject: .string("opaque-apple-sub")).identities!)
        var queried: String?
        let monitor = AppleCredentialMonitor { subject in
            queried = subject
            return .authorized
        }
        monitor.update(user: account, sessionID: sessionID, loginProvider: "apple")
        _ = await monitor.verifiedRevocation()
        XCTAssertEqual(queried, "opaque-apple-sub")
    }

    func testLinkedGoogleEmailAndAmbiguousRestorationPreserveAlternateLogin() async {
        var account = user()
        account.identities?.append(contentsOf: user(id: account.id, provider: "google").identities!)
        account.identities?.append(contentsOf: user(id: account.id, provider: "email").identities!)
        // Original-signup metadata and identity timestamps deliberately still favor Apple.
        account.appMetadata["provider"] = .string("apple")
        var calls = 0
        let monitor = AppleCredentialMonitor { _ in calls += 1; return .notFound }
        for provider in ["google", "email", nil] as [String?] {
            monitor.update(user: account, sessionID: sessionID, loginProvider: provider)
            let result = await monitor.verifiedRevocation()
            XCTAssertNil(result)
        }
        XCTAssertEqual(calls, 0)
        monitor.update(user: account, sessionID: sessionID, loginProvider: "apple")
        let appleResult = await monitor.verifiedRevocation()
        XCTAssertNotNil(appleResult)
    }

    func testAppleResultInvalidatedByAlternateLoginOnSameLinkedAccount() async throws {
        var account = user()
        account.identities?.append(contentsOf: user(id: account.id, provider: "google").identities!)
        let monitor = AppleCredentialMonitor { _ in .revoked }
        monitor.update(user: account, sessionID: sessionID, loginProvider: "apple")
        let result = await monitor.verifiedRevocation()
        let check = try XCTUnwrap(result)
        XCTAssertTrue(monitor.isCurrent(check, user: account, sessionID: sessionID, loginProvider: "apple"))
        monitor.update(user: account, sessionID: sessionID, loginProvider: "google")
        XCTAssertFalse(monitor.isCurrent(check, user: account, sessionID: sessionID, loginProvider: "google"))
    }

    func testKnownProviderContextSurvivesRotationButNotAnotherSession() throws {
        func token(_ sessionID: UUID) throws -> String {
            let data = try JSONSerialization.data(withJSONObject: ["session_id": sessionID.uuidString])
            let payload = data.base64EncodedString().replacingOccurrences(of: "=", with: "")
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            return "header.\(payload).signature"
        }
        let id = UUID()
        let context = try XCTUnwrap(AppleCredentialMonitor.LoginContext(accessToken: token(id), provider: "email"))
        XCTAssertEqual(context.provider(accessToken: try token(id)), "email")
        XCTAssertNil(context.provider(accessToken: try token(UUID())))
        XCTAssertNil(AppleCredentialMonitor.LoginContext(accessToken: "invalid", provider: "apple"))
        XCTAssertNil(AppleCredentialMonitor.sessionID(accessToken: "header.e30.signature"))
    }

    func testDelayedRevocationCannotClearSwitchedAccountOrReturningAccount() async {
        let original = user()
        for next in [user(), user(id: original.id), user(provider: "email"), nil] as [User?] {
            var continuation: CheckedContinuation<ASAuthorizationAppleIDProvider.CredentialState, Error>?
            var started: CheckedContinuation<Void, Never>?
            let monitor = AppleCredentialMonitor { _ in
                try await withCheckedThrowingContinuation { pending in
                    continuation = pending
                    started?.resume()
                }
            }
            monitor.update(user: original, sessionID: sessionID)
            let pending = Task { await monitor.verifiedRevocation() }
            await withCheckedContinuation { signal in
                if continuation != nil { signal.resume() } else { started = signal }
            }
            monitor.update(user: next, sessionID: sessionID)
            monitor.update(user: original, sessionID: sessionID)
            continuation?.resume(returning: .revoked)
            let result = await pending.value
            XCTAssertNil(result)
        }
    }

    func testVerifiedResultIsInvalidatedBeforeCleanupIfAccountChanges() async throws {
        let monitor = AppleCredentialMonitor { _ in .revoked }
        let original = user()
        monitor.update(user: original, sessionID: sessionID)
        let result = await monitor.verifiedRevocation()
        let check = try XCTUnwrap(result)
        XCTAssertFalse(monitor.isCurrent(check, user: user(), sessionID: sessionID))
        monitor.update(user: nil, sessionID: sessionID)
        monitor.update(user: original, sessionID: sessionID)
        XCTAssertFalse(monitor.isCurrent(check, user: original, sessionID: sessionID))
    }

    func testDelayedRevocationCannotClearReplacementSessionWithIdenticalUserMetadata() async {
        for signedInAt in [nil, Date(timeIntervalSince1970: 1_700_000_000)] as [Date?] {
            var account = user()
            account.lastSignInAt = signedInAt
            var continuation: CheckedContinuation<ASAuthorizationAppleIDProvider.CredentialState, Error>?
            var started: CheckedContinuation<Void, Never>?
            let monitor = AppleCredentialMonitor { _ in
                try await withCheckedThrowingContinuation { pending in
                    continuation = pending
                    started?.resume()
                }
            }
            monitor.update(user: account, sessionID: sessionID, loginProvider: "apple")
            let pending = Task { await monitor.verifiedRevocation() }
            await withCheckedContinuation { signal in
                if continuation != nil { signal.resume() } else { started = signal }
            }
            // Only the SDK session changes: user, subject, identity and timestamp are identical.
            monitor.update(user: account, sessionID: UUID(), loginProvider: "apple")
            continuation?.resume(returning: .revoked)
            let result = await pending.value
            XCTAssertNil(result)
        }
    }

    func testVerifiedRevocationRejectsNewSDKSessionBeforePublishedUpdate() async throws {
        for signedInAt in [nil, Date(timeIntervalSince1970: 1_700_000_000)] as [Date?] {
            var account = user()
            account.lastSignInAt = signedInAt
            let monitor = AppleCredentialMonitor { _ in .notFound }
            monitor.update(user: account, sessionID: sessionID, loginProvider: "apple")
            let result = await monitor.verifiedRevocation()
            let check = try XCTUnwrap(result)
            // Cleanup checks the actual SDK session while holding the gate, even before didSet.
            XCTAssertFalse(monitor.isCurrent(check, user: account, sessionID: UUID(), loginProvider: "apple"))
            XCTAssertFalse(monitor.isCurrent(check, user: account, sessionID: nil, loginProvider: "apple"))
            XCTAssertTrue(monitor.isCurrent(check, user: account, sessionID: sessionID, loginProvider: "apple"))
        }
    }

    func testMissingSessionIDNeverQueriesAndInvalidatesExistingCheck() async throws {
        var calls = 0
        let account = user()
        let monitor = AppleCredentialMonitor { _ in calls += 1; return .revoked }
        monitor.update(user: account, sessionID: nil)
        let missing = await monitor.verifiedRevocation()
        XCTAssertNil(missing)
        XCTAssertEqual(calls, 0)
        monitor.update(user: account, sessionID: sessionID)
        let result = await monitor.verifiedRevocation()
        let check = try XCTUnwrap(result)
        monitor.update(user: account, sessionID: nil)
        monitor.update(user: account, sessionID: sessionID)
        XCTAssertFalse(monitor.isCurrent(check, user: account, sessionID: sessionID))
    }

    func testTokenRotationWithSameSessionIDKeepsCheckValid() async throws {
        let payload = try JSONSerialization.data(withJSONObject: ["session_id": sessionID.uuidString])
            .base64EncodedString().replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        let firstToken = "header.\(payload).first-signature"
        let rotatedToken = "header.\(payload).rotated-signature"
        XCTAssertNotEqual(firstToken, rotatedToken)
        let monitor = AppleCredentialMonitor { _ in .notFound }
        let account = user()
        monitor.update(user: account, sessionID: AppleCredentialMonitor.sessionID(accessToken: firstToken))
        let result = await monitor.verifiedRevocation()
        let check = try XCTUnwrap(result)
        monitor.update(user: account, sessionID: AppleCredentialMonitor.sessionID(accessToken: rotatedToken))
        XCTAssertTrue(monitor.isCurrent(check, user: account,
                                        sessionID: AppleCredentialMonitor.sessionID(accessToken: rotatedToken)))
    }
}
