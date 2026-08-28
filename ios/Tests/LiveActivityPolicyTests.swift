import XCTest
@testable import LazyMansReminders

final class LiveActivityPolicyTests: XCTestCase {
    func testStaysHiddenWhenTheBoardIsEmpty() {
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 0, activityExists: false), .none)
    }

    func testEndsWhenTheLastReminderGoesAway() {
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 0, activityExists: true), .end)
    }

    func testUpdatesWhileRemindersRemain() {
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 3, activityExists: true), .update)
    }

    func testStartsWhenRemindersExistAndTheBannerIsGone() {
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 1, activityExists: false), .start)
    }
}
