import XCTest

final class ActivityNativeLayoutTests: XCTestCase {
    func testExpandedIslandLastLineClearsRoundedCorners() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--hillclimb-demo", "activity", "--hillclimb-activity", "short"]
        app.launch()
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let window = springboard.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 30.0 / 874.0))
            .press(forDuration: 1.5)
        let footer = springboard.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "\\+[0-9]+ more")).firstMatch
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "Actual ActivityKit overflow row was not exposed")
        let frame = footer.frame
        XCTAssertGreaterThanOrEqual(frame.height, 18, "Last row has insufficient glyph height")
        XCTAssertGreaterThanOrEqual(frame.minX, 30, "Last row enters the Island's curved lower-left corner")
        XCTAssertLessThanOrEqual(frame.maxY, 150, "Last row exceeds the native expanded Island height")
        let evidence = XCTAttachment(string: "Actual SpringBoard Activity footer frame: \(frame)")
        evidence.lifetime = .keepAlways
        add(evidence)
        app.launchArguments = ["--hillclimb-demo", "activity", "--hillclimb-activity", "end"]
        app.launch()
        app.terminate()
    }
}
