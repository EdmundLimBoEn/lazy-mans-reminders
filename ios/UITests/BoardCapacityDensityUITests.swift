import XCTest
import UIKit
import SwiftUI

@MainActor
final class BoardCapacityDensityUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app.terminate() }

    func testLightDefaultCapacityDensity() throws { try check(dark: false, xxxl: false) }
    func testDarkDefaultCapacityDensity() throws { try check(dark: true, xxxl: false) }
    func testLightXXXLTitleAndFinalInkCapacityDensity() throws { try check(dark: false, xxxl: true) }
    func testDarkXXXLTitleAndFinalInkCapacityDensity() throws { try check(dark: true, xxxl: true) }

    private func geometry() throws -> [String: CGRect] {
        let data = try XCTUnwrap((app.otherElements["hillclimb.geometry"].value as? String)?.data(using: .utf8))
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [Double]])
        return values.mapValues { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
    }
    private func capture(_ state: String, dark: Bool, xxxl: Bool) throws {
        let name = "capacity-\(dark ? "dark" : "light")-\(xxxl ? "XXXL" : "default")-\(state)"
        for attachment in [XCTAttachment(screenshot: XCUIScreen.main.screenshot()),
                           XCTAttachment(string: app.debugDescription),
                           XCTAttachment(string: try XCTUnwrap(app.otherElements["hillclimb.geometry"].value as? String))] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
    private func check(dark: Bool, xxxl: Bool) throws {
        app.launchArguments = ["--hillclimb-demo", xxxl ? "long-text" : "full",
            "--hillclimb-style", dark ? "dark" : "light", "--hillclimb-size", xxxl ? "XXXL" : "default",
            "--hillclimb-board-interaction", "local"]
        app.launch()
        XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
        let status = app.staticTexts["board.capacity"]
        XCTAssertEqual(status.label, "Board full — combine lines instead")
        XCTAssertFalse(app.buttons["Add reminder"].exists)
        XCTAssertFalse(app.buttons["Adding reminder"].exists)
        XCTAssertEqual(app.textViews.count + app.textFields.count, 0)
        XCTAssertGreaterThanOrEqual(status.frame.height, 44)
        let g = try geometry()
        let composer = try XCTUnwrap(g["composer"])
        // The static capacity group shares the native 18pt gutter on both sides.
        XCTAssertEqual(status.frame.minX, composer.minX + 18, accuracy: 1)
        XCTAssertEqual(status.frame.maxX, composer.maxX - 18, accuracy: 1)
        let hintCopy = "Hint: This board is more like a post-it note. Combine reminders into one line, or find other ways to keep it short."
        XCTAssertEqual(app.staticTexts.matching(identifier: "board.capacity").count, 1)
        // XCTest includes the ignored backing Text beneath the semantic status wrapper,
        // as in the original binary. There must be only one independent status subtree.
        let statusMatches = app.staticTexts.matching(NSPredicate(format: "label == %@", status.label)).count
        let backingMatches = status.descendants(matching: .staticText)
            .matching(NSPredicate(format: "label == %@", status.label)).count
        XCTAssertEqual(statusMatches - backingMatches, 1)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", hintCopy)).count, 1)
        let hint = try XCTUnwrap(g["capacityHint"])
        XCTAssertEqual(status.frame.minX, hint.minX, accuracy: 1)
        XCTAssertEqual(hint.minX, composer.minX + 18, accuracy: 1)
        XCTAssertLessThan(status.frame.maxY, hint.minY)
        XCTAssertGreaterThanOrEqual(hint.minY - status.frame.maxY, 6)
        XCTAssertLessThanOrEqual(hint.minY - status.frame.maxY, 8)
        // Measured from this device's original binary, retained alongside native before images.
        let measuredBaselineHeight: CGFloat = xxxl ? 147.66666666666663 : 110.33333333333337
        XCTAssertLessThanOrEqual(composer.height, measuredBaselineHeight)
        let reference = UIHostingController(rootView: Text(hintCopy).font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.dynamicTypeSize, xxxl ? .xxxLarge : .large))
        let idealHint = reference.sizeThatFits(in: CGSize(width: composer.width - 36, height: .greatestFiniteMagnitude))
        XCTAssertGreaterThanOrEqual(hint.height + 0.5, idealHint.height)
        try assertTextContrast(app.screenshot().image, region: hint, dark: dark)
        let actual = try XCTUnwrap(g["capacity"])
        let statusInk = try inkBounds(app.screenshot().image, in: actual, dark: dark)
        let hintInk = try inkBounds(app.screenshot().image, in: hint, dark: dark)
        XCTAssertEqual(statusInk.minX, hintInk.minX, accuracy: 1)
        let proof = XCTAttachment(string: "baselineFooterHeight=\(measuredBaselineHeight) actualFooterHeight=\(composer.height) status=\(status.frame) hint=\(hint) idealHint=\(idealHint) statusInk=\(statusInk) hintInk=\(hintInk)")
        proof.name = "density-layout-\(dark ? "dark" : "light")-\(xxxl ? "XXXL" : "default")"
        proof.lifetime = .keepAlways
        add(proof)
        XCTAssertGreaterThan(actual.height, xxxl ? 26 : 20)
        if xxxl {
            let type = try XCTUnwrap(g["typeSize"])
            XCTAssertGreaterThan(type.minX, type.minY)
        }
        XCTAssertGreaterThanOrEqual(actual.height + 0.5, try XCTUnwrap(g["capacityIdeal"]).height)
        try assertTextContrast(app.screenshot().image, region: actual, dark: dark)
        try capture("full-top", dark: dark, xxxl: xxxl)
        let list = app.collectionViews.firstMatch
        list.swipeDown()
        XCTAssertEqual(try geometry()["refreshState"]?.minX, 0)
        for _ in 0..<8 { list.swipeUp(velocity: .fast) }
        let bottom = try geometry()
        let id = "00000000-0000-4000-8000-000000000007"
        let row = try XCTUnwrap(bottom[id])
        let viewport = try XCTUnwrap(bottom["listViewport"])
        XCTAssertGreaterThanOrEqual(row.minY, viewport.minY)
        XCTAssertLessThanOrEqual(row.maxY, try XCTUnwrap(bottom["composer"]).minY + 0.5)
        let text = try XCTUnwrap(bottom["text-" + id])
        XCTAssertGreaterThanOrEqual(text.height + 0.5, try XCTUnwrap(bottom["ideal-" + id]).height)
        let lastLine = CGRect(x: text.minX, y: text.maxY - (xxxl ? 32 : 22), width: text.width, height: xxxl ? 32 : 22)
        let ink = try inkBounds(app.screenshot().image, in: lastLine, dark: dark)
        XCTAssertGreaterThan(ink.width, 20)
        XCTAssertLessThan(ink.maxY, try XCTUnwrap(bottom["composer"]).minY)
        try assertTextContrast(app.screenshot().image, region: lastLine, dark: dark)
        try capture("bottom-after-pull", dark: dark, xxxl: xxxl)
        let last = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND value == %@", "Demo 7:", "Active")).firstMatch
        XCTAssertTrue(last.isHittable)
        last.tap()
        let field = app.descendants(matching: .any).matching(identifier: "New reminder").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(status.exists)
        let add = app.buttons["Add reminder"]
        XCTAssertTrue(add.exists)
        XCTAssertGreaterThanOrEqual(add.frame.width, 44)
        XCTAssertGreaterThanOrEqual(add.frame.height, 44)
        XCTAssertFalse(add.isEnabled)
        XCTAssertEqual(try geometry()["boardCompletions"]?.minX, 1)
        try capture("below-capacity", dark: dark, xxxl: xxxl)
        field.tap()
        field.typeText("Remember the weekly review")
        XCTAssertTrue(add.isEnabled)
        app.buttons["Done"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertEqual(field.value as? String, "Remember the weekly review")
        try capture("normal-composer-draft", dark: dark, xxxl: xxxl)
        // Demo submission is intentionally inert; neither button nor Return contacts a store.
        add.tap()
        XCTAssertEqual(field.value as? String, "Remember the weekly review")
        XCTAssertEqual(try geometry()["boardCompletions"]?.minX, 1)
        XCTAssertEqual(try geometry()["authState"], .zero)
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
