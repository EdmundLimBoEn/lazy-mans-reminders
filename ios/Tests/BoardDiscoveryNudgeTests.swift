import SwiftUI
import XCTest
@testable import LazyMansReminders

final class BoardDiscoveryNudgeTests: XCTestCase {
    private func visit(
        setupDismissed: Bool = true,
        additions: Int = 0,
        webShown: Bool = false,
        webDismissed: Bool = false,
        agentShown: Bool = false,
        agentDismissed: Bool = false
    ) -> BoardNudgeVisit {
        BoardNudgeVisit(
            setupTipDismissed: setupDismissed,
            successfulAdditionCount: additions,
            webShown: webShown, webDismissed: webDismissed,
            agentShown: agentShown, agentDismissed: agentDismissed
        )
    }

    func testWebWaitsForAVisitAfterSetupDismissal() {
        let firstVisit = visit(setupDismissed: false)
        XCTAssertNil(firstVisit.candidate)
        // Even after the setup card disappears, this visit cannot gain a nudge.
        let idle = BoardNudgeVisit.Visibility(hasLoaded: true, isBoardEmpty: true)
        XCTAssertFalse(firstVisit.shouldShow(idle, isDismissed: false))
        let laterVisit = visit(setupDismissed: true)
        XCTAssertEqual(laterVisit.candidate, .web)
        XCTAssertTrue(laterVisit.shouldShow(idle, isDismissed: false))
    }

    func testWebRequiresSuccessfulEmptyLoad() {
        let web = visit()
        XCTAssertFalse(web.shouldShow(.init(isBoardEmpty: true), isDismissed: false))
        XCTAssertFalse(web.shouldShow(.init(hasLoaded: true), isDismissed: false))
        XCTAssertTrue(web.shouldShow(.init(hasLoaded: true, isBoardEmpty: true), isDismissed: false))
    }

    func testExistingBoardContentsDoNotCountAsAnAddition() {
        let existingBoard = visit(setupDismissed: false, additions: 0)
        XCTAssertNil(existingBoard.candidate)
        XCTAssertFalse(existingBoard.shouldShow(.init(hasLoaded: true), isDismissed: false))
    }

    func testConfirmedAdditionUnlocksAgentOnLaterVisitEvenIfBoardIsEmptyAgain() {
        let beforeAddition = visit(setupDismissed: false)
        XCTAssertNil(beforeAddition.candidate)
        let afterAddition = visit(additions: 1)
        XCTAssertEqual(afterAddition.candidate, .agent)
        for empty in [false, true] {
            XCTAssertTrue(afterAddition.shouldShow(
                .init(hasLoaded: true, isBoardEmpty: empty), isDismissed: false
            ))
        }
    }

    func testEveryBusyStateHidesBothNudges() {
        let blockers: [(String, (inout BoardNudgeVisit.Visibility) -> Void)] = [
            ("not loaded", { $0.hasLoaded = false }),
            ("loading or refreshing", { $0.isLoading = true }),
            ("error", { $0.hasError = true }),
            ("editing or mutation", { $0.isEditing = true }),
            ("keyboard", { $0.isKeyboardVisible = true }),
            ("consent", { $0.isPresentingConsent = true }),
            ("account sheet", { $0.isAccountPresented = true }),
            ("inactive", { $0.isActive = false }),
            ("setup tip", { $0.isShowingSetupTip = true }),
        ]
        for nudgeVisit in [visit(), visit(additions: 1)] {
            let idle = BoardNudgeVisit.Visibility(hasLoaded: true, isBoardEmpty: true)
            XCTAssertTrue(nudgeVisit.shouldShow(idle, isDismissed: false))
            for (reason, block) in blockers {
                var visibility = idle
                block(&visibility)
                XCTAssertFalse(nudgeVisit.shouldShow(visibility, isDismissed: false), reason)
            }
            XCTAssertFalse(nudgeVisit.shouldShow(idle, isDismissed: true))
        }
    }

    func testBothEligibleSelectsOnlyAgentAndDismissalCannotReplaceItWithWeb() {
        let bothEligible = visit(additions: 1)
        XCTAssertEqual(bothEligible.candidate, .agent)
        let idle = BoardNudgeVisit.Visibility(hasLoaded: true, isBoardEmpty: true)
        XCTAssertFalse(bothEligible.shouldShow(idle, isDismissed: true))
        XCTAssertEqual(bothEligible.candidate, .agent)
        // The other card may be considered only on another visit.
        XCTAssertEqual(visit(additions: 1, agentShown: true, agentDismissed: true).candidate, .web)
    }

    func testShownOrDismissedNudgesNeverReturnOnLaterVisits() {
        XCTAssertNil(visit(webShown: true).candidate)
        XCTAssertNil(visit(webDismissed: true).candidate)
        XCTAssertNil(visit(additions: 1, webShown: true, agentShown: true).candidate)
        XCTAssertNil(visit(additions: 1, webDismissed: true, agentDismissed: true).candidate)
        // Repeated successful additions do not reset history.
        XCTAssertNil(visit(additions: 100, webShown: true, agentShown: true).candidate)
    }

    @MainActor
    func testInstallationHistoryPersistsAcrossAppStorageInstances() throws {
        let suite = "BoardDiscoveryNudgeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let keys = BoardDiscoveryNudge.allCases.flatMap { [$0.shownKey, $0.dismissedKey] }
        XCTAssertEqual(Set(keys), Set([
            "boardWebNudgeShown", "boardWebNudgeDismissed",
            "boardAgentNudgeShown", "boardAgentNudgeDismissed",
        ]))
        for key in keys {
            let first = AppStorage(wrappedValue: false, key, store: defaults)
            XCTAssertFalse(first.wrappedValue)
            first.wrappedValue = true
            let relaunch = AppStorage(wrappedValue: false, key, store: defaults)
            XCTAssertTrue(relaunch.wrappedValue, key)
        }
        let relaunch = visit(
            additions: 1,
            webShown: defaults.bool(forKey: BoardDiscoveryNudge.web.shownKey),
            webDismissed: defaults.bool(forKey: BoardDiscoveryNudge.web.dismissedKey),
            agentShown: defaults.bool(forKey: BoardDiscoveryNudge.agent.shownKey),
            agentDismissed: defaults.bool(forKey: BoardDiscoveryNudge.agent.dismissedKey)
        )
        XCTAssertNil(relaunch.candidate)
    }

    @MainActor
    func testSuccessfulAdditionCountPersistsAndEligibilityIsSnapshotted() throws {
        let suite = "BoardDiscoveryNudgeCountTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = BoardDiscoveryNudge.successfulAdditionCountKey
        XCTAssertEqual(key, "boardNudgeSuccessfulAdditionCount")
        XCTAssertEqual(defaults.integer(forKey: key), 0)
        let beforeAddition = visit(setupDismissed: false, additions: defaults.integer(forKey: key))

        BoardDiscoveryNudge.recordSuccessfulAddition(in: defaults)
        XCTAssertNil(beforeAddition.candidate)
        let relaunch = AppStorage(wrappedValue: 0, key, store: defaults)
        XCTAssertEqual(relaunch.wrappedValue, 1)
        XCTAssertEqual(visit(additions: relaunch.wrappedValue).candidate, .agent)

        BoardDiscoveryNudge.recordSuccessfulAddition(in: defaults)
        XCTAssertEqual(defaults.integer(forKey: key), 2)
    }
}
