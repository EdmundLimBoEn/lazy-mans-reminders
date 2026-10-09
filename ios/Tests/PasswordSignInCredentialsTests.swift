import XCTest
@testable import LazyMansReminders

final class PasswordSignInCredentialsTests: XCTestCase {
    func testTrimsEmailWithoutChangingPassword() throws {
        let credentials = try XCTUnwrap(PasswordSignInCredentials(
            email: "  person@example.com\n", password: "  a secret  "
        ))
        XCTAssertEqual(credentials.email, "person@example.com")
        XCTAssertEqual(credentials.password, "  a secret  ")
    }

    func testRejectsMissingCredentials() {
        XCTAssertNil(PasswordSignInCredentials(email: "", password: "secret"))
        XCTAssertNil(PasswordSignInCredentials(email: "person@", password: "secret"))
        XCTAssertNil(PasswordSignInCredentials(email: "person@example.com", password: ""))
    }

    func testDoesNotApplySignupPasswordRulesToExistingAccounts() {
        XCTAssertNotNil(PasswordSignInCredentials(email: "person@example.com", password: "x"))
        XCTAssertEqual(
            PasswordSignInCredentials(email: "person@example.com", password: " ")?.password,
            " "
        )
    }
}
