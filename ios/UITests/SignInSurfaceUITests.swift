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
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
        XCTAssertGreaterThanOrEqual(element.frame.height + 1, ceil(ideal.height), text)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDefaultAndXXXLControlsAndTextInBothAppearances() {
        for style in ["light", "dark"] {
            for size in ["default", "XXXL"] {
                launch(style: style, size: size)
                target(app.buttons["Sign in with Google"])
                target(app.textFields["Email address"])
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
                for variant in ["password", "inbox", "error"] {
                    launch(style: style, size: size, variant: variant)
                    if variant == "password" {
                        target(app.secureTextFields["Password"])
                        target(app.buttons["Sign In with Password"])
                        target(app.buttons["Use a Sign-In Link Instead"])
                        wraps("For an existing account with a password. You can also use a sign-in link.", style: .footnote, size: size)
                    } else if variant == "inbox" {
                        target(app.buttons["Use a Different Email"])
                        wraps("We sent a sign-in link to you@example.com.", style: .subheadline, size: size)
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
            for variant in ["keyboard", "password-keyboard"] {
                launch(style: style, size: "default", variant: variant)
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
                let field = variant == "keyboard" ? app.textFields["Email address"] : app.secureTextFields["Password"]
                target(field)
                XCTAssertLessThanOrEqual(field.frame.maxY, app.keyboards.firstMatch.frame.minY)
                XCTAssertTrue(app.buttons["Done"].exists)
                capture("signin-\(style)-default-\(variant)")
            }
        }
    }
}
