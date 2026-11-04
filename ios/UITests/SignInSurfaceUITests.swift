import XCTest
import UIKit

final class SignInSurfaceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(style: String, size: String, variant: String = "default") {
        app.launchArguments = ["--hillclimb-demo", "signin", "--hillclimb-style", style,
                               "--hillclimb-size", size, "--hillclimb-signin-variant", variant]
        app.launch()
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 10))
    }

    private func target(_ element: XCUIElement) {
        XCTAssertTrue(element.exists)
        XCTAssertGreaterThanOrEqual(element.frame.width, 44, element.label)
        XCTAssertGreaterThanOrEqual(element.frame.height, 44, element.label)
        XCTAssertGreaterThanOrEqual(element.frame.minX, 0)
        XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.width)
    }

    private func wraps(_ text: String, style: UIFont.TextStyle, size: String) {
        let element = app.staticTexts[text]
        XCTAssertTrue(element.exists)
        let traits = UITraitCollection(preferredContentSizeCategory: size == "XXXL" ? .extraExtraExtraLarge : .large)
        let font = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        let ideal = (text as NSString).boundingRect(
            with: CGSize(width: element.frame.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin], attributes: [.font: font], context: nil)
        XCTAssertGreaterThanOrEqual(element.frame.height + 1, ceil(ideal.height), text)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testEnabledAppearanceIsInertAndAppleBoundaryIsVisible() {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                app.launchArguments = ["--hillclimb-demo", "signin", "--hillclimb-style", style,
                    "--hillclimb-size", size, "--hillclimb-signin-appearance", "enabled"]
                app.launch()
                XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 10))
                let apple = app.buttons["signin.apple"]
                target(apple)
                XCTAssertTrue(apple.isEnabled)
                XCTAssertTrue(app.buttons["Sign in with Google"].isEnabled)
                if style == "dark" { assertAppleBoundary(apple.frame) }
                assertNormalTextContrast("Your board on this iPhone, the web, and the Lock Screen.", style: style)
                assertNormalTextContrast("Use the same address as the web board.", style: style)
                apple.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                app.buttons["Sign in with Google"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                app.textFields["Email address"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                app.buttons["Use an Existing Password"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                XCTAssertFalse(app.keyboards.firstMatch.exists)
                XCTAssertFalse(app.secureTextFields["Password"].exists)
                XCTAssertEqual(app.navigationBars.firstMatch.identifier, "Sign In")
                for label in ["Privacy", "Terms", "Support"] {
                    let link = app.buttons[label]
                    XCTAssertTrue(link.isEnabled)
                    XCTAssertTrue(link.isHittable)
                    assertNormalTextContrast(label, style: style, frame: link.frame)
                    link.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    XCTAssertEqual(app.state, .runningForeground)
                    XCTAssertTrue(app.navigationBars["Sign In"].exists)
                }
                capture("design-only-inert-enabled-signin-\(style)-\(size)")
            }
        }
    }

    private func pixels(in frame: CGRect) -> [[UInt8]] {
        let image = app.screenshot().image.cgImage!
        let scale = CGFloat(image.width) / app.frame.width
        let crop = image.cropping(to: CGRect(x: frame.minX * scale, y: frame.minY * scale,
                                            width: frame.width * scale, height: frame.height * scale))!
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = CGContext(data: &bytes, width: crop.width, height: crop.height,
            bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        return stride(from: 0, to: bytes.count, by: 4).map { Array(bytes[$0..<$0+3]) }
    }

    private func assertAppleBoundary(_ frame: CGRect) {
        // A strip away from the centered label must contain the native white bezel/fill.
        let strip = CGRect(x: frame.minX + 6, y: frame.minY + 8, width: 8, height: frame.height - 16)
        let samples = pixels(in: strip)
        let white = samples.filter { $0.allSatisfy { $0 > 200 } }.count
        XCTAssertGreaterThan(Double(white) / Double(samples.count), 0.8)
    }

    private func assertNormalTextContrast(_ text: String, style: String, frame: CGRect? = nil) {
        let samples = pixels(in: frame ?? app.staticTexts[text].frame)
        var histogram: [Int: Int] = [:]
        for rgb in samples {
            let key = Int(rgb[0]) << 16 | Int(rgb[1]) << 8 | Int(rgb[2])
            histogram[key, default: 0] += 1
        }
        let background = style == "light" ? 255.0 : 0.0
        let ink = histogram.filter { key, _ in
            let channels = [Double((key >> 16) & 255), Double((key >> 8) & 255), Double(key & 255)]
            return channels.allSatisfy { abs($0 - background) > 40 }
        }.max { $0.value < $1.value }
        XCTAssertNotNil(ink)
        guard let ink else { return }
        XCTAssertGreaterThan(ink.value, 20)
        func linear(_ value: Double) -> Double {
            let s = value / 255
            return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        let key = ink.key
        let luminance = 0.2126 * linear(Double((key >> 16) & 255))
            + 0.7152 * linear(Double((key >> 8) & 255)) + 0.0722 * linear(Double(key & 255))
        let ratio = style == "light" ? 1.05 / (luminance + 0.05) : (luminance + 0.05) / 0.05
        XCTAssertGreaterThanOrEqual(ratio, 4.5, text)
    }

    func testDefaultAndXXXLControlsAndTextInBothAppearances() {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                launch(style: style, size: size)
                target(app.buttons["Sign in with Google"])
                target(app.otherElements["signin.emailTarget"])
                XCTAssertTrue(app.textFields["Email address"].exists)
                target(app.buttons["Send Sign-In Link"])
                target(app.buttons["Use an Existing Password"])
                wraps("Your board on this iPhone, the web, and the Lock Screen.", style: .body, size: size)
                wraps("Use the same address as the web board.", style: .footnote, size: size)
                let intro = app.staticTexts["Notepad"].frame
                let google = app.buttons["Sign in with Google"].frame
                let email = app.textFields["Email address"].frame
                XCTAssertGreaterThan(google.minY, intro.maxY)
                XCTAssertGreaterThan(email.minY, google.maxY)
                XCTAssertGreaterThanOrEqual(intro.minY, app.navigationBars.firstMatch.frame.maxY)
                capture("signin-\(style)-\(size)")
            }
        }
    }

    func testPasswordInboxAndErrorWrapInBothAppearancesAndSizes() {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                for variant in ["password", "inbox", "error", "loading"] {
                    launch(style: style, size: size, variant: variant)
                    if variant == "password" {
                        target(app.otherElements["signin.passwordTarget"])
                        XCTAssertTrue(app.secureTextFields["Password"].exists)
                        target(app.buttons["Sign In with Password"])
                        target(app.buttons["Use a Sign-In Link Instead"])
                        wraps("For an existing account with a password. You can also use a sign-in link.", style: .footnote, size: size)
                    } else if variant == "inbox" {
                        target(app.buttons["Use a Different Email"])
                        wraps("We sent a sign-in link to you@example.com.", style: .subheadline, size: size)
                    } else if variant == "loading" {
                        XCTAssertTrue(app.buttons["Send Sign-In Link, in progress"].exists)
                        XCTAssertFalse(app.buttons["Send Sign-In Link, in progress"].isEnabled)
                    } else {
                        wraps("Couldn’t sign in. Check your email and password, or use a sign-in link. If you’re offline, reconnect and try again.", style: .footnote, size: size)
                    }
                    capture("signin-\(style)-\(size)-\(variant)")
                }
            }
        }
    }

    func testFocusedEmailAndPasswordClearKeyboardInBothAppearances() {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
            for variant in ["keyboard", "password-keyboard"] {
                launch(style: style, size: size, variant: variant)
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
                let field = variant == "keyboard" ? app.textFields["Email address"] : app.secureTextFields["Password"]
                XCTAssertTrue(field.exists)
                target(app.otherElements[variant == "keyboard" ? "signin.emailTarget" : "signin.passwordTarget"])
                XCTAssertLessThanOrEqual(field.frame.maxY, app.keyboards.firstMatch.frame.minY)
                XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
                let done = app.buttons["Done"]
                target(done)
                let alternate = app.buttons[variant == "keyboard" ? "Use an Existing Password" : "Use a Sign-In Link Instead"]
                XCTAssertLessThanOrEqual(alternate.frame.maxY + 8, done.frame.minY)
                XCTAssertGreaterThanOrEqual(field.frame.minY, app.navigationBars.firstMatch.frame.maxY)
                // Exercise real form scrolling as well as initial keyboard placement.
                scrollFormAndRestoreKeyboard(field: field)
                for _ in 0..<4 {
                    if alternate.frame.maxY + 8 <= done.frame.minY && alternate.frame.minY >= app.navigationBars.firstMatch.frame.maxY { break }
                    scrollFormAndRestoreKeyboard(field: field)
                }
                target(alternate)
                XCTAssertTrue(alternate.isHittable)
                XCTAssertFalse(alternate.frame.intersects(done.frame))
                XCTAssertLessThanOrEqual(alternate.frame.maxY + 8, done.frame.minY)
                XCTAssertLessThanOrEqual(alternate.frame.maxY, app.keyboards.firstMatch.frame.minY)
                capture("signin-\(style)-\(size)-\(variant)")
                done.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
                field.tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
                for _ in 0..<4 {
                    if alternate.frame.maxY + 8 <= done.frame.minY && alternate.frame.minY >= app.navigationBars.firstMatch.frame.maxY { break }
                    scrollFormAndRestoreKeyboard(field: field)
                }
                XCTAssertFalse(alternate.frame.intersects(done.frame))
                XCTAssertLessThanOrEqual(alternate.frame.maxY + 8, done.frame.minY)
                alternate.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
                XCTAssertTrue(app.buttons[variant == "keyboard" ? "Use a Sign-In Link Instead" : "Use an Existing Password"].exists)
                if app.keyboards.firstMatch.exists {
                    done.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
                }
            }
            }
        }
    }
    private func scrollFormAndRestoreKeyboard(field: XCUIElement) {
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let top = app.navigationBars.firstMatch.frame.maxY + 12
        let bottom = min(app.buttons["Done"].frame.minY - 12, app.keyboards.firstMatch.frame.minY - 12)
        XCTAssertGreaterThan(bottom - top, 44)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: bottom))
        let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: top))
        start.press(forDuration: 0.05, thenDragTo: end)
        // Interactive dismissal is valid; refocus before querying keyboard geometry.
        if !app.keyboards.firstMatch.exists {
            XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 5))
            XCTAssertTrue(field.isHittable)
            field.tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(field.frame.minY, app.navigationBars.firstMatch.frame.maxY)
        XCTAssertLessThanOrEqual(field.frame.maxY, app.buttons["Done"].frame.minY)
    }
    func testDemoBlocksExternalActionsAndAllowsLocalRecovery() {
        launch(style: "light", size: "default")
        XCTAssertFalse(app.buttons["Sign in with Apple"].isEnabled)
        XCTAssertFalse(app.buttons["Sign in with Google"].isEnabled)
        let email = app.textFields["Email address"]
        email.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        email.typeText("you@example.com")
        XCTAssertFalse(app.buttons["Send Sign-In Link"].isEnabled)
        app.buttons["Clear text"].tap()
        XCTAssertFalse(app.buttons["Clear text"].exists)
        email.typeText("you@example.com")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.buttons["Use an Existing Password"].tap()
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("offline-only")
        XCTAssertFalse(app.buttons["Sign In with Password"].isEnabled)
        app.buttons["Done"].tap()
        app.swipeUp()
        for label in ["Privacy", "Terms", "Support"] {
            XCTAssertTrue(app.buttons[label].exists)
            XCTAssertFalse(app.buttons[label].isEnabled)
        }
        launch(style: "light", size: "default", variant: "inbox")
        app.buttons["Use a Different Email"].tap()
        XCTAssertTrue(app.textFields["Email address"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        launch(style: "light", size: "default", variant: "error")
        app.textFields["Email address"].tap()
        app.textFields["Email address"].typeText("x")
        XCTAssertFalse(app.staticTexts["Couldn’t sign in. Check your email and password, or use a sign-in link. If you’re offline, reconnect and try again."].exists)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.buttons["Done"].tap()
    }

}
