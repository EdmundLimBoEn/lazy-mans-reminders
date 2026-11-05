import XCTest
import UIKit

final class LoginLoadingGeometryUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app.terminate() }

    func testPendingActionDoesNotReflowFollowingControls() throws {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                for password in [false, true] {
                    var baseline: [CGRect] = []
                    for loading in [false, true, false] {
                        app.terminate()
                        let variant = password ? (loading ? "password-loading" : "password") : (loading ? "loading" : "default")
                        app.launchArguments = ["--hillclimb-demo", "signin", "--hillclimb-style", style,
                            "--hillclimb-size", size, "--hillclimb-signin-variant", variant,
                            "--hillclimb-signin-appearance", "enabled", "--hillclimb-signin-filled", "yes"]
                        app.launch()
                        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 10))
                        let title = password ? "Sign In with Password" : "Send Sign-In Link"
                        let action = app.buttons[loading ? title + ", in progress" : title]
                        XCTAssertTrue(action.exists)
                        XCTAssertEqual(action.isEnabled, !loading)
                        let alternate = app.buttons[password ? "Use a Sign-In Link Instead" : "Use an Existing Password"]
                        let frames = [action.frame, alternate.frame, app.buttons["Privacy"].frame]
                        XCTAssertGreaterThanOrEqual(action.frame.height, 44)
                        if baseline.isEmpty { baseline = frames }
                        for (before, after) in zip(baseline, frames) {
                            XCTAssertEqual(before.minY, after.minY, accuracy: 1.0 / 3)
                            XCTAssertEqual(before.height, after.height, accuracy: 1.0 / 3)
                            XCTAssertEqual(before.width, after.width, accuracy: 1.0 / 3)
                        }
                        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                        proof.name = "loading-stability-\(style)-\(size)-\(variant)"
                        proof.lifetime = .keepAlways
                        add(proof)
                        if loading { try assertSpinnerInk(action.frame) }
                    }
                }
            }
        }
    }

    private func assertSpinnerInk(_ frame: CGRect) throws {
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let scale = CGFloat(image.width) / app.frame.width
        let center = CGRect(x: frame.midX - 12, y: frame.midY - 12, width: 24, height: 24)
        let crop = try XCTUnwrap(image.cropping(to: center.applying(CGAffineTransform(scaleX: scale, y: scale))))
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: crop.width, height: crop.height,
            bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        var histogram: [Int: Int] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            histogram[Int(pixels[i]) << 16 | Int(pixels[i+1]) << 8 | Int(pixels[i+2]), default: 0] += 1
        }
        let backgroundCount = try XCTUnwrap(histogram.values.max())
        XCTAssertGreaterThan(crop.width * crop.height - backgroundCount, 100, "Native spinner must render ink")
    }
}
