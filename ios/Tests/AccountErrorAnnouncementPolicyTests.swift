import XCTest
@testable import LazyMansReminders

final class AccountErrorAnnouncementPolicyTests: XCTestCase {
    private let error = "Couldn’t disconnect notifications. You’re still signed in. Reconnect and try signing out again before giving this iPhone to someone else."
    private let refresh = "Couldn’t refresh. Your saved board is still available."

    func testExactErrorAnnouncesOncePerPresentation() {
        var policy = AccountErrorAnnouncementPolicy()
        XCTAssertEqual(policy.announcement(for: error), error)
        XCTAssertNil(policy.announcement(for: error))
        XCTAssertNil(policy.announcement(for: nil))
        XCTAssertEqual(policy.announcement(for: error), error)
    }

    func testChangedMessageAndSuccessfulRefreshReset() {
        var policy = AccountErrorAnnouncementPolicy()
        XCTAssertEqual(policy.announcement(for: error), error)
        XCTAssertEqual(policy.announcement(for: refresh), refresh)
        XCTAssertNil(policy.announcement(for: refresh))
        XCTAssertEqual(policy.announcement(for: "Board refreshed."), "Board refreshed.")
        XCTAssertNil(policy.announcement(for: "Board refreshed."))
        XCTAssertEqual(policy.announcement(for: refresh), refresh)
    }

    func testClearingBeforeAnyFailureIsSilent() {
        var policy = AccountErrorAnnouncementPolicy()
        XCTAssertNil(policy.announcement(for: nil))
        XCTAssertNil(policy.announcement(for: nil))
        XCTAssertEqual(policy.announcement(for: refresh), refresh)
    }
}
