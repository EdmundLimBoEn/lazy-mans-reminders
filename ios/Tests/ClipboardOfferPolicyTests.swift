import SwiftUI
import XCTest
@testable import LazyMansReminders

final class ClipboardOfferPolicyTests: XCTestCase {
    private func shouldShow(
        hasStrings: Bool = true,
        changeCount: Int = 42,
        lastHandled: Int = -1,
        active: Bool = true,
        sessionReady: Bool = true,
        loaded: Bool = true,
        loading: Bool = false,
        error: Bool = false,
        full: Bool = false,
        busy: Bool = false
    ) -> Bool {
        ClipboardOfferPolicy.shouldShow(
            snapshot: .init(hasStrings: hasStrings, changeCount: changeCount),
            lastHandledChangeCount: lastHandled,
            isActive: active,
            isSessionReady: sessionReady,
            hasLoaded: loaded,
            isLoading: loading,
            hasError: error,
            isAtCapacity: full,
            isBusy: busy
        )
    }

    func testShowsNewTextOnSuccessfullyLoadedActiveBoard() {
        XCTAssertTrue(shouldShow())
        XCTAssertTrue(shouldShow(changeCount: 43, lastHandled: 42))
    }

    func testHidesEmptyUnchangedAndOlderPasteboards() {
        XCTAssertFalse(shouldShow(hasStrings: false))
        XCTAssertFalse(shouldShow(lastHandled: 42))
        XCTAssertFalse(shouldShow(lastHandled: 43))
    }

    func testHidesWhileLoadingFailedFullInactiveSignedOutOrBusy() {
        XCTAssertFalse(shouldShow(loaded: false))
        XCTAssertFalse(shouldShow(loading: true))
        XCTAssertFalse(shouldShow(error: true))
        XCTAssertFalse(shouldShow(full: true))
        XCTAssertFalse(shouldShow(active: false))
        XCTAssertFalse(shouldShow(sessionReady: false))
        XCTAssertFalse(shouldShow(busy: true))
    }

    func testBecomingFullHidesAnExistingOfferWithoutConsumingIt() {
        XCTAssertTrue(shouldShow())
        XCTAssertFalse(shouldShow(full: true))
        XCTAssertTrue(shouldShow(full: false))
    }

    func testTrimsDeliveredPayloadAndPreservesInternalNewlines() {
        XCTAssertEqual(ClipboardOfferPolicy.reminderText(from: [" \n Buy milk\nCall Mum \t"]), "Buy milk\nCall Mum")
        XCTAssertEqual(ClipboardOfferPolicy.reminderText(from: [" First ", "Second"]), "First")
    }

    func testRejectsEmptyAndWhitespaceOnlyDeliveredPayloads() {
        XCTAssertNil(ClipboardOfferPolicy.reminderText(from: []))
        XCTAssertNil(ClipboardOfferPolicy.reminderText(from: [""]))
        XCTAssertNil(ClipboardOfferPolicy.reminderText(from: [" \t\r\n\u{00a0}"]))
    }

    @MainActor
    func testDismissedAndAddedChangeCountsPersistAcrossLaunches() throws {
        let suite = "ClipboardOfferPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = AppStorage(wrappedValue: -1, ClipboardOfferPolicy.storageKey, store: defaults)
        XCTAssertTrue(shouldShow(lastHandled: first.wrappedValue))
        // Dismissal and all delivered-paste outcomes use the same persisted marker.
        for handled in [42, 43] {
            first.wrappedValue = handled
            let relaunch = AppStorage(wrappedValue: -1, ClipboardOfferPolicy.storageKey, store: defaults)
            XCTAssertEqual(relaunch.wrappedValue, handled)
            XCTAssertEqual(defaults.integer(forKey: ClipboardOfferPolicy.storageKey), handled)
            XCTAssertFalse(shouldShow(changeCount: handled, lastHandled: relaunch.wrappedValue))
            XCTAssertTrue(shouldShow(changeCount: handled + 1, lastHandled: relaunch.wrappedValue))
        }
    }
}
