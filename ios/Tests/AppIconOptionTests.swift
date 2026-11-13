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
    func testSelectionReadsSystemStateAndRestoresDefault() async {
        let client = FakeAppIconClient()
        client.alternateIconName = "AppIcon-Bold"
        let selection = AppIconSelection(client: client)
        XCTAssertEqual(selection.selected, .bold)
        await selection.select(.minimal)
        XCTAssertEqual(selection.selected, .minimal)
        await selection.select(.default)
        XCTAssertEqual(selection.selected, .default)
        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[0], "AppIcon-Minimal")
        XCTAssertNil(client.requests[1])
        XCTAssertFalse(selection.hasError)
        XCTAssertFalse(selection.isChanging)
    }

    @MainActor
    func testUnsupportedAndAlreadySelectedDoNotCallSystem() async {
        let client = FakeAppIconClient()
        let selection = AppIconSelection(client: client)
        await selection.select(.default)
        client.supportsAlternateIcons = false
        await selection.select(.bold)
        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertFalse(selection.supportsAlternateIcons)
        XCTAssertEqual(selection.selected, .default)
    }

    @MainActor
    func testFailurePreservesActualIconAndAllowsRetry() async {
        let client = FakeAppIconClient()
        let selection = AppIconSelection(client: client)
        client.shouldFail = true
        await selection.select(.bold)
        XCTAssertTrue(selection.hasError)
        XCTAssertFalse(selection.isChanging)
        XCTAssertEqual(selection.selected, .default)
        client.shouldFail = false
        await selection.select(.bold)
        XCTAssertFalse(selection.hasError)
        XCTAssertEqual(selection.selected, .bold)
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
    func testOverlappingSelectionsAreIgnoredUntilRequestCompletes() async {
        let client = FakeAppIconClient()
        let selection = AppIconSelection(client: client)
        client.duringChange = {
            XCTAssertTrue(selection.isChanging)
            XCTAssertEqual(selection.selected, .default)
            await selection.select(.minimal)
        }
        await selection.select(.bold)
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
    var requests: [String?] = []
    var duringChange: (@MainActor () async -> Void)?

    func setAlternateIconName(_ name: String?) async throws {
        requests.append(name)
        await duringChange?()
        if shouldFail { throw Failure.unavailable }
        alternateIconName = name
    }
}
