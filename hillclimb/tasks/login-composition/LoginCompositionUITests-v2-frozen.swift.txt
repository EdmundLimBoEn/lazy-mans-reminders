import XCTest
import UIKit

final class LoginCompositionUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app.terminate() }

    private func launch(_ style: String, _ size: String, password: Bool, filled: Bool) {
        app.terminate()
        app.launchArguments = ["--hillclimb-demo", "signin", "--hillclimb-style", style,
            "--hillclimb-size", size, "--hillclimb-signin-variant", password ? "password" : "default",
            "--hillclimb-signin-appearance", "enabled"]
        if filled { app.launchArguments += ["--hillclimb-signin-filled", "yes"] }
        app.launch()
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 10))
    }

    func testNativeInlineHierarchyAndFilledPrimaryActionMatrix() throws {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                for password in [false, true] {
                    for filled in [false, true] {
                        launch(style, size, password: password, filled: filled)
                        let nav = app.navigationBars["Sign In"]
                        let brand = app.staticTexts["Notepad"]
                        let apple = app.buttons["signin.apple"]
                        let google = app.buttons["Sign in with Google"]
                        let submit = app.buttons[password ? "Sign In with Password" : "Send Sign-In Link"]
                        XCTAssertLessThanOrEqual(nav.frame.height, 60)
                        XCTAssertGreaterThanOrEqual(brand.frame.minY, nav.frame.maxY)
                        XCTAssertGreaterThanOrEqual(brand.frame.height, size == "XXXL" ? 30 : 26)
                        XCTAssertEqual(apple.frame.minX, google.frame.minX, accuracy: 1)
                        XCTAssertEqual(apple.frame.width, google.frame.width, accuracy: 1)
                        XCTAssertEqual(apple.frame.height, google.frame.height, accuracy: 1)
                        XCTAssertEqual(app.otherElements["signin.emailTarget"].frame.height, 48, accuracy: 1e-9)
                        XCTAssertEqual(submit.isEnabled, filled)
                        XCTAssertEqual(app.textFields["Email address"].value as? String, "you@example.com")
                        XCTAssertEqual(app.buttons["Clear text"].exists, filled)
                        XCTAssertEqual(app.secureTextFields.count, password ? 1 : 0)
                        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                        proof.name = "composition-\(style)-\(size)-\(password ? "password" : "default")-\(filled ? "filled" : "empty")"
                        proof.lifetime = .keepAlways
                        add(proof)
                        if !filled { try assertNeutralPrompt(app.textFields["Email address"].frame) }
                        if filled {
                            try assertPrimaryContrast(submit.frame, name: try XCTUnwrap(proof.name))
                            submit.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                            XCTAssertTrue(nav.exists)
                            XCTAssertFalse(app.keyboards.firstMatch.exists)
                            XCTAssertEqual(submit.isEnabled, true)
                        }
                    }
                }
            }
        }
    }
    private func assertPrimaryContrast(_ frame: CGRect, name: String) throws {
        let histogram = try nativeHistogram(frame.insetBy(dx: 16, dy: 5))
        func luminance(_ rgb: Int) -> Double {
            let c = [rgb >> 16 & 255, rgb >> 8 & 255, rgb & 255].map { value -> Double in
                let s = Double(value) / 255
                return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
        }
        let background = try XCTUnwrap(histogram.max { $0.value < $1.value }).key
        let bg = luminance(background)
        let ink = try XCTUnwrap(histogram.filter { rgb, _ in
            let c = [rgb >> 16 & 255, rgb >> 8 & 255, rgb & 255]
            return (c.max()! - c.min()!) < 10 && abs(luminance(rgb) - bg) > 0.05
        }.max { $0.value < $1.value })
        XCTAssertGreaterThan(ink.value, 100, "Native solid label glyphs")
        let fg = luminance(ink.key)
        let contrast = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05)
        XCTAssertGreaterThanOrEqual(contrast, 4.5)
        let proof = XCTAttachment(string: "background=\(background) ink=\(ink.key) pixels=\(ink.value) contrast=\(contrast) frame=\(frame)")
        proof.name = name + "-primary-contrast"; proof.lifetime = .keepAlways; add(proof)
    }

    private func nativeHistogram(_ frame: CGRect) throws -> [Int: Int] {
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let scale = CGFloat(image.width) / app.frame.width
        let crop = try XCTUnwrap(image.cropping(to: frame.applying(CGAffineTransform(scaleX: scale, y: scale))))
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: crop.width, height: crop.height,
            bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        var colors: [Int: Int] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            colors[Int(pixels[i]) << 16 | Int(pixels[i + 1]) << 8 | Int(pixels[i + 2]), default: 0] += 1
        }
        return colors
    }

    private func assertNeutralPrompt(_ frame: CGRect) throws {
        let colors = try nativeHistogram(frame.insetBy(dx: 5, dy: 5))
        let background = try XCTUnwrap(colors.max { $0.value < $1.value }).key
        func channels(_ rgb: Int) -> [Int] { [rgb >> 16 & 255, rgb >> 8 & 255, rgb & 255] }
        let bg = channels(background).reduce(0, +) / 3
        let ink = try XCTUnwrap(colors.filter { abs(channels($0.key).reduce(0, +) / 3 - bg) > 30 }
            .max { $0.value < $1.value })
        let rgb = channels(ink.key)
        XCTAssertGreaterThan(ink.value, 100)
        XCTAssertLessThanOrEqual(try XCTUnwrap(rgb.max()) - XCTUnwrap(rgb.min()), 10)
        let proof = XCTAttachment(string: "background=\(background) promptRGB=\(rgb) solidPixels=\(ink.value) frame=\(frame)")
        proof.name = "composition-neutral-prompt"; proof.lifetime = .keepAlways; add(proof)
    }

}
