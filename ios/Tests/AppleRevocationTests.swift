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
}
