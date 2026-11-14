import ActivityKit
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
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 0, activityExists: true), .end(.boardEmpty))
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(LiveActivityPolicy.EndReason.boardEmpty.dismissalDate(now: now), now.addingTimeInterval(3))
    }

    func testAccountCleanupEndsImmediatelyEvenIfTheCacheStillHasReminders() {
        for count in [0, 1] {
            XCTAssertEqual(
                LiveActivityPolicy.action(lineCount: count, activityExists: true, isClearing: true),
                .end(.clear)
            )
            XCTAssertEqual(
                LiveActivityPolicy.action(lineCount: count, activityExists: false, isClearing: true),
                .none
            )
        }
        XCTAssertNil(LiveActivityPolicy.EndReason.clear.dismissalDate(now: .now))
    }

    @MainActor
    func testControllerEndsWithClearMomentContentAndDelayedDismissal() {
        let now = Date(timeIntervalSince1970: 1_000)
        let ending = ReminderLiveActivityController.endPresentation(for: .boardEmpty, now: now)
        XCTAssertEqual(ending.content.state.lines, ["Nothing to do."])
        XCTAssertNil(ending.content.staleDate)
        XCTAssertEqual(ending.dismissalPolicy, .after(now.addingTimeInterval(3)))
    }

    @MainActor
    func testControllerAccountCleanupEndsImmediatelyWithoutClearMomentContent() {
        let ending = ReminderLiveActivityController.endPresentation(for: .clear, now: .now)
        XCTAssertTrue(ending.content.state.lines.isEmpty)
        XCTAssertNil(ending.content.staleDate)
        XCTAssertEqual(ending.dismissalPolicy, .immediate)
    }

    @MainActor
    func testRepeatedEmptySyncLeavesTheEndedClearFrameDeadlineAlone() {
        let clearFrame = ReminderActivityPresentation.finalState(for: .boardEmpty)
        XCTAssertFalse(ReminderLiveActivityController.shouldEndActivity(
            state: .ended, content: clearFrame, reason: .boardEmpty
        ))
        // Sign-out must remove even a clear frame that is waiting for dismissal.
        XCTAssertTrue(ReminderLiveActivityController.shouldEndActivity(
            state: .ended, content: clearFrame, reason: .clear
        ))
    }

    @MainActor
    func testClearMomentEndsActiveStaleAndPreviouslyEndedReminderBanners() {
        let content = ReminderAttributes.ContentState(lines: ["Milk"])
        for state in [ActivityState.active, .stale, .ended] {
            XCTAssertTrue(ReminderLiveActivityController.shouldEndActivity(
                state: state, content: content, reason: .boardEmpty
            ))
        }
        XCTAssertFalse(ReminderLiveActivityController.shouldEndActivity(
            state: .dismissed, content: content, reason: .boardEmpty
        ))
    }

    func testAddingAfterClearMomentCanStartOrUpdateWithoutARestartFlag() {
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 0, activityExists: true), .end(.boardEmpty))
        // Ended banners are excluded from the controller's active/stale inventory.
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 1, activityExists: false), .start)
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 1, activityExists: true), .update)
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 0, activityExists: false), .none)
    }

    func testUpdatesWhileRemindersRemain() {
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 3, activityExists: true), .update)
    }

    func testStartsWhenRemindersExistAndTheBannerIsGone() {
        XCTAssertEqual(LiveActivityPolicy.action(lineCount: 1, activityExists: false), .start)
    }
}
