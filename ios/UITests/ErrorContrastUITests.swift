import XCTest
import UIKit

final class ErrorContrastUITests: XCTestCase {
    private let app = XCUIApplication()
    private let signInError = "Couldn’t sign in. Check your email and password, or use a sign-in link. If you’re offline, reconnect and try again."

    override func setUpWithError() throws { continueAfterFailure = false }

    func testLightDefaultErrors() throws { try verify(style: "light", size: "default") }
    func testLightXXXLErrors() throws { try verify(style: "light", size: "XXXL") }
    func testDarkDefaultErrors() throws { try verify(style: "dark", size: "default") }
    func testDarkXXXLErrors() throws { try verify(style: "dark", size: "XXXL") }

    private func verify(style: String, size: String) throws {
        app.launchArguments = ["--hillclimb-demo", "signin", "--hillclimb-style", style,
            "--hillclimb-size", size, "--hillclimb-signin-variant", "error"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 10))
        let message = app.staticTexts[signInError]
        if !message.isHittable { app.swipeUp() }
        try raster(message, name: "signin-\(style)-\(size)-error")
        app.textFields["Email address"].tap()
        app.textFields["Email address"].typeText("x")
        XCTAssertFalse(message.exists)
        app.buttons["Done"].tap()
        capture("signin-\(style)-\(size)-cleared")
        app.terminate()
        app.launch()
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        if !message.isHittable { app.swipeUp() }
        try raster(message, name: "signin-\(style)-\(size)-reappeared")
        for state in ["error", "refresh-error"] {
            app.launchArguments = ["--hillclimb-demo", "account", "--hillclimb-style", style,
                "--hillclimb-size", size, "--hillclimb-account-appearance", "enabled",
                "--hillclimb-account-state", state]
            app.launch()
            XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 10))
            let error = app.staticTexts[state == "error" ? "account.error" : "account.refreshResult"]
            let exact = state == "error" ? "Couldn’t disconnect notifications. You’re still signed in. Reconnect and try signing out again before giving this iPhone to someone else." : "Couldn’t refresh. Your saved board is still available."
            let list = app.collectionViews["account.settings"]
            if !error.isHittable { list.swipeUp(velocity: .slow) }
            XCTAssertEqual(error.label, exact)
            try raster(error, name: "account-\(state)-\(style)-\(size)-initial", frame: error.frame.insetBy(dx: 8, dy: 4))
            let retry = app.buttons["Refresh Board Now"]
            if !retry.isHittable { list.swipeUp(velocity: .slow) }
            retry.tap()
            XCTAssertFalse(error.exists)
            capture("account-\(state)-\(style)-\(size)-cleared")
            retry.tap()
            XCTAssertTrue(error.waitForExistence(timeout: 3))
            if state == "error" && error.frame.minY < app.navigationBars.firstMatch.frame.maxY { list.swipeDown(velocity: .slow) }
            try raster(error, name: "account-\(state)-\(style)-\(size)-reappeared", frame: error.frame.insetBy(dx: 8, dy: 4))
            for _ in 0..<8 {
                if app.buttons["Delete Account…"].isHittable { break }
                list.swipeUp(velocity: .slow)
            }
            let delete = app.buttons["Delete Account…"]
            XCTAssertTrue(delete.isEnabled)
            // Exclude the separately coloured trash glyph using the native title geometry.
            let probe = app.descendants(matching: .any)["account.geometry"]
            let frames = try XCTUnwrap(JSONSerialization.jsonObject(with: Data((try XCTUnwrap(probe.value as? String)).utf8)) as? [String: [Double]])
            let f = try XCTUnwrap(frames["Delete Account….title"])
            try raster(delete, name: "account-delete-\(state)-\(style)-\(size)", frame: CGRect(x: f[0], y: f[1], width: f[2], height: f[3]))
            delete.tap()
            XCTAssertFalse(app.alerts["Delete Account?"].exists)
            app.terminate()
        }
    }


    private func capture(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func raster(_ element: XCUIElement, name: String, frame: CGRect? = nil) throws {
        try assertNativeErrorRaster(element, app: app, name: name, frame: frame)
    }
}

extension XCTestCase {
    func assertNativeErrorRaster(_ element: XCUIElement, app: XCUIApplication, name: String, frame: CGRect? = nil) throws {
        XCTAssertTrue(element.isHittable, name)
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let scale = CGFloat(image.width) / app.frame.width
        let bounds = frame ?? element.frame
        XCTAssertGreaterThanOrEqual(bounds.minY, app.navigationBars.firstMatch.frame.maxY)
        XCTAssertLessThan(bounds.maxY, app.frame.maxY - 34)
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: bounds.minX * scale, y: bounds.minY * scale, width: bounds.width * scale, height: bounds.height * scale)))
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        func key(_ x: Int, _ y: Int) -> Int {
            let i = (y * crop.width + x) * 4
            return Int(bytes[i]) << 16 | Int(bytes[i+1]) << 8 | Int(bytes[i+2])
        }
        var solid: [Int: Int] = [:]
        // Uniform 2x2 interiors prevent antialiased edge minima from masquerading as ink.
        for y in 0..<(crop.height-1) { for x in 0..<(crop.width-1) {
            let k = key(x,y)
            if k == key(x+1,y) && k == key(x,y+1) && k == key(x+1,y+1) { solid[k, default: 0] += 1 }
        }}
        func luminance(_ k: Int) -> Double {
            func linear(_ c: Int) -> Double { let s = Double(c)/255; return s <= 0.04045 ? s/12.92 : pow((s+0.055)/1.055, 2.4) }
            return 0.2126*linear((k>>16)&255) + 0.7152*linear((k>>8)&255) + 0.0722*linear(k&255)
        }
        let background = try XCTUnwrap(solid.max { $0.value < $1.value })
        let ink = try XCTUnwrap(solid.filter { abs(luminance($0.key)-luminance(background.key)) > 0.1 }.max { $0.value < $1.value })
        XCTAssertGreaterThan(ink.value, 30)
        let a = luminance(background.key), b = luminance(ink.key)
        let ratio = (max(a,b)+0.05)/(min(a,b)+0.05)
        let proof = XCTAttachment(string: "\(name) background=\(background) ink=\(ink) ratio=\(ratio) frame=\(bounds)")
        proof.name = name + "-raster"; proof.lifetime = .keepAlways; add(proof)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, name)
    }
}
