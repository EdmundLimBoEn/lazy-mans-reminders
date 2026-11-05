import XCTest
import SwiftUI
@testable import LazyMansReminders

final class ActivityLayoutTests: XCTestCase {
    @MainActor func testRenderedLastLineFitsBothNativeSurfaceBudgets() throws {
        for size in [DynamicTypeSize.large, .xxxLarge, .accessibility5] {
            for surface in [ReminderActivityLayout.Surface.lockScreen, .island] {
                for scheme in [ColorScheme.light, .dark] {
                    let reminder = Reminder(id: UUID(), userID: UUID(),
                        text: (1...10).map { "Demo \($0): " + String(repeating: "Review sample notes. ", count: 8) }.joined(separator: "\n"),
                        sortOrder: 0, isDone: false, createdAt: .now)
                    let state = ReminderActivityPresentation.state(from: [reminder], limit: 6)
                    let view = ReminderActivityLinesView(
                        lines: state.lines,
                        hiddenLineCount: state.hiddenLineCount,
                        surface: surface)
                        .environment(\.dynamicTypeSize, size)
                        .environment(\.colorScheme, scheme)
                        .frame(width: 340)
                        .background(scheme == .dark ? Color.black : Color.white)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 1
                    let image = try XCTUnwrap(renderer.uiImage?.cgImage)
                    XCTAssertLessThanOrEqual(CGFloat(image.height), ReminderActivityLayout.availableHeight(surface) + 1,
                        "Rendered rows exceed native surface budget at \(size)")
                    let attachment = XCTAttachment(image: UIImage(cgImage: image))
                    attachment.name = "Activity-\(surface)-\(size)-\(scheme)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    // Read the raster, not just allocated frames: each row, including
                    // the overflow row, must retain visible foreground ink.
                    let bytesPerRow = image.width * 4
                    var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
                    let context = try XCTUnwrap(CGContext(data: &pixels, width: image.width, height: image.height,
                        bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                    let pointSize = UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: 15,
                        compatibleWith: UITraitCollection(preferredContentSizeCategory:
                            size == .large ? .large : size == .xxxLarge ? .extraExtraExtraLarge : .accessibilityExtraExtraExtraLarge))
                    let expected = ReminderActivityLayout.lineLimit(pointSize: pointSize, surface: surface)
                    let rowHeight = Int(ReminderActivityLayout.rowHeight(pointSize: pointSize))
                    let stride = rowHeight + Int(LockScreenLineBudget.lineSpacing)
                    for row in 0..<expected {
                        let inkRows = (row * stride..<min(image.height, row * stride + rowHeight)).filter { y in
                            (0..<image.width).filter { x in
                                let offset = y * bytesPerRow + x * 4
                                let luminance = Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])
                                return scheme == .dark ? luminance > 500 : luminance < 260
                            }.count > 3
                        }.count
                        // A digit such as 5 can have disconnected ink bands. Check
                        // each allocated row's actual ink height, including the footer.
                        XCTAssertGreaterThanOrEqual(inkRows, Int(pointSize * 0.55),
                            "Missing or clipped row \(row) in rendered \(surface), \(size), \(scheme)")
                    }
                }
            }
        }
    }

    func testSurfaceOverflowRetainsExistingCopy() {
        XCTAssertEqual(ReminderActivityPresentation.surfaceLines(["One", "Two", "Three", "Four"], limit: 3),
                       ["One", "Two", "+2 more"])
        XCTAssertEqual(ReminderActivityPresentation.surfaceLines([], limit: 1), ["Nothing to remember"])
    }
}
