import XCTest
@testable import LazyMansReminders

final class AppleRevocationTests: XCTestCase {
    private func intent(userID: UUID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
                        sessionID: UUID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
                        suffix: String = "original") -> AppleRevocation.DeletionIntent {
        let payload = Data("{\"session_id\":\"\(sessionID)\"}".utf8).base64EncodedString()
        return .init(userID: userID, accessToken: "header.\(payload).\(suffix)")
    }

    func testDetectsAppleAmongLinkedIdentities() {
        XCTAssertTrue(AppleRevocation.hasAppleIdentity(providers: ["apple"]))
        XCTAssertTrue(AppleRevocation.hasAppleIdentity(providers: ["google", "Apple"]))
        XCTAssertFalse(AppleRevocation.hasAppleIdentity(providers: ["google", "email"]))
        XCTAssertFalse(AppleRevocation.hasAppleIdentity(providers: []))
    }

    func testDeleteAccountBodyUsesAuthorizationCodeKey() throws {
        let data = try JSONEncoder().encode(
            AppleRevocation.requestBody(authorizationCode: "auth-code-from-ios")
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(json, ["appleAuthorizationCode": "auth-code-from-ios"])
    }

    @MainActor
    func testCancellationDoesNotDeleteAccount() async {
        var deleted = false
        do {
            try await AppleRevocation.performDeletion(
                intendedIdentity: intent(),
                providers: ["apple"],
                authorize: { throw AppleRevocation.DeletionError.cancelled },
                delete: { _ in deleted = true }
            )
            XCTFail("Cancellation should stop deletion")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Account deletion was cancelled. Your account has not been deleted.")
        }
        XCTAssertFalse(deleted)
    }

    @MainActor
    func testUnavailableAppleCredentialsStillAllowDeletion() async throws {
        var deleted = false
        try await AppleRevocation.performDeletion(
            intendedIdentity: intent(),
            providers: ["apple"],
            authorize: { nil },
            delete: { _ in
                XCTAssertNil(AppleRevocation.pendingAuthorizationCode)
                deleted = true
            }
        )
        XCTAssertTrue(deleted)
    }

    @MainActor
    func testAuthorizationCodeIsAvailableOnlyDuringDeletion() async throws {
        try await AppleRevocation.performDeletion(
            intendedIdentity: intent(),
            providers: ["apple"],
            authorize: { "fresh-code" },
            delete: { _ in XCTAssertEqual(AppleRevocation.pendingAuthorizationCode, "fresh-code") }
        )
        XCTAssertNil(AppleRevocation.pendingAuthorizationCode)
    }

    func testFallbackNoticeAndLegacyResponseCompatibility() throws {
        let decoder = JSONDecoder()
        let fallback = try decoder.decode(
            AppleRevocation.DeletionResponse.self,
            from: Data(#"{"ok":true,"appleRevocation":"manual_required"}"#.utf8)
        )
        XCTAssertTrue(fallback.ok)
        XCTAssertTrue(try XCTUnwrap(fallback.notice).contains("were deleted"))
        XCTAssertTrue(try XCTUnwrap(fallback.notice).contains("https://support.apple.com/102571"))
        for json in [#"{"ok":true}"#, #"{"ok":true,"appleRevocation":"revoked"}"#] {
            let result = try decoder.decode(AppleRevocation.DeletionResponse.self, from: Data(json.utf8))
            XCTAssertTrue(result.ok)
            XCTAssertNil(result.notice)
        }
    }

    @MainActor
    func testNonAppleDeletionDoesNotRequestAppleAuthorization() async throws {
        var deleted = false
        try await AppleRevocation.performDeletion(
            intendedIdentity: intent(),
            providers: ["email"],
            authorize: { XCTFail("Must not ask email users to authorize Apple"); return nil },
            delete: { _ in deleted = true }
        )
        XCTAssertTrue(deleted)
    }

    @MainActor
    private func pausedDeletion(replacement: AppleRevocation.DeletionIntent?, code: String?,
                                shouldDelete: Bool) async {
        let intended = intent()
        var current: AppleRevocation.DeletionIntent? = intended
        let pause = AuthorizationPause()
        let gate = AuthSessionGate()
        var invocations = 0
        var cleanups = 0
        let task = Task { @MainActor in
            try await AppleRevocation.performDeletion(
                intendedIdentity: intended,
                providers: ["apple"],
                authorize: { await pause.authorize() },
                delete: { expected in
                    try await AppleRevocation.withValidatedDeletion(
                        expected: expected, gate: gate, currentIdentity: { current }
                    ) {
                        XCTAssertEqual(AppleRevocation.pendingAuthorizationCode, code)
                        invocations += 1
                        cleanups += 1
                    }
                }
            )
        }
        await pause.waitUntilStarted()
        // This must acquire while Apple UI is pending: the UI holds no session gate.
        await gate.withLock { current = replacement }
        pause.resume(code)
        do {
            try await task.value
            XCTAssertTrue(shouldDelete, "Stale intent must require confirmation again")
        } catch {
            XCTAssertFalse(shouldDelete)
            guard case AppleRevocation.DeletionError.accountChanged = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
        XCTAssertEqual(invocations, shouldDelete ? 1 : 0)
        XCTAssertEqual(cleanups, shouldDelete ? 1 : 0)
        XCTAssertNil(AppleRevocation.pendingAuthorizationCode)
    }

    @MainActor
    func testAccountChangeDuringAuthorizationNeverDeletesReplacement() async {
        let otherUser = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        for code in [nil, "code-for-A"] as [String?] {
            await pausedDeletion(replacement: intent(userID: otherUser), code: code, shouldDelete: false)
            await pausedDeletion(replacement: intent(sessionID: UUID()), code: code, shouldDelete: false)
            await pausedDeletion(replacement: nil, code: code, shouldDelete: false)
        }
    }

    @MainActor
    func testSameLoginTokenRotationAndUnavailableAppleCredentialsAllowIntendedDeletion() async {
        for code in [nil, "code-for-A"] as [String?] {
            await pausedDeletion(replacement: intent(suffix: "rotated"), code: code, shouldDelete: true)
        }
    }

    @MainActor
    func testMissingVisibleSessionDoesNotAuthorizeInvokeOrCleanUp() async {
        var authorized = false
        var deleted = false
        do {
            try await AppleRevocation.performDeletion(
                intendedIdentity: nil, providers: ["apple"],
                authorize: { authorized = true; return nil },
                delete: { _ in deleted = true }
            )
            XCTFail("Missing visible session must require confirmation again")
        } catch {
            guard case AppleRevocation.DeletionError.accountChanged = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
        XCTAssertFalse(authorized)
        XCTAssertFalse(deleted)
    }

    @MainActor
    func testLegacySessionRequiresExactTokenInsideGate() async {
        let expected = AppleRevocation.DeletionIntent(userID: intent().userID, accessToken: "legacy-token")
        let gate = AuthSessionGate()
        for token in ["legacy-token", "changed-token"] {
            var invoked = false
            do {
                try await AppleRevocation.withValidatedDeletion(
                    expected: expected, gate: gate,
                    currentIdentity: { .init(userID: expected.userID, accessToken: token) }
                ) { invoked = true }
                XCTAssertEqual(token, "legacy-token")
            } catch {
                XCTAssertEqual(token, "changed-token")
            }
            XCTAssertEqual(invoked, token == "legacy-token")
        }
    }
}

@MainActor
private final class AuthorizationPause {
    private var continuation: CheckedContinuation<String?, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func authorize() async -> String? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        guard continuation == nil else { return }
        await withCheckedContinuation { started = $0 }
    }

    func resume(_ code: String?) {
        let pending = continuation
        continuation = nil
        pending?.resume(returning: code)
    }
}
