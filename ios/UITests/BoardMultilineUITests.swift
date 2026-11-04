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
