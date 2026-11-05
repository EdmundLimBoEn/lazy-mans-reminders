import XCTest

final class ActivityCaptureUITests: XCTestCase {
    private let app = XCUIApplication()
    private let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    private var originalTextSize: Float?
    private var originalAppearance: XCUIDevice.Appearance?

    override func setUpWithError() throws {
        continueAfterFailure = false
        originalAppearance = XCUIDevice.shared.appearance
    }

    override func tearDownWithError() throws {
        endActivity()
        if let originalTextSize {
            try openTextSize()
            settings.sliders.firstMatch.adjust(toNormalizedSliderPosition: CGFloat(originalTextSize))
            XCTAssertEqual(try sliderValue(), originalTextSize, accuracy: 0.02)
        }
        settings.terminate()
        if let originalAppearance { XCUIDevice.shared.appearance = originalAppearance }
    }

    private func openTextSize() throws {
        settings.launch()
        for _ in 0..<5 {
            if settings.staticTexts["Accessibility"].exists { break }
            let back = settings.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
        }
        settings.staticTexts["Accessibility"].tap()
        settings.staticTexts["Display & Text Size"].tap()
        settings.staticTexts["Larger Text"].tap()
        XCTAssertTrue(settings.sliders.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(settings.switches["Larger Accessibility Sizes"].value as? String, "0")
    }

    private func sliderValue() throws -> Float {
        let value = try XCTUnwrap(settings.sliders.firstMatch.value as? String)
        return try XCTUnwrap(Float(value.replacingOccurrences(of: "%", with: ""))) / 100
    }

    private func endActivity() {
        app.launchArguments = ["--hillclimb-demo", "activity", "--hillclimb-activity", "end"]
        app.launch()
        XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 5))
        app.terminate()
    }

    private func capture(_ name: String, springboard: XCUIApplication) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let tree = XCTAttachment(string: springboard.debugDescription)
        tree.name = name + "-geometry"
        tree.lifetime = .keepAlways
        add(tree)
    }

    func testNativeShortActivityMatrix() throws {
        try verifyActivityMatrix(text: "multiline")
    }

    func testNativeLongActivityMatrix() throws {
        try verifyActivityMatrix(text: "long")
    }

    private func verifyActivityMatrix(text: String) throws {
        for size in ["default", "XXXL"] {
            try openTextSize()
            if originalTextSize == nil { originalTextSize = try sliderValue() }
            let target: Float = size == "XXXL" ? 1 : 0.5
            settings.sliders.firstMatch.adjust(toNormalizedSliderPosition: CGFloat(target))
            XCTAssertEqual(try sliderValue(), target, accuracy: 0.02)
            settings.terminate()
            for style in ["light", "dark"] {
                XCUIDevice.shared.appearance = style == "light" ? .light : .dark
                app.launchArguments = ["--hillclimb-demo", "activity", "--hillclimb-activity", text]
                app.launch()
                XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 5))
                XCUIDevice.shared.press(.home)
                let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                let window = springboard.windows.firstMatch
                XCTAssertTrue(window.waitForExistence(timeout: 10))
                window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 30.0 / 874.0)).press(forDuration: 1.5)
                let total = text == "multiline" ? 10 : 8
                let islandRows = size == "XXXL" ? 2 : 3
                let islandFooter = springboard.staticTexts["+\(total - islandRows) more"]
                XCTAssertTrue(islandFooter.waitForExistence(timeout: 5))
                capture("activity-\(text)-\(style)-\(size)-island", springboard: springboard)
                XCUIDevice.shared.press(.home)
                let origin = window.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: 20, dy: 2)).press(forDuration: 0.1,
                    thenDragTo: origin.withOffset(CGVector(dx: 20, dy: 650)))
                let bannerRows = size == "XXXL" ? 4 : 5
                let bannerFooter = springboard.staticTexts["+\(total - bannerRows) more"]
                XCTAssertTrue(bannerFooter.waitForExistence(timeout: 5))
                capture("activity-\(text)-\(style)-\(size)-banner", springboard: springboard)
                endActivity()
            }
        }
    }
}
