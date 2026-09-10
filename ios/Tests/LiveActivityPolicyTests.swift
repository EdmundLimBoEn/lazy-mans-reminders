import ActivityKit
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

    func testOnlyActiveAndStaleActivitiesCanBeUpdated() {
        XCTAssertTrue(LiveActivityPolicy.canUpdate(.active))
        XCTAssertTrue(LiveActivityPolicy.canUpdate(.stale))
        XCTAssertFalse(LiveActivityPolicy.canUpdate(.ended))
        XCTAssertFalse(LiveActivityPolicy.canUpdate(.dismissed))
    }

    func testEndedActivityDoesNotPreventReplacement() {
        let states: [ActivityState] = [.ended, .dismissed]
        XCTAssertEqual(LiveActivityPolicy.action(
            lineCount: 2,
            activityExists: states.contains(where: LiveActivityPolicy.canUpdate)
        ), .start)
    }

    func testStaleReplacementPreventsAnotherStart() {
        let states: [ActivityState] = [.ended, .stale]
        XCTAssertEqual(LiveActivityPolicy.action(
            lineCount: 2,
            activityExists: states.contains(where: LiveActivityPolicy.canUpdate)
        ), .update)
    }
}
