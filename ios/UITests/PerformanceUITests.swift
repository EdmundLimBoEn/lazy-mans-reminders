import XCTest

final class PerformanceUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--hillclimb-demo", "long-text", "--hillclimb-style", "light", "--hillclimb-size", "default"]
    }

    override func tearDownWithError() throws { app.terminate() }

    private func options() -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        return options
    }

    func testSeededLaunchMetric() {
        measure(metrics: [XCTApplicationLaunchMetric()], options: options()) {
            app.terminate()
            startMeasuring()
            app.launch()
            stopMeasuring()
            XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.collectionViews.firstMatch.exists)
        }
    }

    func testSeededScrollElapsedMetric() {
        measureScroll(metrics: [XCTClockMetric()])
    }

    func testSeededScrollSignpostMetric() {
        measureScroll(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric])
    }

    private func measureScroll(metrics: [any XCTMetric]) {
        measure(metrics: metrics, options: options()) {
            app.terminate()
            app.launch()
            XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
            let list = app.collectionViews.firstMatch
            XCTAssertTrue(list.exists)
            startMeasuring()
            list.swipeUp(velocity: .slow)
            list.swipeDown(velocity: .slow)
            stopMeasuring()
            XCTAssertTrue(app.otherElements["hillclimb.geometry"].exists)
            XCTAssertFalse(app.buttons["Add reminder"].exists)
        }
    }
}
