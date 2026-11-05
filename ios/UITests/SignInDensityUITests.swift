import XCTest

final class SignInDensityUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app.terminate() }

    private func launch(_ style: String, _ size: String, _ variant: String, paint: Bool = false) {
        app.terminate()
        app.launchArguments = [
            "--hillclimb-demo", "signin", "--hillclimb-style", style,
            "--hillclimb-size", size, "--hillclimb-signin-variant", variant,
        ]
        if paint { app.launchArguments += ["--hillclimb-signin-appearance", "enabled"] }
        app.launch()
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 10))
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "density-" + name
        shot.lifetime = .keepAlways
        add(shot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "density-" + name + "-frames"
        tree.lifetime = .keepAlways
        add(tree)
    }

    func testMatchedNativeStateMatrix() {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                for variant in ["default", "password", "loading", "error", "inbox"] {
                    launch(style, size, variant)
                    capture("\(style)-\(size)-\(variant)")
                }
                launch(style, size, "password-keyboard")
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
                capture("\(style)-\(size)-password-keyboard")
                let field = app.secureTextFields["Password"]
                field.typeText("offline-only")
                XCTAssertEqual((field.value as? String)?.count, 12)
                XCTAssertEqual(app.secureTextFields.count, 1)
                capture("\(style)-\(size)-populated-focused")
                app.buttons["Done"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
                capture("\(style)-\(size)-populated-dismissed")
                app.swipeUp()
                for name in ["Privacy", "Terms", "Support"] { XCTAssertTrue(app.buttons[name].isHittable) }
                capture("\(style)-\(size)-legal-bottom")
                launch(style, size, "password", paint: true)
                XCTAssertTrue(app.buttons["signin.apple"].isEnabled)
                capture("\(style)-\(size)-enabled-paint")
            }
        }
    }
    func testNativeFieldGroupingAndExactCopy() throws {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                launch(style, size, "password")
                let raw = try XCTUnwrap(app.otherElements["signin.densityFrames"].value as? String)
                let frames = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: [Double]])
                func frame(_ key: String) throws -> CGRect {
                    let v = try XCTUnwrap(frames[key], key)
                    return CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
                }
                for (upper, lower) in [
                    ("emailHeading", "emailHelper"), ("emailHelper", "emailField"),
                    ("passwordHeading", "passwordField"), ("passwordField", "passwordHelper"),
                ] {
                    XCTAssertEqual(try frame(lower).minY - frame(upper).maxY, 8, accuracy: 0.5)
                }
                XCTAssertEqual(
                    try frame("passwordGroup").minY - frame("emailGroup").maxY, 20, accuracy: 0.5)
                XCTAssertEqual(
                    try frame("actionGroup").minY - frame("passwordGroup").maxY, 20, accuracy: 0.5)
                XCTAssertGreaterThanOrEqual(try frame("passwordField").height, 48)
                XCTAssertEqual(
                    try frame("emailHeading").minY - app.buttons["Sign in with Google"].frame.maxY, 24,
                    accuracy: 1)
                for copy in [
                    "Email", "Use the same address as the web board.",
                    "For an existing account with a password. You can also use a sign-in link.",
                ] {
                    XCTAssertEqual(app.staticTexts.matching(identifier: copy).count, 1)
                }
                XCTAssertEqual(app.secureTextFields.matching(identifier: "Password").count, 1)
                XCTAssertEqual(
                    app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Password"))
                        .count, 1)
                XCTAssertGreaterThanOrEqual(app.buttons["Use a Sign-In Link Instead"].frame.height, 48)
                let proof = XCTAttachment(string: raw)
                proof.name = "density-gaps-\(style)-\(size)"
                proof.lifetime = .keepAlways
                add(proof)
                capture("groups-\(style)-\(size)")
            }
        }
    }

}
