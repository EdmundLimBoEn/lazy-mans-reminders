import XCTest

final class ActivityNativeLayoutTests: XCTestCase {
    func testExpandedIslandLastLineClearsRoundedCorners() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--hillclimb-demo", "activity", "--hillclimb-activity", "multiline"]
        app.launch()
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let window = springboard.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 30.0 / 874.0))
            .press(forDuration: 1.5)
        let footer = springboard.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "\\+[0-9]+ more")).firstMatch
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "Actual ActivityKit overflow row was not exposed")
        XCTAssertEqual(footer.label, "+7 more")
        let rows = springboard.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Demo ")).allElementsBoundByIndex
        XCTAssertEqual(rows.count, 3, "Native Island must retain three original rows")
        XCTAssertEqual(rows.map(\.label), (1...3).map { "Demo \($0): Review the sample notes." },
                       "Accessibility content conservation; visible glyph tails are checked separately from recordings")
        XCTAssertEqual(rows.count + 7, 10)
        for (index, row) in rows.enumerated() {
            XCTAssertGreaterThanOrEqual(row.frame.height, 18)
            XCTAssertGreaterThanOrEqual(row.frame.minX, 30)
            XCTAssertLessThanOrEqual(row.frame.maxX, window.frame.width - 30)
            if index > 0 { XCTAssertGreaterThanOrEqual(row.frame.minY, rows[index - 1].frame.maxY) }
        }
        XCTAssertGreaterThanOrEqual(footer.frame.minY, try XCTUnwrap(rows.last).frame.maxY)
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
