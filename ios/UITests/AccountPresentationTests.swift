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
            XCTAssertLessThan(bar.frame.minY, 160, "Account must open at large")
            let done = bar.buttons["Done"]
            XCTAssertTrue(done.isEnabled)
            XCTAssertGreaterThanOrEqual(done.frame.width, 44)
            XCTAssertGreaterThanOrEqual(done.frame.height, 44)
            XCTAssertGreaterThanOrEqual(done.frame.minY, 62)
            XCTAssertLessThanOrEqual(done.frame.maxX, app.frame.maxX)
            let grabber = app.buttons["Sheet Grabber"]
            let origin = app.coordinate(withNormalizedOffset: .zero)
            grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: 446)))
            XCTAssertGreaterThan(bar.frame.minY, 400, "Medium detent was not reached")
            let allow = app.buttons["Allow Notifications"]
            XCTAssertTrue(allow.exists)
            XCTAssertFalse(allow.isEnabled)
            XCTAssertGreaterThanOrEqual(allow.frame.height, 44)
            XCTAssertGreaterThanOrEqual(allow.frame.minY, bar.frame.maxY)
            let list = app.collectionViews["account.settings"]
            XCTAssertTrue(list.exists)
            grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: 80)))
            XCTAssertLessThan(bar.frame.minY, 160, "Large detent was not reached")
            let actions = ["Refresh Board Now", "Open App Settings", "Add a lasting widget", "Sign Out",
                           "Privacy", "Terms", "Support", "Download My Data", "Send Feedback", "Delete Account…"]
            for title in actions {
                let element = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND (elementType == %d OR elementType == %d)", title, XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.link.rawValue)).firstMatch
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
            app.buttons["Account"].tap()
            XCTAssertTrue(bar.waitForExistence(timeout: 5))
            XCTAssertLessThan(bar.frame.minY, 160, "Reopened Account must select large")
            done.tap()
            app.terminate()
        }
    }
}

extension AccountPresentationTests {
    func testEnabledAccountTypographyAndAlignment() throws {
        for size in ["default", "XXXL"] {
            for style in ["light", "dark"] {
                launchEnabled(style: style, size: size)
                let list = app.collectionViews["account.settings"]
                let disclosure = app.buttons["Add a lasting widget"]
                if !disclosure.isHittable { list.swipeUp(velocity: .slow) }
                let before = try accountFrames()
                let refresh = try XCTUnwrap(before["refresh.title"])
                let widget = try XCTUnwrap(before["disclosure.title"])
                XCTAssertEqual(refresh[3], widget[3], accuracy: 1, "Sibling body text must have equal actual height")
                XCTAssertTrue(disclosure.isEnabled)
                disclosure.tap()
                let home = app.staticTexts["Home Screen: touch and hold an empty area, choose Edit → Add Widget, then Notepad → Board."]
                XCTAssertTrue(home.waitForExistence(timeout: 3))
                for _ in 0..<6 {
                    if app.buttons["Delete Account…"].isHittable { break }
                    list.swipeUp(velocity: .slow)
                }
                list.swipeUp(velocity: .slow)
                let frames = try accountFrames()
                let delete = try XCTUnwrap(frames["Delete Account….title"])
                let feedback = try XCTUnwrap(frames["Send Feedback.title"])
                XCTAssertEqual(delete[0], feedback[0], accuracy: 0.5)
                XCTAssertEqual(try XCTUnwrap(frames["Delete Account….icon"])[2], 24, accuracy: 0.5)
                XCTAssertEqual(delete[0] - (try XCTUnwrap(frames["Delete Account….icon"])[0] + 24), 14, accuracy: 0.5)
                let footer = app.staticTexts["Deletes reminders, device registrations, lock-screen prefs, agent access, and this sign-in."]
                XCTAssertTrue(footer.isHittable)
                XCTAssertLessThanOrEqual(footer.frame.maxY, app.frame.maxY - 34)
                app.buttons["Delete Account…"].tap()
                XCTAssertFalse(app.alerts["Delete Account?"].exists)
                app.navigationBars["Account"].buttons["Done"].tap()
                app.terminate()
            }
        }
    }

    func testSafeAccountErrorsClearAndReappear() throws {
        for state in ["error", "refresh-error"] {
            launchEnabled(style: "light", size: "XXXL", state: state)
            let id = state == "error" ? "account.error" : "account.refreshResult"
            let message = app.staticTexts[id]
            XCTAssertTrue(message.waitForExistence(timeout: 5))
            let exact = state == "error"
                ? "Couldn’t disconnect notifications. You’re still signed in. Reconnect and try signing out again before giving this iPhone to someone else."
                : "Couldn’t refresh. Your saved board is still available."
            XCTAssertEqual(message.label, exact)
            let list = app.collectionViews["account.settings"]
            let retry = app.buttons["Refresh Board Now"]
            for _ in 0..<4 {
                if retry.isHittable { break }
                list.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(retry.isEnabled)
            retry.tap()
            XCTAssertFalse(message.exists)
            retry.tap()
            XCTAssertTrue(message.waitForExistence(timeout: 3))
            XCTAssertEqual(message.label, exact)
            XCTAssertFalse(app.alerts["Delete Account?"].exists)
            app.navigationBars["Account"].buttons["Done"].tap()
            app.terminate()
        }
    }

    private func launchEnabled(style: String, size: String, state: String? = nil) {
        app.launchArguments = ["--hillclimb-demo", "account", "--hillclimb-style", style,
                               "--hillclimb-size", size, "--hillclimb-account-appearance", "enabled"]
        if let state { app.launchArguments += ["--hillclimb-account-state", state] }
        app.launch()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 10))
    }

    private func accountFrames() throws -> [String: [Double]] {
        let probe = app.descendants(matching: .any)["account.geometry"]
        let value = try XCTUnwrap(probe.value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: [Double]])
    }
}
