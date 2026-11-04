import XCTest
import UIKit

final class HillclimbUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    private func launch(_ mode: String, xxxl: Bool = false, style: String = "light") {
        app.launchArguments = ["--hillclimb-demo", mode, "--hillclimb-style", style,
                               "--hillclimb-size", xxxl ? "XXXL" : "default"]
        app.launch()
        XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
    }
    private func frames() throws -> [String: CGRect] {
        let element = app.otherElements["hillclimb.geometry"]
        let json = try XCTUnwrap(element.value as? String)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [Double]])
        return values.mapValues { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
    }
    private func lastRowID(_ geometry: [String: CGRect]) throws -> String {
        let count = Int(try XCTUnwrap(geometry["fixtureCount"]).minX)
        XCTAssertGreaterThan(count, 0)
        return String(format: "00000000-0000-4000-8000-%012d", count)
    }
    private func bottom() throws {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        // Pull at the top, then traverse well beyond the finite fixture's capacity.
        list.swipeDown()
        XCTAssertEqual(try frames()["refreshState"]?.minX, 0, "Pull must finish refreshing before the next gesture")
        var previous: CGRect?
        for _ in 0..<12 {
            let geometry = try frames()
            if let id = try? lastRowID(geometry),
               let row = geometry[id], let composer = geometry["composer"], let safe = geometry["safeArea"],
               row.minY >= safe.minY, row.maxY <= composer.minY + 0.5 {
                return
            }
            let lastVisible = geometry[try lastRowID(geometry)]
            if let previous, previous == lastVisible { return }
            previous = lastVisible
            list.swipeUp(velocity: .fast)
        }
        XCTFail("Could not settle at the bottom within 12 swipes")
    }
    func testFullBoardBottomAboveComposerAfterPullAndScroll() throws {
        launch("full")
        try bottom()
        let geometry = try frames()
        let lastID = try lastRowID(geometry)
        let last = try XCTUnwrap(geometry[lastID])
        let composer = try XCTUnwrap(geometry["composer"])
        let safe = try XCTUnwrap(geometry["safeArea"])
        XCTAssertGreaterThan(last.height, 0)
        XCTAssertGreaterThanOrEqual(last.minY, safe.minY)
        XCTAssertLessThanOrEqual(last.maxY, composer.minY + 0.5, "Last row is obscured by the composer")
        try assertFinalInk(geometry, dark: false)
    }
    func testTopControlsAvoidIslandAndHave44PointTargets() throws {
        launch("full")
        let safe = try XCTUnwrap(try frames()["safeArea"])
        let account = app.buttons["Account"]
        XCTAssertTrue(account.exists)
        XCTAssertGreaterThanOrEqual(account.frame.minY, safe.minY)
        assertTarget(account)
        assertTarget(app.buttons["Add reminder"])
    }
    func testXXXLTextFitsAllocatedHeightAtBottom() throws {
        launch("long-text", xxxl: true)
        try bottom()
        let geometry = try frames()
        let safe = try XCTUnwrap(geometry["safeArea"])
        let composer = try XCTUnwrap(geometry["composer"])
        let typeSize = try XCTUnwrap(geometry["typeSize"])
        XCTAssertGreaterThan(typeSize.minX, typeSize.minY, "UIKit rows must inherit XXXL, not the default size")
        let visible = geometry.keys.filter { $0.hasPrefix("text-") && geometry[$0]!.intersects(safe) }
        XCTAssertFalse(visible.isEmpty, "No rendered text geometry measured")
        for key in visible {
            let actual = try XCTUnwrap(geometry[key])
            let ideal = try XCTUnwrap(geometry[key.replacingOccurrences(of: "text-", with: "ideal-")])
            XCTAssertGreaterThan(ideal.height, 0)
            XCTAssertGreaterThanOrEqual(actual.height + 0.5, ideal.height, "Clipped text: \(key)")
            XCTAssertGreaterThanOrEqual(actual.minX, safe.minX)
            XCTAssertLessThanOrEqual(actual.maxX, safe.maxX)
        }
        let last = try XCTUnwrap(geometry[try lastRowID(geometry)])
        XCTAssertLessThanOrEqual(last.maxY, composer.minY + 0.5)
        XCTAssertGreaterThanOrEqual(last.minY, safe.minY, "Last long row cannot fit fully on screen")
        try assertFinalInk(geometry, dark: false)
    }
    func testComposerKeyboardDismissTarget() {
        launch("composer")
        let field = app.descendants(matching: .any).matching(identifier: "New reminder").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        assertTarget(field)
        field.tap()
        let dismiss = app.buttons["Done"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        assertTarget(dismiss)
        dismiss.tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }
    func testOfflineRoutesAndFixtureStability() throws {
        launch("empty")
        XCTAssertTrue(app.staticTexts["All Clear"].exists)
        launch("account")
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        launch("signin")
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 5))
        launch("full")
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Demo 1:")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let auth = try XCTUnwrap(try frames()["authState"])
        XCTAssertEqual(auth, .zero, "Demo must have no authenticated/restoring/shared session")
        let label = first.label
        first.tap() // Demo completion must never reach the production store.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch.exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch.waitForExistence(timeout: 5))
    }
    func testDarkBoardBottomInkAfterPull() throws {
        for xxxl in [false, true] {
            launch(xxxl ? "long-text" : "full", xxxl: xxxl, style: "dark")
            try bottom()
            try assertFinalInk(frames(), dark: true)
        }
    }

    private func assertFinalInk(_ geometry: [String: CGRect], dark: Bool) throws {
        let text = try XCTUnwrap(geometry["text-" + lastRowID(geometry)])
        let fade = try XCTUnwrap(geometry["bottomFade"])
        let composer = try XCTUnwrap(geometry["composer"])
        XCTAssertLessThanOrEqual(text.maxY, min(fade.minY, composer.minY) + 0.5,
                                 "Final rendered text must clear the entire bottom edge effect")
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "settled-final-ink"
        attachment.lifetime = .keepAlways
        add(attachment)
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let scale = CGFloat(image.width) / app.frame.width
        let region = CGRect(x: text.minX, y: text.maxY - 18, width: text.width, height: 16)
        let crop = try XCTUnwrap(image.cropping(to: region.applying(CGAffineTransform(scaleX: scale, y: scale))))
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: crop.width, height: crop.height,
            bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        var strongInk = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            if dark {
                if red > 200 && green > 200 && blue > 200 { strongInk += 1 }
            } else {
                if red < 55 && green < 55 && blue < 55 { strongInk += 1 }
            }
        }
        XCTAssertGreaterThan(strongInk, 20, "Final line must contain high-contrast ink, not faded gray glyphs")
    }

    private func assertTarget(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.exists, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.width, 44, "\(element.label) width", file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.height, 44, "\(element.label) height", file: file, line: line)
    }
}
