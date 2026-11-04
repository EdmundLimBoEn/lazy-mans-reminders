import XCTest
import UIKit

final class BoardMultilineUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ mode: String = "full", xxxl: Bool, dark: Bool) {
        app.launchArguments = ["--hillclimb-demo", mode, "--hillclimb-size", xxxl ? "XXXL" : "default",
                               "--hillclimb-style", dark ? "dark" : "light"]
        app.launch()
        XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
    }
    private func geometry() throws -> [String: CGRect] {
        let data = try XCTUnwrap((app.otherElements["hillclimb.geometry"].value as? String)?.data(using: .utf8))
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [Double]])
        return values.mapValues { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
    }
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testCapacityAndFirstLineOpticalAlignmentMatrix() throws {
        for dark in [false, true] {
            for xxxl in [false, true] {
                launch(xxxl ? "long-text" : "full", xxxl: xxxl, dark: dark)
                let g = try geometry()
                let capacity = app.staticTexts["board.capacity"]
                XCTAssertEqual(capacity.label, "Board full — combine lines instead")
                XCTAssertEqual(app.textViews.count + app.textFields.count, 0)
                XCTAssertFalse(app.buttons["Add reminder"].isEnabled)
                let actual = try XCTUnwrap(g["capacity"])
                let ideal = try XCTUnwrap(g["capacityIdeal"])
                XCTAssertGreaterThanOrEqual(actual.height + 0.5, ideal.height)
                XCTAssertGreaterThan(actual.height, xxxl ? 50 : 20)
                XCTAssertGreaterThanOrEqual(capacity.frame.height, 44)
                capacity.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.98)).tap()
                XCTAssertFalse(app.keyboards.firstMatch.exists)
                let id = "00000000-0000-4000-8000-000000000001"
                let text = try XCTUnwrap(g["text-" + id])
                let circle = try XCTUnwrap(g["circle-" + id])
                let grip = try XCTUnwrap(g["grip-" + id])
                for target in [circle, grip] {
                    XCTAssertGreaterThanOrEqual(target.width, 44)
                    XCTAssertGreaterThanOrEqual(target.height, 44)
                }
                let shot = app.screenshot().image
                try assertTextContrast(shot, region: actual, dark: dark)
                try assertTextContrast(shot, region: XCTUnwrap(g["capacityHint"]), dark: dark)
                let circleInk = try inkBounds(shot, in: circle, dark: dark)
                let gripInk = try inkBounds(shot, in: grip, dark: dark)
                let firstLine = CGRect(x: text.minX, y: text.minY, width: text.width, height: xxxl ? 31 : 21)
                let textInk = try inkBounds(shot, in: firstLine, dark: dark)
                XCTAssertLessThan(abs(circleInk.midY - textInk.midY), 9)
                XCTAssertLessThan(abs(gripInk.midY - textInk.midY), 9)
                XCTAssertLessThan(circleInk.maxY, text.minY + text.height / 2)
                attach("board-\(dark ? "dark" : "light")-\(xxxl ? "XXXL" : "default")-top")
            }
        }
    }
    func testGuideHidesRestoresAndDismissalPersistsWhileEditing() throws {
        for dark in [false, true] {
            for xxxl in [false, true] {
                launch("empty", xxxl: xxxl, dark: dark)
                let heading = app.staticTexts["Keep Your Board in View"]
                XCTAssertTrue(heading.exists)
                let field = app.descendants(matching: .any).matching(identifier: "New reminder").firstMatch
                field.tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
                XCTAssertFalse(heading.exists)
                XCTAssertFalse(app.buttons["Dismiss tip"].exists)
                attach("guide-focused-\(dark)-\(xxxl)")
                app.buttons["Done"].tap()
                XCTAssertTrue(heading.waitForExistence(timeout: 5))
                let instructions = [
                    "Add the Notepad widget to your Lock Screen: touch and hold the Lock Screen, tap Customize, then Add Widgets.",
                    "Allow Live Activities so your board stays on the Lock Screen (Settings → Notepad → Live Activities).",
                    "Keep notifications on so reminders and board updates reach you."
                ]
                for instruction in instructions { XCTAssertTrue(app.staticTexts[instruction].exists) }
                attach("guide-restored-\(dark)-\(xxxl)")
                let dismiss = app.buttons["Dismiss tip"]
                XCTAssertGreaterThanOrEqual(dismiss.frame.width, 44)
                XCTAssertGreaterThanOrEqual(dismiss.frame.height, 44)
                dismiss.tap()
                XCTAssertFalse(heading.exists)
                field.tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
                app.buttons["Done"].tap()
                XCTAssertFalse(heading.exists)
            }
        }
    }

    func testOfflineLoadingAndErrorsMatrix() throws {
        for dark in [false, true] {
            for xxxl in [false, true] {
                for state in ["loading", "error-empty", "error-populated"] {
                    app.launchArguments = ["--hillclimb-demo", state == "error-populated" ? "full" : "empty",
                        "--hillclimb-board-state", state, "--hillclimb-size", xxxl ? "XXXL" : "default",
                        "--hillclimb-style", dark ? "dark" : "light"]
                    app.launch()
                    XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
                    if state == "loading" {
                        let loading = app.descendants(matching: .any).matching(identifier: "board.loading").firstMatch
                        XCTAssertTrue(loading.exists)
                        XCTAssertEqual(loading.label, "Loading reminders")
                        XCTAssertFalse(app.buttons["Try Again"].exists)
                        XCTAssertFalse(app.staticTexts["All Clear"].exists)
                    } else {
                        let message = URLError(.notConnectedToInternet).localizedDescription
                        XCTAssertTrue(app.staticTexts[message].exists)
                        XCTAssertEqual(try geometry()["boardErrorAnnouncements"]?.minX, 1)
                        if state == "error-empty" {
                            let retry = app.buttons["Try Again"]
                            XCTAssertTrue(retry.exists)
                            XCTAssertGreaterThanOrEqual(retry.frame.width, 44)
                            XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
                            retry.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
                            XCTAssertFalse(app.keyboards.firstMatch.exists)
                            XCTAssertEqual(try geometry()["boardErrorAnnouncements"]?.minX, 1)
                            let field = app.descendants(matching: .any).matching(identifier: "New reminder").firstMatch
                            field.tap()
                            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
                            XCTAssertEqual(try geometry()["boardErrorAnnouncements"]?.minX, 1)
                            app.buttons["Done"].tap()
                        } else {
                            app.buttons["Dismiss"].tap()
                            XCTAssertFalse(app.staticTexts[message].exists)
                            XCTAssertEqual(try geometry()["boardErrorAnnouncements"]?.minX, 1)
                            XCTAssertTrue(app.collectionViews.firstMatch.exists)
                        }
                    }
                    attach("\(state)-\(dark)-\(xxxl)")
                }
            }
        }
    }

    func testNonemptyDraftDonePreservesTextAndRefocusMatrix() throws {
        for dark in [false, true] {
            for xxxl in [false, true] {
                launch("composer", xxxl: xxxl, dark: dark)
                let field = app.descendants(matching: .any).matching(identifier: "New reminder").firstMatch
                field.tap()
                field.typeText("Remember the weekly review")
                let done = app.buttons["Done"]
                XCTAssertTrue(done.exists)
                XCTAssertGreaterThanOrEqual(done.frame.width, 44)
                XCTAssertGreaterThanOrEqual(done.frame.height, 44)
                XCTAssertTrue(app.buttons["Add reminder"].isEnabled)
                attach("nonempty-focused-\(dark)-\(xxxl)")
                done.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
                XCTAssertFalse(app.keyboards.firstMatch.exists)
                XCTAssertEqual(field.value as? String, "Remember the weekly review")
                field.tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
                XCTAssertEqual(field.value as? String, "Remember the weekly review")
                app.buttons["Done"].tap()
                XCTAssertEqual(try geometry()["authState"], .zero)
            }
        }
    }

    func testOnlyCircleCompletesLocalFixtureAndGripStillReordersMatrix() throws {
        for dark in [false, true] {
            for xxxl in [false, true] {
                app.launchArguments = ["--hillclimb-demo", "long-text", "--hillclimb-size", xxxl ? "XXXL" : "default",
                    "--hillclimb-style", dark ? "dark" : "light", "--hillclimb-board-interaction", "local"]
                app.launch()
                XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
                let first = app.buttons.matching(NSPredicate(format: "value == %@", "Active")).firstMatch
                let label = first.label
                let text = app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
                XCTAssertTrue(text.exists)
                let g = try geometry()
                let id = "00000000-0000-4000-8000-000000000001"
                let rect = try XCTUnwrap(g["text-" + id])
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: rect.midX, dy: rect.midY)).tap()
                XCTAssertEqual(try geometry()["boardCompletions"]?.minX, 0)
                XCTAssertTrue(first.exists)
                XCTAssertEqual(first.value as? String, "Active")
                let grip = app.otherElements.matching(NSPredicate(format: "label == %@", "Reorder " + label)).firstMatch
                XCTAssertTrue(grip.exists)
                XCTAssertEqual(grip.value as? String, "Position 1 of 7")
                XCTAssertGreaterThanOrEqual(grip.frame.width, 44)
                let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                start.press(forDuration: 0.15, thenDragTo: start.withOffset(CGVector(dx: 0, dy: rect.height + 40)))
                XCTAssertEqual(try geometry()["boardMoves"]?.minX, 1)
                let circle = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
                XCTAssertGreaterThanOrEqual(circle.frame.width, 44)
                XCTAssertGreaterThanOrEqual(circle.frame.height, 44)
                circle.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).tap()
                XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch.exists)
                XCTAssertEqual(try geometry()["boardCompletions"]?.minX, 1)
                XCTAssertEqual(try geometry()["authState"], .zero)
                attach("local-completion-\(dark)-\(xxxl)")
            }
        }
    }

    func testPopulatedRetryRecoversLocallyOnceWithoutFocusOrDuplicateAnnouncement() throws {
        for dark in [false, true] {
            for xxxl in [false, true] {
                app.launchArguments = ["--hillclimb-demo", "full", "--hillclimb-board-state", "error-populated",
                    "--hillclimb-board-retry", "recover", "--hillclimb-size", xxxl ? "XXXL" : "default",
                    "--hillclimb-style", dark ? "dark" : "light"]
                app.launch()
                XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.staticTexts["Couldn’t Load Board"].exists)
                let message = URLError(.notConnectedToInternet).localizedDescription
                XCTAssertTrue(app.staticTexts[message].exists)
                let retry = app.buttons["Try Again"]
                XCTAssertGreaterThanOrEqual(retry.frame.width, 44)
                XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
                let rows = app.buttons.matching(NSPredicate(format: "value == %@", "Active"))
                let firstLabel = rows.firstMatch.label
                let list = app.collectionViews.firstMatch
                for _ in 0..<8 { list.swipeUp(velocity: .fast) }
                let g = try geometry()
                let last = try XCTUnwrap(g["00000000-0000-4000-8000-000000000007"])
                let viewport = try XCTUnwrap(g["listViewport"])
                let composer = try XCTUnwrap(g["composer"])
                XCTAssertGreaterThanOrEqual(last.minY, viewport.minY)
                XCTAssertLessThanOrEqual(last.maxY, composer.minY + 0.5)
                attach("populated-error-bottom-\(dark)-\(xxxl)")
                retry.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
                XCTAssertFalse(app.staticTexts[message].exists)
                XCTAssertFalse(app.keyboards.firstMatch.exists)
                XCTAssertEqual(try geometry()["boardRetryAttempts"]?.minX, 1)
                XCTAssertEqual(try geometry()["boardErrorAnnouncements"]?.minX, 1)
                for _ in 0..<8 { list.swipeDown(velocity: .fast) }
                XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", firstLabel)).firstMatch.exists)
                XCTAssertTrue(app.staticTexts["Board full — combine lines instead"].exists)
                attach("populated-recovered-\(dark)-\(xxxl)")
            }
        }
    }

    private func assertTextContrast(_ image: UIImage, region: CGRect, dark: Bool) throws {
        let cg = try XCTUnwrap(image.cgImage)
        let scale = CGFloat(cg.width) / app.frame.width
        let crop = try XCTUnwrap(cg.cropping(to: region.applying(CGAffineTransform(scaleX: scale, y: scale))))
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: crop.width, height: crop.height,
            bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        var counts: [Int: Int] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let rgb = Int(pixels[i]) << 16 | Int(pixels[i + 1]) << 8 | Int(pixels[i + 2])
            counts[rgb, default: 0] += 1
        }
        func luminance(_ rgb: Int) -> Double {
            let channels = [rgb >> 16 & 255, rgb >> 8 & 255, rgb & 255].map { value -> Double in
                let c = Double(value) / 255
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        let background = try XCTUnwrap(counts.max(by: { $0.value < $1.value })).key
        // Solid interiors dominate the text histogram. Exclude background and
        // near-background antialiasing rather than treating edge blends as ink.
        let bg = luminance(background)
        let ink = try XCTUnwrap(counts.filter {
            dark ? luminance($0.key) > bg + 0.2 : luminance($0.key) < bg - 0.2
        }.max(by: { $0.value < $1.value }))
        XCTAssertGreaterThan(ink.value, 20)
        let fg = luminance(ink.key)
        XCTAssertGreaterThanOrEqual((max(fg, bg) + 0.05) / (min(fg, bg) + 0.05), 4.5)
    }

    private func inkBounds(_ image: UIImage, in region: CGRect, dark: Bool) throws -> CGRect {
        let cg = try XCTUnwrap(image.cgImage)
        let scale = CGFloat(cg.width) / app.frame.width
        let crop = try XCTUnwrap(cg.cropping(to: region.applying(CGAffineTransform(scaleX: scale, y: scale))))
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: crop.width, height: crop.height,
            bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        var xs: [Int] = [], ys: [Int] = []
        for y in 0..<crop.height {
            for x in 0..<crop.width {
                let i = (y * crop.width + x) * 4
                let value = (Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])) / 3
                if dark ? value > 100 : value < 190 { xs.append(x); ys.append(y) }
            }
        }
        XCTAssertGreaterThan(xs.count, 15, "Rendered glyph ink must exist")
        return CGRect(x: region.minX + CGFloat(try XCTUnwrap(xs.min())) / scale,
                      y: region.minY + CGFloat(try XCTUnwrap(ys.min())) / scale,
                      width: CGFloat(try XCTUnwrap(xs.max()) - (xs.min() ?? 0) + 1) / scale,
                      height: CGFloat(try XCTUnwrap(ys.max()) - (ys.min() ?? 0) + 1) / scale)
    }
}
