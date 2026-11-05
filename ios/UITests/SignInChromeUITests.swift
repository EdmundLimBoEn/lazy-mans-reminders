import XCTest
import UIKit

final class SignInChromeUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }
    private let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    private var originals: [String: Bool] = [:]
    override func tearDownWithError() throws {
        app.terminate()
        if !originals.isEmpty { try configure(restoring: true) }
        settings.terminate()
    }

    func testCombinedSettingsPopulatedPasswordKeepsVisualName() throws {
        try configure(restoring: false)
        settings.terminate()
        verifyPopulatedPassword(prefix: "combined")
    }

    private func configure(restoring: Bool) throws {
        settings.launch()
        for _ in 0..<5 {
            if settings.staticTexts["Accessibility"].exists { break }
            let back = settings.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
        }
        settings.staticTexts["Accessibility"].tap()
        for (page, labels) in [("Motion", ["Reduce Motion"]), ("Display & Text Size", ["Reduce Transparency", "Increase Contrast"])] {
            settings.staticTexts[page].tap()
            if !restoring && page == "Motion" {
                originals["Auto-Play Message Effects"] = try XCTUnwrap(settings.switches["Auto-Play Message Effects"].value as? String) == "1"
            }
            let beforeValues = settings.switches.allElementsBoundByIndex.map { "\($0.label)=\($0.value ?? "nil")" }.joined(separator: "\n")
            let beforeProof = XCTAttachment(string: "page=\(page) stage=\(restoring ? "before-restore" : "original")\n" + beforeValues)
            beforeProof.name = "settings-values-\(page)-\(restoring ? "before-restore" : "original")"
            beforeProof.lifetime = .keepAlways; add(beforeProof)
            for label in labels {
                let toggle = settings.switches[label]
                XCTAssertTrue(toggle.waitForExistence(timeout: 5))
                let before = try XCTUnwrap(toggle.value as? String) == "1"
                if !restoring { originals[label] = before }
                let desired = restoring ? try XCTUnwrap(originals[label]) : true
                if before != desired { toggle.switches.firstMatch.tap() }
                XCTAssertEqual(toggle.value as? String, desired ? "1" : "0")
            }
            if restoring && page == "Motion" {
                let effects = settings.switches["Auto-Play Message Effects"]
                let desired = try XCTUnwrap(originals["Auto-Play Message Effects"])
                if (effects.value as? String == "1") != desired { effects.switches.firstMatch.tap() }
                XCTAssertEqual(effects.value as? String, desired ? "1" : "0")
            }
            let afterValues = settings.switches.allElementsBoundByIndex.map { "\($0.label)=\($0.value ?? "nil")" }.joined(separator: "\n")
            let afterProof = XCTAttachment(string: "page=\(page) stage=\(restoring ? "restored" : "enabled")\n" + afterValues)
            afterProof.name = "settings-values-\(page)-\(restoring ? "restored" : "enabled")"
            afterProof.lifetime = .keepAlways; add(afterProof)
            let proof = XCTAttachment(string: "originals=\(originals) restoring=\(restoring)\n" + settings.debugDescription)
            proof.name = "chrome-settings-\(page)-\(restoring ? "restored" : "enabled")"
            proof.lifetime = .keepAlways; add(proof)
            settings.navigationBars.buttons.firstMatch.tap()
        }
    }

    private func launch(_ style: String, _ size: String, _ variant: String, enabled: Bool = false, bottom: Bool = false) {
        app.terminate()
        app.launchArguments = ["--hillclimb-demo", "signin", "--hillclimb-style", style,
            "--hillclimb-size", size, "--hillclimb-signin-variant", variant]
        if enabled { app.launchArguments += ["--hillclimb-signin-appearance", "enabled"] }
        if bottom { app.launchArguments += ["--hillclimb-signin-scroll", "bottom"] }
        app.launch()
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 10))
    }

    private func capture(_ name: String, details: String = "") {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
        let geometry = XCTAttachment(string: details + "\n" + app.debugDescription)
        geometry.name = name + "-geometry"; geometry.lifetime = .keepAlways; add(geometry)
    }

    private func ink(_ frame: CGRect, style: String) -> Int {
        let image = app.screenshot().image.cgImage!
        let scale = CGFloat(image.width) / app.frame.width
        let rect = CGRect(x: frame.minX * scale, y: frame.minY * scale,
                          width: frame.width * scale, height: frame.height * scale)
        guard let crop = image.cropping(to: rect) else { XCTFail("Missing raster"); return 0 }
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = CGContext(data: &bytes, width: crop.width, height: crop.height,
            bitsPerComponent: 8, bytesPerRow: crop.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        return stride(from: 0, to: bytes.count, by: 4).filter { index in
            let rgb = bytes[index..<index+3]
            return style == "light" ? rgb.allSatisfy { $0 < 80 } : rgb.allSatisfy { $0 > 180 }
        }.count
    }

    func testPopulatedPasswordKeepsVisualNameAndOneSecureField() {
        verifyPopulatedPassword(prefix: "normal")
    }

    private func verifyPopulatedPassword(prefix: String) {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                launch(style, size, "password-keyboard")
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
                let field = app.secureTextFields["Password"]
                field.typeText("offline-only")
                XCTAssertEqual(app.secureTextFields.matching(identifier: "Password").count, 1)
                XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Password")).count, 1)
                XCTAssertNotEqual(field.value as? String, "Password")
                XCTAssertGreaterThanOrEqual(field.frame.height, 44)
                let done = app.buttons["Done"]
                XCTAssertGreaterThanOrEqual(done.frame.height, 48)
                XCTAssertLessThanOrEqual(field.frame.maxY, app.keyboards.firstMatch.frame.minY)
                assertPasswordInk(field: field, style: style, size: size, state: prefix + "-focused")
                done.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
                assertPasswordInk(field: field, style: style, size: size, state: prefix + "-dismissed")
            }
        }
    }

    func testEmptyPasswordFirstFocusAndRefocusKeepsHeading() throws {
        try verifyEmptyPasswordFocus(prefix: "normal")
    }

    func testCombinedEmptyPasswordFirstFocusAndRefocusKeepsHeading() throws {
        try configure(restoring: false)
        settings.terminate()
        try verifyEmptyPasswordFocus(prefix: "combined")
    }

    private func verifyEmptyPasswordFocus(prefix: String) throws {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                launch(style, size, "password-keyboard")
                for cycle in 0..<2 {
                    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
                    let field = app.secureTextFields["Password"]
                    let raw = try XCTUnwrap(app.otherElements["signin.densityFrames"].value as? String)
                    let frames = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: [Double]])
                    let v = try XCTUnwrap(frames["passwordHeading"])
                    let heading = CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
                    let nav = app.navigationBars.firstMatch.frame
                    capture("first-focus-\(prefix)-\(style)-\(size)-\(cycle)", details: raw)
                    XCTAssertGreaterThanOrEqual(heading.minY + 1.0 / 3, nav.maxY)
                    XCTAssertLessThanOrEqual(heading.maxY, field.frame.minY)
                    XCTAssertGreaterThan(ink(heading, style: style), 100)
                    XCTAssertLessThanOrEqual(field.frame.maxY, app.buttons["Done"].frame.minY)
                    XCTAssertGreaterThanOrEqual(field.frame.height, 44)
                    app.buttons["Done"].tap()
                    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
                    if cycle == 0 { field.tap() }
                }
            }
        }
    }

    private func assertPasswordInk(field: XCUIElement, style: String, size: String, state: String) {
        let target = app.otherElements["signin.passwordTarget"].frame
        let height: CGFloat = size == "XXXL" ? 28 : 22
        let label = CGRect(x: target.minX, y: target.minY - 12 - height,
                           width: 150, height: height)
        XCTAssertGreaterThanOrEqual(label.minY, app.navigationBars.firstMatch.frame.maxY)
        if state.hasSuffix("focused") { assertTitleBand(style: style) }
        let count = ink(label, style: style)
        XCTAssertGreaterThan(count, 100, "Persistent Password ink")
        capture("chrome-password-\(style)-\(size)-\(state)", details: "field=\(field.frame) label=\(label) ink=\(count)")
    }

    private func assertTitleBand(style: String) {
        let nav = app.navigationBars.firstMatch.frame
        let image = app.screenshot().image.cgImage!
        let scale = CGFloat(image.width) / app.frame.width
        for x in [CGFloat(20), app.frame.width - 140] {
            let band = CGRect(x: x * scale, y: nav.minY * scale,
                              width: 120 * scale, height: min(44, nav.height) * scale)
            guard let crop = image.cropping(to: band) else { XCTFail("Missing title band"); return }
            var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
            let context = CGContext(data: &bytes, width: crop.width, height: crop.height,
                bitsPerComponent: 8, bytesPerRow: crop.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
            func linear(_ byte: UInt8) -> Double {
                let value = Double(byte) / 255
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            var maximum = 1.0
            for i in stride(from: 0, to: bytes.count, by: 4) {
                let luminance = 0.2126 * linear(bytes[i]) + 0.7152 * linear(bytes[i+1]) + 0.0722 * linear(bytes[i+2])
                let ratio = style == "light" ? 1.05 / (luminance + 0.05) : (luminance + 0.05) / 0.05
                maximum = max(maximum, ratio)
            }
            XCTAssertLessThanOrEqual(maximum, 1.5, "Non-title ink beside centered Sign In")
            let proof = XCTAttachment(string: "nav=\(nav) sideX=\(x) maxNonTitleContrast=\(maximum)")
            proof.name = "chrome-title-band"; proof.lifetime = .keepAlways; add(proof)
        }
    }

    func testLegalFooterRestingAndBottomReachabilityWithEnabledInertAppearance() throws {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                launch(style, size, "password", enabled: true)
                capture("chrome-footer-\(style)-\(size)-initial")
                launch(style, size, "password", enabled: true, bottom: true)
                let export = app.otherElements["hillclimb.geometry"]
                let value = try XCTUnwrap(export.value as? String)
                let data = try XCTUnwrap(value.data(using: .utf8))
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [Double]])
                let safe = try XCTUnwrap(json["safeArea"])
                let bottom = safe[1] + safe[3]
                for name in ["Privacy", "Terms", "Support"] {
                    let link = app.buttons[name]
                    XCTAssertTrue(link.isEnabled); XCTAssertTrue(link.isHittable)
                    XCTAssertGreaterThanOrEqual(link.frame.minY, app.navigationBars.firstMatch.frame.maxY)
                    XCTAssertGreaterThan(ink(link.frame, style: style), 20)
                    XCTAssertLessThanOrEqual(link.frame.maxY + 8, bottom)
                    link.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    XCTAssertEqual(app.state, .runningForeground)
                    XCTAssertTrue(app.navigationBars["Sign In"].exists)
                }
                capture("chrome-footer-\(style)-\(size)-bottom", details: "safeBottom=\(bottom) links=\(["Privacy", "Terms", "Support"].map { app.buttons[$0].frame })")
            }
        }
    }

    func testOrdinaryLegalFooterReachableByActualGesture() throws {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                launch(style, size, "password")
                XCTAssertFalse(app.keyboards.firstMatch.exists)
                let visibleScrollView = app.scrollViews.firstMatch
                XCTAssertTrue(visibleScrollView.isHittable)
                let names = ["Privacy", "Terms", "Support"]
                let initial = names.map { app.buttons[$0].frame }
                let witness = app.otherElements["signin.passwordTarget"]
                let initialWitness = witness.frame
                let value = try XCTUnwrap(app.otherElements["hillclimb.geometry"].value as? String)
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: [Double]])
                let safe = try XCTUnwrap(json["safeArea"])
                let safeBottom = safe[1] + safe[3]
                if size == "XXXL" {
                    XCTAssertTrue(initial.contains { $0.maxY > safeBottom }, "Footer must initially extend outside viewport")
                }
                capture("gesture-\(style)-\(size)-initial", details: "safeBottom=\(safeBottom) links=\(initial) witness=\(initialWitness)")
                // Coordinates stay inside the observed ScrollView and avoid tapping a field.
                let start = visibleScrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
                let end = visibleScrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
                start.press(forDuration: 0.1, thenDragTo: end)
                start.press(forDuration: 0.1, thenDragTo: end)
                XCTAssertFalse(app.keyboards.firstMatch.exists)
                let bottomFrames = names.map { app.buttons[$0].frame }
                if size == "XXXL" {
                    XCTAssertGreaterThan(initialWitness.minY - witness.frame.minY, 20, "Actual content displacement")
                    XCTAssertGreaterThan(initial[0].minY - bottomFrames[0].minY, 20)
                }
                for name in names {
                    let link = app.buttons[name]
                    XCTAssertFalse(link.isEnabled)
                    XCTAssertGreaterThanOrEqual(link.frame.minY, app.navigationBars.firstMatch.frame.maxY)
                    XCTAssertLessThanOrEqual(link.frame.maxY + 8, safeBottom)
                    XCTAssertGreaterThan(legalInk(link.frame, style: style), 20, "Disabled legal text remains visible")
                    link.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    XCTAssertEqual(app.state, .runningForeground)
                    XCTAssertTrue(app.navigationBars["Sign In"].exists)
                    XCTAssertEqual(app.buttons[name].frame, link.frame)
                }
                capture("gesture-\(style)-\(size)-bottom", details: "safeBottom=\(safeBottom) initial=\(initial) links=\(bottomFrames) initialWitness=\(initialWitness) witness=\(witness.frame)")
                launch(style, size, "password", enabled: true, bottom: true)
                let paintFrames = names.map { app.buttons[$0].frame }
                for index in names.indices {
                    XCTAssertEqual(bottomFrames[index].width, paintFrames[index].width, accuracy: 1)
                    XCTAssertEqual(bottomFrames[index].height, paintFrames[index].height, accuracy: 1)
                    XCTAssertEqual(bottomFrames[index].minY - bottomFrames[0].minY,
                                   paintFrames[index].minY - paintFrames[0].minY, accuracy: 1)
                }
                capture("gesture-\(style)-\(size)-paint-comparison", details: "ordinary=\(bottomFrames) enabledPaint=\(paintFrames); compare dimensions and relative layout; color differs")
            }
        }
    }

    private func legalInk(_ frame: CGRect, style: String) -> Int {
        let image = app.screenshot().image.cgImage!
        let scale = CGFloat(image.width) / app.frame.width
        guard let crop = image.cropping(to: CGRect(x: frame.minX * scale, y: frame.minY * scale,
            width: frame.width * scale, height: frame.height * scale)) else { XCTFail("Missing legal raster"); return 0 }
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = CGContext(data: &bytes, width: crop.width, height: crop.height, bitsPerComponent: 8,
            bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        return stride(from: 0, to: bytes.count, by: 4).filter { i in
            let rgb = bytes[i..<i+3]
            return style == "light" ? rgb.allSatisfy { $0 < 210 } : rgb.allSatisfy { $0 > 45 }
        }.count
    }

    func testNativeAppleLoadingLabelAcrossThreeFreshProcessesPerStyleAndSize() {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                for repeatIndex in 1...3 {
                    launch(style, size, "loading", enabled: true)
                    let apple = app.buttons["signin.apple"]
                    XCTAssertFalse(apple.isEnabled)
                    XCTAssertTrue(app.buttons["Send Sign-In Link, in progress"].exists)
                    for delay in [0.5, 1.0, 2.0] {
                        Thread.sleep(forTimeInterval: delay == 0.5 ? 0.5 : delay == 1 ? 0.5 : 1)
                        let frame = apple.frame.insetBy(dx: apple.frame.width * 0.2, dy: 8)
                        // The native whiteOutline control has black title/logo ink in both appearances.
                        let count = ink(frame, style: "light")
                        XCTAssertGreaterThan(count, 100)
                        capture("chrome-loading-\(style)-\(size)-\(repeatIndex)-\(delay)", details: "apple=\(apple.frame) titleInk=\(count)")
                    }
                }
            }
        }
    }
}
