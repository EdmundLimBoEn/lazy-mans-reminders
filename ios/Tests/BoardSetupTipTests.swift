import SwiftUI
import XCTest
@testable import LazyMansReminders

final class BoardSetupTipTests: XCTestCase {
    func testShowsOnLoadedEmptyBoardUntilDismissed() {
        XCTAssertTrue(BoardSetupTip.shouldShow(hasLoaded: true, isBoardEmpty: true, hasError: false, isDismissed: false))
        XCTAssertFalse(BoardSetupTip.shouldShow(hasLoaded: true, isBoardEmpty: true, hasError: false, isDismissed: true))
    }

    func testHiddenWhileLoadingOnErrorOrWithReminders() {
        XCTAssertFalse(BoardSetupTip.shouldShow(hasLoaded: false, isBoardEmpty: true, hasError: false, isDismissed: false))
        XCTAssertFalse(BoardSetupTip.shouldShow(hasLoaded: true, isBoardEmpty: true, hasError: true, isDismissed: false))
        XCTAssertFalse(BoardSetupTip.shouldShow(hasLoaded: true, isBoardEmpty: false, hasError: false, isDismissed: false))
    }

    func testOnlyOneCombinationShows() {
        var shown = 0
        for loaded in [false, true] {
            for empty in [false, true] {
                for error in [false, true] {
                    for dismissed in [false, true] where BoardSetupTip.shouldShow(
                        hasLoaded: loaded, isBoardEmpty: empty, hasError: error, isDismissed: dismissed
                    ) {
                        shown += 1
                    }
                }
            }
        }
        XCTAssertEqual(shown, 1)
    }

    @MainActor
    func testDismissalPersistsAcrossAppStorageInstances() throws {
        let suite = "BoardSetupTipTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = AppStorage(wrappedValue: false, BoardSetupTip.storageKey, store: defaults)
        XCTAssertFalse(first.wrappedValue)
        first.wrappedValue = true

        // A fresh wrapper (next launch) reads the stored dismissal.
        let relaunch = AppStorage(wrappedValue: false, BoardSetupTip.storageKey, store: defaults)
        XCTAssertTrue(relaunch.wrappedValue)
        XCTAssertTrue(defaults.bool(forKey: "boardSetupTipDismissed"))
    }

    func testStepsCoverWidgetLiveActivitiesAndNotifications() {
        let text = BoardSetupTip.steps.map(\.text).joined(separator: " ")
        XCTAssertTrue(text.contains("Lock Screen"))
        XCTAssertTrue(text.contains("Live Activities"))
        XCTAssertTrue(text.contains("notifications"))
    }
}
