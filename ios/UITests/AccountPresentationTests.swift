import XCTest

final class AccountPresentationTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDefaultAccountPresentation() throws {
        try verifyAccount(size: "default")
    }

    func testXXXLAccountPresentation() throws {
        try verifyAccount(size: "XXXL")
    }

    private func verifyAccount(size: String) throws {
        for style in ["light", "dark"] {
            app.launchArguments = ["--hillclimb-demo", "account", "--hillclimb-style", style,
                                   "--hillclimb-size", size]
            app.launch()
            let bar = app.navigationBars["Account"]
            XCTAssertTrue(bar.waitForExistence(timeout: 10))
            let done = bar.buttons["Done"]
            XCTAssertTrue(done.isEnabled)
            XCTAssertGreaterThanOrEqual(done.frame.width, 44)
            XCTAssertGreaterThanOrEqual(done.frame.height, 44)
            XCTAssertGreaterThanOrEqual(done.frame.minY, 62)
            XCTAssertLessThanOrEqual(done.frame.maxX, app.frame.maxX)
            let allow = app.buttons["Allow Notifications"]
            XCTAssertTrue(allow.exists)
            XCTAssertFalse(allow.isEnabled)
            XCTAssertGreaterThanOrEqual(allow.frame.height, 44)
            XCTAssertGreaterThanOrEqual(allow.frame.minY, bar.frame.maxY)
            let list = app.collectionViews.firstMatch
            XCTAssertTrue(list.exists)
            // Drag the actual sheet grabber, rather than changing its presentation state.
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: app.frame.midX, dy: bar.frame.minY - 12))
            start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: app.frame.midX, dy: 80)))
            XCTAssertLessThan(bar.frame.minY, 160, "Large detent was not reached")
            let actions = ["Refresh Board Now", "Open App Settings", "Add a lasting widget", "Sign Out",
                           "Privacy", "Terms", "Support", "Download My Data", "Send Feedback", "Delete Account…"]
            for title in actions {
                let element = list.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
                for _ in 0..<10 {
                    if element.exists && element.frame.minY >= bar.frame.maxY && element.frame.maxY < app.frame.maxY - 34 { break }
                    list.swipeUp(velocity: .slow)
                }
                XCTAssertTrue(element.exists, "Missing \(title)")
                XCTAssertFalse(element.isEnabled, "Demo action enabled: \(title)")
                XCTAssertGreaterThanOrEqual(element.frame.minY, bar.frame.maxY, title)
                XCTAssertLessThanOrEqual(element.frame.maxY, app.frame.maxY - 34, title)
                XCTAssertGreaterThanOrEqual(element.frame.height, 44, title)
                XCTAssertGreaterThanOrEqual(element.frame.minX, app.frame.minX, title)
                XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX, title)
            }
            let footer = app.staticTexts["Deletes reminders, device registrations, lock-screen prefs, agent access, and this sign-in."]
            list.swipeUp(velocity: .slow)
            XCTAssertTrue(footer.exists)
            XCTAssertGreaterThan(footer.frame.height, size == "XXXL" ? 50 : 25)
            XCTAssertLessThanOrEqual(footer.frame.maxY, app.frame.maxY - 34)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "account-\(style)-\(size)-lower"
            attachment.lifetime = .keepAlways
            add(attachment)
            done.tap()
            XCTAssertFalse(bar.waitForExistence(timeout: 1), "Done failed to dismiss")
            XCTAssertTrue(app.buttons["Account"].exists)
            app.terminate()
        }
    }
}
