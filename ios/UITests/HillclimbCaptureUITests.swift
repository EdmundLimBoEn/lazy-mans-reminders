import XCTest

final class HillclimbCaptureUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app.terminate() }

    private func launch(_ mode: String, style: String, size: String) {
        app.terminate()
        app.launchArguments = ["--hillclimb-demo", mode, "--hillclimb-style", style,
                               "--hillclimb-size", size]
        app.launch()
        XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
    }

    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let geometry = XCTAttachment(string: app.debugDescription)
        geometry.name = name + "-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
    }

    func testSeededBoardAndComposerCaptureMatrix() {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                for mode in ["empty", "full", "long-text", "composer"] {
                    launch(mode, style: style, size: size)
                    capture("canonical-\(mode)-\(style)-\(size)-top")
                    if mode == "full" || mode == "long-text" {
                        let list = app.collectionViews.firstMatch
                        list.swipeDown()
                        for _ in 0..<6 { list.swipeUp(velocity: .fast) }
                        capture("canonical-\(mode)-\(style)-\(size)-bottom-after-pull")
                    }
                    if mode == "composer" {
                        app.descendants(matching: .any).matching(identifier: "New reminder").firstMatch.tap()
                        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
                        capture("canonical-composer-\(style)-\(size)-keyboard-partial")
                        app.buttons["Done"].tap()
                        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
                    }
                }
            }
        }
    }

    func testSeededAccountAndSignInCaptureMatrix() {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                for mode in ["account", "signin"] {
                    launch(mode, style: style, size: size)
                    XCTAssertTrue(app.navigationBars[mode == "account" ? "Account" : "Sign In"].exists)
                    capture("canonical-\(mode)-\(style)-\(size)-top")
                    let scroll = mode == "account" ? app.collectionViews.firstMatch : app.scrollViews.firstMatch
                    scroll.swipeUp()
                    scroll.swipeUp()
                    capture("canonical-\(mode)-\(style)-\(size)-bottom")
                }
            }
        }
    }
}
