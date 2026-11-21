import XCTest
@testable import LazyMansReminders

final class SignInErrorAnnouncementPolicyTests: XCTestCase {
    func testNewErrorUsesExactExistingText() {
        var policy = SignInErrorAnnouncementPolicy()
        XCTAssertEqual(policy.announcement(for: .error("Couldn’t sign in.")), "Couldn’t sign in.")
    }

    func testRepeatedErrorIsNotAnnouncedAgain() {
        var policy = SignInErrorAnnouncementPolicy()
        _ = policy.announcement(for: .error("Couldn’t sign in."))
        XCTAssertNil(policy.announcement(for: .error("Couldn’t sign in.")))
    }

    func testChangedErrorIsAnnounced() {
        var policy = SignInErrorAnnouncementPolicy()
        _ = policy.announcement(for: .error("Couldn’t sign in."))
        XCTAssertEqual(policy.announcement(for: .error("Enter a valid email address.")), "Enter a valid email address.")
    }

    func testClearingAllowsSameErrorToReappear() {
        var policy = SignInErrorAnnouncementPolicy()
        _ = policy.announcement(for: .error("Couldn’t sign in."))
        XCTAssertNil(policy.announcement(for: nil))
        XCTAssertEqual(policy.announcement(for: .error("Couldn’t sign in.")), "Couldn’t sign in.")
    }

    func testInboxResetsErrorPresentationWithoutErrorAnnouncement() {
        var policy = SignInErrorAnnouncementPolicy()
        _ = policy.announcement(for: .error("Couldn’t sign in."))
        XCTAssertNil(policy.announcement(for: .checkInbox(email: "you@example.com")))
        XCTAssertEqual(policy.announcement(for: .error("Couldn’t sign in.")), "Couldn’t sign in.")
    }
}
