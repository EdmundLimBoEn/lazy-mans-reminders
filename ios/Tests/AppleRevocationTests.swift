import XCTest
@testable import LazyMansReminders

final class AppleRevocationTests: XCTestCase {
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
                providers: ["apple"],
                authorize: { throw AppleRevocation.DeletionError.cancelled },
                delete: { deleted = true }
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
            providers: ["apple"],
            authorize: { nil },
            delete: {
                XCTAssertNil(AppleRevocation.pendingAuthorizationCode)
                deleted = true
            }
        )
        XCTAssertTrue(deleted)
    }

    @MainActor
    func testAuthorizationCodeIsAvailableOnlyDuringDeletion() async throws {
        try await AppleRevocation.performDeletion(
            providers: ["apple"],
            authorize: { "fresh-code" },
            delete: { XCTAssertEqual(AppleRevocation.pendingAuthorizationCode, "fresh-code") }
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
            providers: ["email"],
            authorize: { XCTFail("Must not ask email users to authorize Apple"); return nil },
            delete: { deleted = true }
        )
        XCTAssertTrue(deleted)
    }
}
