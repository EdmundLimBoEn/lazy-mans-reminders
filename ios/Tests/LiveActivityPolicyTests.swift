import XCTest
@testable import LazyMansReminders

final class LiveActivityPolicyTests: XCTestCase {
    func testSelectsNewReplacementOnBackgroundRelaunchRegardlessOfListOrder() {
        for ids in [["old", "replacement"], ["replacement", "old"]] {
            XCTAssertEqual(LiveActivityPolicy.selectedActivityID(
                currentIDs: ids, knownIDs: ["old"], previousSelection: "old"
            ), "replacement")
        }
    }

    func testKeepsAcknowledgedReplacementWhenOldActivityIsFirst() {
        XCTAssertEqual(LiveActivityPolicy.selectedActivityID(
            currentIDs: ["old", "replacement"], knownIDs: ["old", "replacement"],
            previousSelection: "replacement"
        ), "replacement")
    }

    func testMissingActivityDoesNotKeepAStaleSelection() {
        XCTAssertNil(LiveActivityPolicy.selectedActivityID(
            currentIDs: [], knownIDs: ["old"], previousSelection: "old"
        ))
    }

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
