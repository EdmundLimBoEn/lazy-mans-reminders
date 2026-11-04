import XCTest
import UIKit

final class AccountChromeUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }

    func testNativeTitleBands() throws {
        for size in ["default", "XXXL"] {
            for style in ["light", "dark"] {
                launch(style, size)
                let bar = app.navigationBars["Account"]
                XCTAssertLessThan(bar.frame.minY, 160)
                capture("\(style)-\(size)-large-top")
                let list = app.collectionViews["account.settings"]
                list.swipeUp(velocity: .slow)
                try titleBand("\(style)-\(size)-large-scrolled")
                let grabber = app.buttons["Sheet Grabber"]
                grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 201, dy: 446)))
                usleep(900_000)
                XCTAssertGreaterThan(bar.frame.minY, 400)
                capture("\(style)-\(size)-medium")
                list.swipeUp(velocity: .slow)
                if bar.frame.minY < 400 {
                    grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                        .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 201, dy: 446)))
                    usleep(900_000)
                }
                XCTAssertGreaterThan(bar.frame.minY, 400)
                try titleBand("\(style)-\(size)-medium-scrolled")
                let done = bar.buttons["Done"]
                done.tap()
                app.buttons["Account"].tap()
                XCTAssertLessThan(bar.frame.minY, 160)
                grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 201, dy: 446)))
                usleep(900_000)
                XCTAssertGreaterThan(bar.frame.minY, 400)
                capture("\(style)-\(size)-medium-top")
                app.terminate()
            }
        }
    }

    func testGuidanceContentGeometryAndInk() throws {
        var heights: [String: Double] = [:]
        let original = "iOS limits each Live Activity to eight hours. We try to renew it automatically, but renewal can be delayed. Background App Refresh helps sync when iOS allows; it does not keep the app running. Leave the app in the background instead of swiping it away. Use a widget for reminders you want visible overnight."
        for size in ["default", "XXXL"] {
            for style in ["light", "dark"] {
                launch(style, size)
                let first = app.staticTexts["account.guidance.activity"]
                let second = app.staticTexts["account.guidance.background"]
                let list = app.collectionViews["account.settings"]
                for detent in ["large", "medium"] {
                    if detent == "medium" {
                        let grabber = app.buttons["Sheet Grabber"]
                        grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 201, dy: 446)))
                    }
                    for _ in 0..<12 {
                        let frames = try geometry()
                        if let measured = frames["persistence.footer"] {
                            let f = first.exists && second.exists
                                ? [Double(first.frame.minX), Double(first.frame.minY), Double(first.frame.width), Double(second.frame.maxY - first.frame.minY)]
                                : measured
                            let top = app.navigationBars["Account"].frame.maxY + 12
                            let bottom = app.frame.maxY - 42
                            if f[1] >= top && f[1] + f[3] <= bottom { break }
                            let delta = min(130, max(-130, (top + bottom) / 2 - (f[1] + f[3] / 2)))
                            let origin = app.coordinate(withNormalizedOffset: .zero)
                            origin.withOffset(CGVector(dx: 201, dy: (top + bottom) / 2))
                                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: 201, dy: (top + bottom) / 2 + delta)), withVelocity: .slow, thenHoldForDuration: 0.2)
                            usleep(300_000)
                        } else { list.swipeUp(velocity: .slow) }
                    }
                    XCTAssertTrue(first.isHittable); XCTAssertTrue(second.isHittable)
                    XCTAssertEqual([first.label, second.label].joined(separator: " "), original)
                    XCTAssertEqual(app.staticTexts.matching(identifier: "account.guidance.activity").count, 1)
                    XCTAssertEqual(app.staticTexts.matching(identifier: "account.guidance.background").count, 1)
                    let f = try geometry()
                    let a = try XCTUnwrap(f["persistence.activity"])
                    let b = try XCTUnwrap(f["persistence.background"])
                    let whole = try XCTUnwrap(f["persistence.footer"])
                    if detent == "medium" { XCTAssertGreaterThan(app.navigationBars["Account"].frame.minY, 400) }
                    if detent == "large" {
                        if size == "default" { heights[style] = whole[3] }
                        else { XCTAssertGreaterThan(whole[3], try XCTUnwrap(heights[style])) }
                    }
                    XCTAssertEqual(b[1] - a[1] - a[3], 6, accuracy: 0.5)
                    XCTAssertEqual(whole[3], a[3] + b[3] + 6, accuracy: 1)
                    XCTAssertGreaterThanOrEqual(a[1], app.navigationBars["Account"].frame.maxY + 8)
                    XCTAssertLessThanOrEqual(b[1] + b[3], app.frame.maxY - 42)
                    for (element, frame) in [(first, a), (second, b)] {
                        XCTAssertEqual(element.frame.height, frame[3], accuracy: 1)
                        try ink(frame, name: "\(style)-\(size)-\(detent)-paragraph")
                    }
                    let proof = XCTAttachment(string: "labels=\([first.label, second.label]) frames=\(f) bar=\(app.navigationBars["Account"].frame)")
                    proof.name = "\(style)-\(size)-\(detent)-guidance-proof"; proof.lifetime = .keepAlways; add(proof)
                    capture("\(style)-\(size)-\(detent)-guidance")
                }
                app.terminate()
            }
        }
    }

    func testNativeRecoveryRemainsInert() throws {
        for size in ["default", "XXXL"] {
            for style in ["light", "dark"] {
                app.launchArguments = ["--hillclimb-demo", "account", "--hillclimb-style", style,
                    "--hillclimb-size", size, "--hillclimb-account-appearance", "enabled", "--hillclimb-account-state", "refresh-error"]
                app.launch()
                let bar = app.navigationBars["Account"]
                XCTAssertTrue(bar.waitForExistence(timeout: 10))
                let list = app.collectionViews["account.settings"]
                let retry = app.buttons["Refresh Board Now"]
                if !retry.isHittable { list.swipeUp(velocity: .slow) }
                XCTAssertTrue(app.staticTexts["account.refreshResult"].exists)
                capture("\(style)-\(size)-error")
                retry.tap()
                XCTAssertFalse(app.staticTexts["account.refreshResult"].exists)
                capture("\(style)-\(size)-recovered")
                app.buttons["Open App Settings"].tap()
                XCTAssertTrue(bar.exists)
                for _ in 0..<8 {
                    if app.buttons["Delete Account…"].isHittable { break }
                    list.swipeUp(velocity: .slow)
                }
                app.buttons["Delete Account…"].tap()
                XCTAssertFalse(app.alerts["Delete Account?"].exists)
                app.terminate()
            }
        }
    }

    private func geometry() throws -> [String: [Double]] {
        let value = try XCTUnwrap(app.descendants(matching: .any)["account.geometry"].value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: [Double]])
    }

    private func ink(_ f: [Double], name: String) throws {
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let scale = Double(image.width) / app.frame.width
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: f[0]*scale, y: f[1]*scale, width: f[2]*scale, height: f[3]*scale)))
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: crop.width*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        func key(_ x: Int, _ y: Int) -> Int {
            let i = (y*crop.width+x)*4
            return Int(bytes[i])<<16 | Int(bytes[i+1])<<8 | Int(bytes[i+2])
        }
        func luminance(_ k: Int) -> Double {
            func linear(_ c: Int) -> Double { let v = Double(c)/255; return v <= 0.04045 ? v/12.92 : pow((v+0.055)/1.055, 2.4) }
            return 0.2126*linear((k>>16)&255)+0.7152*linear((k>>8)&255)+0.0722*linear(k&255)
        }
        var colors: [Int: Int] = [:]
        for y in 0..<(crop.height-1) { for x in 0..<(crop.width-1) {
            let k = key(x,y)
            if k == key(x+1,y) && k == key(x,y+1) && k == key(x+1,y+1) { colors[k, default: 0] += 1 }
        }}
        let background = try XCTUnwrap(colors.max { $0.value < $1.value }).key
        let text = try XCTUnwrap(colors.filter { abs(luminance($0.key)-luminance(background)) > 0.1 }.max { $0.value < $1.value }).key
        let a = luminance(background), b = luminance(text)
        let ratio = (max(a,b)+0.05)/(min(a,b)+0.05)
        XCTAssertGreaterThanOrEqual(ratio, 7)
        // Both the first and final line must have actual native ink, independent of AX frames.
        for band in [0..<(crop.height/3), (crop.height*2/3)..<crop.height] {
            var count = 0
            for y in band { for x in 0..<crop.width {
                if abs(luminance(key(x,y))-a) > 0.25 { count += 1 }
            }}
            XCTAssertGreaterThan(count, 40)
        }
        let proof = XCTAttachment(string: "\(name) contrast=\(ratio) frame=\(f)")
        proof.name = name + "-ink"; proof.lifetime = .keepAlways; add(proof)
    }

    private func launch(_ style: String, _ size: String) {
        app.launchArguments = ["--hillclimb-demo", "account", "--hillclimb-style", style,
                               "--hillclimb-size", size, "--hillclimb-account-appearance", "enabled"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 10))
    }
    private func capture(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func titleBand(_ name: String) throws {
        let bar = app.navigationBars["Account"]
        XCTAssertTrue(bar.buttons["Done"].isHittable)
        let title = bar.staticTexts["Account"]
        XCTAssertTrue(title.exists)
        let a = XCTAttachment(string: "title=\(title.frame) bar=\(bar.frame) AX=\(bar.debugDescription)")
        a.name = name + "-geometry"; a.lifetime = .keepAlways; add(a)
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let scale = CGFloat(image.width) / app.frame.width
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: 28 * scale, y: title.frame.minY * scale,
            width: (title.frame.minX - 40) * scale, height: title.frame.height * scale)))
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: crop.width, height: crop.height, bitsPerComponent: 8,
            bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        func linear(_ c: UInt8) -> Double { let s = Double(c)/255; return s <= 0.04045 ? s/12.92 : pow((s+0.055)/1.055, 2.4) }
        var maximum = 1.0
        for y in 0..<crop.height {
            let values = (0..<crop.width).map { x -> Double in
                let i = (y * crop.width + x) * 4
                return 0.2126*linear(bytes[i]) + 0.7152*linear(bytes[i+1]) + 0.0722*linear(bytes[i+2])
            }
            let background = values.sorted()[values.count/2]
            for value in values { maximum = max(maximum, (max(value, background)+0.05)/(min(value, background)+0.05)) }
        }
        let pixels = XCTAttachment(string: "non-title maximum contrast=\(maximum) title=\(title.frame)")
        pixels.name = name + "-title-ink"; pixels.lifetime = .keepAlways; add(pixels)
        capture(name)
    }
}
