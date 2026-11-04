import XCTest
import UIKit

final class BoardEdgeAccessibilityUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }
    private func frames() throws -> [String: CGRect] {
        let data = try XCTUnwrap((app.otherElements["hillclimb.geometry"].value as? String)?.data(using: .utf8))
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [Double]])
        return values.mapValues { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
    }
    private func launch(_ state: String, dark: Bool, xxxl: Bool) {
        app.launchArguments = ["--hillclimb-demo", state == "normal" || state == "error-populated" ? "full" : "empty",
            "--hillclimb-style", dark ? "dark" : "light", "--hillclimb-size", xxxl ? "XXXL" : "default"]
        if state != "normal" { app.launchArguments += ["--hillclimb-board-state", state] }
        app.launch()
        XCTAssertTrue(app.otherElements["hillclimb.geometry"].waitForExistence(timeout: 10))
    }
    private func capture(_ name: String) throws -> UIImage {
        let shot = app.screenshot()
        for attachment in [XCTAttachment(screenshot: shot), XCTAttachment(string: app.debugDescription),
                           XCTAttachment(string: try XCTUnwrap(app.otherElements["hillclimb.geometry"].value as? String))] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        return shot.image
    }
    private func histogram(_ image: UIImage, region: CGRect) throws -> [Int: Int] {
        let cg = try XCTUnwrap(image.cgImage)
        let scale = CGFloat(cg.width) / app.frame.width
        let crop = try XCTUnwrap(cg.cropping(to: region.applying(.init(scaleX: scale, y: scale))))
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: crop.width, height: crop.height,
            bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        var counts: [Int: Int] = [:]
        for i in stride(from: 0, to: bytes.count, by: 4) {
            counts[Int(bytes[i]) << 16 | Int(bytes[i + 1]) << 8 | Int(bytes[i + 2]), default: 0] += 1
        }
        return counts
    }
    private func luminance(_ rgb: Int) -> Double {
        let c = [rgb >> 16 & 255, rgb >> 8 & 255, rgb & 255].map { v -> Double in
            let n = Double(v) / 255
            return n <= 0.04045 ? n / 12.92 : pow((n + 0.055) / 1.055, 2.4)
        }
        return c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722
    }
    private func contrast(_ rgb: Int, dark: Bool) -> Double {
        let l = luminance(rgb)
        return dark ? (l + 0.05) / 0.05 : 1.05 / (l + 0.05)
    }
    private func assertInk(_ image: UIImage, region: CGRect, dark: Bool) throws {
        let counts = try histogram(image, region: region)
        let ink = try XCTUnwrap(counts.filter { contrast($0.key, dark: dark) > 2 }.max(by: { $0.value < $1.value }))
        XCTAssertGreaterThan(ink.value, 20)
        XCTAssertGreaterThanOrEqual(contrast(ink.key, dark: dark), 4.5)
    }
    func testDiagnosticNormalTextContrastMatrix() throws {
        for dark in [false, true] { for xxxl in [false, true] { for state in ["loading", "error-empty"] {
            launch(state, dark: dark, xxxl: xxxl)
            let g = try frames()
            let region = try XCTUnwrap(g[state == "loading" ? "loadingLabel" : "errorDescription"])
            let image = try capture("diagnostic-\(state)-\(dark)-\(xxxl)")
            try assertInk(image, region: region, dark: dark)
            XCTAssertEqual(g["authState"], .zero)
        } } }
    }
    func testTopBandAfterRealPullAndPartialScrollMatrix() throws {
        for dark in [false, true] { for xxxl in [false, true] { for state in ["normal", "error-populated"] {
            launch(state, dark: dark, xxxl: xxxl)
            let initial = try frames()
            let text = try XCTUnwrap(initial["text-00000000-0000-4000-8000-000000000001"])
            try assertInk(capture("fresh-top-\(state)-\(dark)-\(xxxl)"), region: text, dark: dark)
            let list = app.collectionViews.firstMatch
            list.swipeDown()
            XCTAssertEqual(try frames()["refreshState"]?.minX, 0)
            for offset in [CGFloat(83), 47, 61] {
                let viewport = try XCTUnwrap(try frames()["listViewport"])
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: viewport.midX, dy: viewport.midY))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -offset)))
                let g = try frames()
                let v = try XCTUnwrap(g["listViewport"])
                let image = try capture("top-band-\(state)-\(dark)-\(xxxl)-\(Int(offset))")
                let scale = CGFloat(try XCTUnwrap(image.cgImage).width) / app.frame.width
                let band = CGRect(x: v.minX + 68, y: v.minY, width: v.width - 128, height: 14 / scale)
                let pixels = try histogram(image, region: band)
                XCTAssertEqual(pixels.filter { contrast($0.key, dark: dark) > 3 }.values.reduce(0, +), 0,
                               "Crisp preceding-row fragments at viewport top")
                XCTAssertEqual(g["refreshState"]?.minX, 0)
                XCTAssertEqual(g["authState"], .zero)
            }
        } } }
    }
}
