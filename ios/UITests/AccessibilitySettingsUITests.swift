import XCTest

final class AccessibilitySettingsUITests: XCTestCase {
    private let app = XCUIApplication()
    private let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    private var originals: [String: Bool] = [:]

    override func setUpWithError() throws {
        continueAfterFailure = false
        if let recovery = ProcessInfo.processInfo.environment["HILLCLIMB_RESTORE_ORIGINALS"] {
            let recorded = try JSONDecoder().decode([String: Bool].self, from: Data(recovery.utf8))
            XCTAssertEqual(Set(recorded.keys), Set([
                "Reduce Motion", "Auto-Play Message Effects", "Reduce Transparency", "Increase Contrast",
            ]))
            originals = recorded
            try configure(enabled: false, restoring: true)
            settings.terminate()
            originals.removeAll()
        }
    }

    override func tearDownWithError() throws {
        app.terminate()
        if !originals.isEmpty { try configure(enabled: false, restoring: true) }
        settings.terminate()
    }

    func testCombinedActualSettingsKeyboardMatrix() throws {
        try configure(enabled: true)
        settings.terminate()
        verifyKeyboardMatrix(styles: ["light"])
    }

    func testCombinedActualSettingsDarkKeyboardMatrix() throws {
        try configure(enabled: true)
        settings.terminate()
        verifyKeyboardMatrix(styles: ["dark"])
    }

    func testCombinedActualSettingsErrorContrast() throws {
        try configure(enabled: true)
        settings.terminate()
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                launch(style: style, size: size, variant: "error")
                let signIn = app.staticTexts["Couldn’t sign in. Check your email and password, or use a sign-in link. If you’re offline, reconnect and try again."]
                if !signIn.isHittable { app.swipeUp() }
                try assertNativeErrorRaster(signIn, app: app, name: "combined-signin-\(style)-\(size)-error")
                for state in ["error", "refresh-error"] {
                    app.launchArguments = ["--hillclimb-demo", "account", "--hillclimb-style", style, "--hillclimb-size", size, "--hillclimb-account-appearance", "enabled", "--hillclimb-account-state", state]
                    app.launch()
                    XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 10))
                    let message = app.staticTexts[state == "error" ? "account.error" : "account.refreshResult"]
                    if !message.isHittable { app.collectionViews["account.settings"].swipeUp(velocity: .slow) }
                    try assertNativeErrorRaster(message, app: app, name: "combined-account-\(state)-\(style)-\(size)", frame: message.frame.insetBy(dx: 8, dy: 4))
                }
            }
        }
    }

    private func configure(enabled: Bool, restoring: Bool = false) throws {
        settings.launch()
        // Return through native back buttons if Settings retained its previous page.
        for _ in 0..<5 {
            if settings.staticTexts["Accessibility"].exists { break }
            let back = settings.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
        }
        let accessibility = settings.staticTexts["Accessibility"]
        XCTAssertTrue(accessibility.waitForExistence(timeout: 5))
        accessibility.tap()
        for (page, labels) in [("Motion", ["Reduce Motion"]), ("Display & Text Size", ["Reduce Transparency", "Increase Contrast"])] {
            settings.staticTexts[page].tap()
            recordSettings(page: page, stage: restoring ? "before-restore" : "original")
            for label in labels {
                let toggle = settings.switches[label]
                XCTAssertTrue(toggle.waitForExistence(timeout: 5), label)
                let value = try XCTUnwrap(toggle.value as? String)
                if !restoring {
                    let before = XCTAttachment(screenshot: settings.screenshot())
                    before.name = "actual-settings-original-" + label; before.lifetime = .keepAlways; add(before)
                }
                if originals[label] == nil { originals[label] = value == "1" }
                if label == "Reduce Motion", !restoring {
                    let effects = settings.switches["Auto-Play Message Effects"]
                    XCTAssertTrue(effects.waitForExistence(timeout: 5))
                    if originals["Auto-Play Message Effects"] == nil {
                        originals["Auto-Play Message Effects"] = try XCTUnwrap(effects.value as? String) == "1"
                    }
                }
                let desired = restoring ? try XCTUnwrap(originals[label]) : enabled
                if (value == "1") != desired { toggle.switches.firstMatch.tap() }
                XCTAssertEqual(toggle.value as? String, desired ? "1" : "0", label)
            }
            if page == "Motion", restoring, let desired = originals["Auto-Play Message Effects"] {
                let effects = settings.switches["Auto-Play Message Effects"]
                XCTAssertTrue(effects.waitForExistence(timeout: 5))
                if (effects.value as? String == "1") != desired { effects.switches.firstMatch.tap() }
                XCTAssertEqual(effects.value as? String, desired ? "1" : "0", "Restore the dependent Motion setting")
            }
            recordSettings(page: page, stage: restoring ? "restored" : "enabled")
            let proof = XCTAttachment(screenshot: settings.screenshot())
            proof.name = "actual-settings-\(page)-\(restoring ? "restored" : "enabled")"; proof.lifetime = .keepAlways; add(proof)
            settings.navigationBars.buttons.firstMatch.tap()
        }
    }

    private func recordSettings(page: String, stage: String) {
        let values = settings.switches.allElementsBoundByIndex.map {
            "\($0.label)=\($0.value ?? "nil")"
        }.joined(separator: "\n")
        let proof = XCTAttachment(string: "page=\(page) stage=\(stage) originals=\(originals)\n\(values)\n\(settings.debugDescription)")
        proof.name = "settings-values-\(page)-\(stage)"
        proof.lifetime = .keepAlways
        add(proof)
    }

    private func launch(style: String, size: String, variant: String) {
        app.launchArguments = ["--hillclimb-demo", "signin", "--hillclimb-style", style, "--hillclimb-size", size, "--hillclimb-signin-variant", variant]
        app.launch()
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 10))
    }
    private func target(_ element: XCUIElement) {
        XCTAssertTrue(element.exists)
        XCTAssertGreaterThanOrEqual(element.frame.width, 44)
        XCTAssertGreaterThanOrEqual(element.frame.height, 44)
        XCTAssertGreaterThanOrEqual(element.frame.minX, 0)
        XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.width)
    }
    private func capture(_ name: String) {
        let proof = XCTAttachment(screenshot: app.screenshot()); proof.name = "combined-settings-" + name; proof.lifetime = .keepAlways; add(proof)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "combined-full-screen-" + name; screen.lifetime = .keepAlways; add(screen)
    }
    private func verifyKeyboardMatrix(styles: [String]) {
        for style in styles {
            for size in ["default", "XXXL"] {
            for variant in ["keyboard", "password-keyboard"] {
                launch(style: style, size: size, variant: variant)
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
                let field = variant == "keyboard" ? app.textFields["Email address"] : app.secureTextFields["Password"]
                XCTAssertTrue(field.exists)
                target(app.otherElements[variant == "keyboard" ? "signin.emailTarget" : "signin.passwordTarget"])
                XCTAssertLessThanOrEqual(field.frame.maxY, app.keyboards.firstMatch.frame.minY)
                XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
                let done = app.buttons["Done"]
                target(done)
                XCTAssertGreaterThanOrEqual(done.frame.height, 48)
                let alternate = app.buttons[variant == "keyboard" ? "Use an Existing Password" : "Use a Sign-In Link Instead"]
                XCTAssertLessThanOrEqual(alternate.frame.maxY + 8, done.frame.minY)
                XCTAssertGreaterThanOrEqual(field.frame.minY, app.navigationBars.firstMatch.frame.maxY)
                // Exercise real form scrolling as well as initial keyboard placement.
                scrollFormAndRestoreKeyboard(field: field)

                target(alternate)
                XCTAssertTrue(alternate.isHittable)
                XCTAssertFalse(alternate.frame.intersects(done.frame))
                XCTAssertLessThanOrEqual(alternate.frame.maxY + 8, done.frame.minY)
                XCTAssertLessThanOrEqual(alternate.frame.maxY, app.keyboards.firstMatch.frame.minY)
                let geometry = XCTAttachment(string: "style=\(style) size=\(size) variant=\(variant) field=\(field.frame) nav=\(app.navigationBars.firstMatch.frame) alternate=\(alternate.frame) done=\(done.frame) keyboard=\(app.keyboards.firstMatch.frame)")
                geometry.name = "combined-geometry-\(style)-\(size)-\(variant)"; geometry.lifetime = .keepAlways; add(geometry)
                capture("signin-\(style)-\(size)-\(variant)")
                done.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
                field.tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

                XCTAssertFalse(alternate.frame.intersects(done.frame))
                XCTAssertLessThanOrEqual(alternate.frame.maxY + 8, done.frame.minY)
                alternate.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
                XCTAssertTrue(app.buttons[variant == "keyboard" ? "Use a Sign-In Link Instead" : "Use an Existing Password"].exists)
                if app.keyboards.firstMatch.exists {
                    done.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
                }
            }
            }
        }
    }
    private func scrollFormAndRestoreKeyboard(field: XCUIElement) {
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let top = app.navigationBars.firstMatch.frame.maxY + 12
        let bottom = min(app.buttons["Done"].frame.minY - 12, app.keyboards.firstMatch.frame.minY - 12)
        XCTAssertGreaterThan(bottom - top, 44)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: bottom))
        let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: top))
        start.press(forDuration: 0.05, thenDragTo: end)
        // Interactive dismissal is valid; refocus before querying keyboard geometry.
        if !app.keyboards.firstMatch.exists {
            XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 5))
            XCTAssertTrue(field.isHittable)
            field.tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(field.frame.minY, app.navigationBars.firstMatch.frame.maxY)
        XCTAssertLessThanOrEqual(field.frame.maxY, app.buttons["Done"].frame.minY)
    }

}
