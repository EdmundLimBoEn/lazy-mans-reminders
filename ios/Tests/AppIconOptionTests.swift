import UIKit
import XCTest
@testable import LazyMansReminders

final class AppIconOptionTests: XCTestCase {
    func testSystemNamesRoundTripAndDefaultUsesNil() {
        XCTAssertNil(AppIconOption.default.alternateIconName)
        XCTAssertEqual(AppIconOption.minimal.alternateIconName, "AppIcon-Minimal")
        XCTAssertEqual(AppIconOption.bold.alternateIconName, "AppIcon-Bold")
        for option in AppIconOption.allCases {
            XCTAssertEqual(AppIconOption(alternateIconName: option.alternateIconName), option)
        }
        XCTAssertNil(AppIconOption(alternateIconName: "UnknownIcon"))
    }

    @MainActor
    func testPreviewImagesLoadFromAppBundle() {
        let bundle = Bundle(for: AppIconSelection.self)
        for option in AppIconOption.allCases {
            XCTAssertNotNil(UIImage(named: option.previewImageName, in: bundle, compatibleWith: nil))
        }
    }

    @MainActor
    func testSelectionReadsSystemStateAndRestoresDefault() {
        let client = FakeAppIconClient()
        client.alternateIconName = "AppIcon-Bold"
        let selection = AppIconSelection(client: client)
        XCTAssertEqual(selection.selected, .bold)
        selection.select(.minimal)
        XCTAssertEqual(selection.selected, .minimal)
        selection.select(.default)
        XCTAssertEqual(selection.selected, .default)
        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[0], "AppIcon-Minimal")
        XCTAssertNil(client.requests[1])
        XCTAssertFalse(selection.hasError)
        XCTAssertFalse(selection.isChanging)
    }

    @MainActor
    func testUnsupportedAndAlreadySelectedDoNotCallSystem() {
        let client = FakeAppIconClient()
        let selection = AppIconSelection(client: client)
        selection.select(.default)
        client.supportsAlternateIcons = false
        selection.select(.bold)
        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertFalse(selection.supportsAlternateIcons)
        XCTAssertEqual(selection.selected, .default)
    }

    @MainActor
    func testFailurePreservesActualIconAndAllowsRetry() {
        let client = FakeAppIconClient()
        let selection = AppIconSelection(client: client)
        client.shouldFail = true
        selection.select(.bold)
        XCTAssertTrue(selection.hasError)
        XCTAssertFalse(selection.isChanging)
        XCTAssertEqual(selection.selected, .default)
        client.shouldFail = false
        selection.select(.bold)
        XCTAssertFalse(selection.hasError)
        XCTAssertEqual(selection.selected, .bold)
    }

    @MainActor
    func testAppliedIconWinsOverReportedErrorAndSelectionsKeepWorking() {
        let client = FakeAppIconClient()
        client.failAfterApplying = true
        let selection = AppIconSelection(client: client)

        for option in [AppIconOption.minimal, .bold, .default] {
            selection.select(option)
            XCTAssertEqual(selection.selected, option)
            XCTAssertFalse(selection.hasError)
            XCTAssertFalse(selection.isChanging)
        }
        XCTAssertEqual(client.requests, ["AppIcon-Minimal", "AppIcon-Bold", nil])
    }

    @MainActor
    func testRefreshFinishesAppliedChangesWithoutWaitingForCompletion() {
        let client = FakeAppIconClient()
        client.holdsCompletion = true
        let selection = AppIconSelection(client: client)

        for option in [AppIconOption.minimal, .bold, .default] {
            selection.select(option)
            XCTAssertTrue(selection.isChanging)
            selection.refresh()
            XCTAssertEqual(selection.selected, option)
            XCTAssertFalse(selection.isChanging)
            XCTAssertFalse(selection.hasError)
        }
        XCTAssertEqual(client.requests, ["AppIcon-Minimal", "AppIcon-Bold", nil])

        selection.select(.minimal)
        client.completions.removeFirst()(FakeAppIconClient.Failure.unavailable)
        XCTAssertTrue(selection.isChanging, "An old callback must not finish a new request for the same icon")
        XCTAssertFalse(selection.hasError)
        client.completions.removeLast()(nil)
        XCTAssertEqual(selection.selected, .minimal)
        XCTAssertFalse(selection.isChanging)
    }

    @MainActor
    func testRefreshDoesNotUnlockAnUnappliedRequest() {
        let client = FakeAppIconClient()
        client.holdsCompletion = true
        client.skipsApplying = true
        let selection = AppIconSelection(client: client)

        selection.select(.minimal)
        selection.refresh()
        selection.select(.bold)
        XCTAssertTrue(selection.isChanging)
        XCTAssertEqual(selection.selected, .default)
        XCTAssertEqual(client.requests.count, 1)

        client.completions.removeFirst()(FakeAppIconClient.Failure.unavailable)
        XCTAssertFalse(selection.isChanging)
        XCTAssertTrue(selection.hasError)
        client.holdsCompletion = false
        client.skipsApplying = false
        selection.select(.bold)
        XCTAssertEqual(selection.selected, .bold)
        XCTAssertFalse(selection.hasError)
    }

    @MainActor
    func testCompletionWithoutApplyingIconDoesNotClaimSuccess() {
        let client = FakeAppIconClient()
        client.skipsApplying = true
        let selection = AppIconSelection(client: client)

        selection.select(.minimal)
        XCTAssertEqual(selection.selected, .default)
        XCTAssertTrue(selection.hasError)
        XCTAssertFalse(selection.isChanging)
    }

    @MainActor
    func testRefreshReflectsExternalChangeIncludingUnknownIcon() {
        let client = FakeAppIconClient()
        let selection = AppIconSelection(client: client)
        client.alternateIconName = "AppIcon-Minimal"
        selection.refresh()
        XCTAssertEqual(selection.selected, .minimal)
        client.alternateIconName = "UnknownIcon"
        selection.refresh()
        XCTAssertNil(selection.selected)
    }

    @MainActor
    func testOverlappingSelectionsAreIgnoredUntilRequestCompletes() {
        let client = FakeAppIconClient()
        let selection = AppIconSelection(client: client)
        client.duringChange = {
            XCTAssertTrue(selection.isChanging)
            XCTAssertEqual(selection.selected, .default)
            selection.select(.minimal)
        }
        selection.select(.bold)
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(selection.selected, .bold)
        XCTAssertFalse(selection.isChanging)
    }
}

@MainActor
private final class FakeAppIconClient: AppIconClient {
    enum Failure: Error { case unavailable }

    var alternateIconName: String?
    var supportsAlternateIcons = true
    var shouldFail = false
    var failAfterApplying = false
    var requests: [String?] = []
    var duringChange: (@MainActor () -> Void)?

    var holdsCompletion = false
    var skipsApplying = false
    var completions: [@MainActor (Error?) -> Void] = []

    func changeIcon(to name: String?, completion: @escaping @MainActor (Error?) -> Void) {
        requests.append(name)
        duringChange?()
        if !shouldFail && !skipsApplying { alternateIconName = name }
        if holdsCompletion {
            completions.append(completion)
        } else {
            completion(shouldFail || failAfterApplying ? Failure.unavailable : nil)
        }
    }
}
