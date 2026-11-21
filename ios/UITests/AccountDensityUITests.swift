import XCTest
import UIKit

final class AccountDensityUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAdjacentSectionRhythm() throws {
        for size in ["default", "XXXL"] {
            for style in ["light", "dark"] {
                app.launchArguments = ["--hillclimb-demo", "account", "--hillclimb-style", style,
                    "--hillclimb-size", size, "--hillclimb-account-appearance", "enabled"]
                app.launch()
                let bar = app.navigationBars["Account"]
                XCTAssertTrue(bar.waitForExistence(timeout: 10))
                let signOut = app.buttons["Sign Out"]
                let privacy = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND (elementType == %d OR elementType == %d)", "Privacy", XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.link.rawValue)).firstMatch
                for _ in 0..<12 {
                    if signOut.exists && privacy.exists && signOut.frame.minY > bar.frame.maxY + 8 && privacy.frame.maxY < app.frame.maxY - 42 { break }
                    try scrollUp()
                }
                XCTAssertTrue(signOut.isHittable)
                XCTAssertTrue(privacy.isHittable)
                let probe = try XCTUnwrap(app.descendants(matching: .any)["account.geometry"].value as? String)
                let frames = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(probe.utf8)) as? [String: [Double]])
                let footer = try XCTUnwrap(frames["persistence.footer"])
                let boundary = signOut.frame.minY - footer[1] - footer[3]
                XCTAssertGreaterThanOrEqual(boundary, 16)
                let gap = privacy.frame.minY - signOut.frame.maxY
                XCTAssertGreaterThanOrEqual(gap, 16)
                XCTAssertGreaterThanOrEqual(signOut.frame.height, 44)
                XCTAssertGreaterThanOrEqual(privacy.frame.height, 44)
                let proof = XCTAttachment(string: "gap=\(gap) boundary=\(boundary) footer=\(footer) signOut=\(signOut.frame) privacy=\(privacy.frame) bar=\(bar.frame)")
                proof.name = "\(style)-\(size)-section-rhythm"; proof.lifetime = .keepAlways; add(proof)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "\(style)-\(size)-section-rhythm"; shot.lifetime = .keepAlways; add(shot)
                signOut.tap()
                XCTAssertFalse(app.alerts["Sign Out?"].exists)
                privacy.tap()
                XCTAssertTrue(bar.exists)
                app.terminate()
            }
        }
    }

    func testExplanatoryInkAndPassiveIdentity() throws {
        for size in ["default", "XXXL"] {
            for style in ["light", "dark"] {
                app.launchArguments = ["--hillclimb-demo", "account", "--hillclimb-style", style,
                    "--hillclimb-size", size, "--hillclimb-account-appearance", "enabled"]
                app.launch()
                let bar = app.navigationBars["Account"]
                XCTAssertTrue(bar.waitForExistence(timeout: 10))
                let identity = try XCTUnwrap(try geometry()["identity.row"])
                let image = try XCTUnwrap(app.screenshot().image.cgImage)
                let scale = Double(image.width) / app.frame.width
                func pixel(_ x: Double, _ y: Double) throws -> [UInt8] {
                    let crop = try XCTUnwrap(image.cropping(to: CGRect(x: x*scale, y: y*scale, width: 1, height: 1)))
                    var bytes = [UInt8](repeating: 0, count: 4)
                    let c = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    c.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                    return Array(bytes.prefix(3))
                }
                let inside = try pixel(350, identity[1] + identity[3]/2)
                let outside = try pixel(8, identity[1] + identity[3]/2)
                for i in 0..<3 { XCTAssertEqual(Int(inside[i]), Int(outside[i]), accuracy: 2) }
                let identityProof = XCTAttachment(string: "frame=\(identity) inside=\(inside) outside=\(outside)")
                identityProof.name = "\(style)-\(size)-identity-background"; identityProof.lifetime = .keepAlways; add(identityProof)
                for key in ["notifications.footer", "home.helper", "lock.helper", "widget.helper", "feedback.footer", "version.footer"] {
                    if key == "home.helper" {
                        let disclosure = app.buttons["Add a lasting widget"]
                        for _ in 0..<8 {
                            if disclosure.isHittable { break }
                            try scrollUp()
                        }
                        disclosure.tap()
                    }
                    for _ in 0..<16 {
                        if let f = try geometry()[key] {
                            let top = bar.frame.maxY + 12, bottom = app.windows.firstMatch.frame.maxY - 34
                            if f[1] >= top && f[1]+f[3] <= bottom { break }
                            let delta = min(130, max(-130, (top+bottom)/2 - f[1] - f[3]/2))
                            let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
                            origin.withOffset(CGVector(dx: 201, dy: (top+bottom)/2)).press(forDuration: 0.1,
                                thenDragTo: origin.withOffset(CGVector(dx: 201, dy: (top+bottom)/2 + delta)), withVelocity: .slow, thenHoldForDuration: 0.2)
                            usleep(300_000)
                        } else { try scrollUp() }
                    }
                    let f = try XCTUnwrap(try geometry()[key])
                    XCTAssertGreaterThanOrEqual(f[1], bar.frame.maxY + 8)
                    XCTAssertLessThanOrEqual(f[1]+f[3], app.frame.maxY - 34)
                    try ink(f, name: "\(style)-\(size)-\(key)")
                    let shot = XCTAttachment(screenshot: app.screenshot())
                    shot.name = "\(style)-\(size)-\(key)"; shot.lifetime = .keepAlways; add(shot)
                }
                app.terminate()
            }
        }
    }

    private func scrollUp() throws {
        let window = app.windows.firstMatch
        let frame = window.frame
        XCTAssertTrue(frame.minX.isFinite && frame.minY.isFinite && frame.width > 0 && frame.height > 0)
        let origin = window.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: frame.width/2, dy: frame.height*0.75)).press(forDuration: 0.1,
            thenDragTo: origin.withOffset(CGVector(dx: frame.width/2, dy: frame.height*0.35)), withVelocity: .slow, thenHoldForDuration: 0.2)
        usleep(300_000)
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

}
