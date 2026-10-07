import XCTest

final class SignInScreenUITests: XCTestCase {
    func testEachFlagCombinationShowsItsOwnButtons() {
        let cases: [(grok: String, chatgpt: String, dark: Bool)] = [
            ("NO", "NO", false),
            ("YES", "NO", false),
            ("NO", "YES", false),
            ("YES", "YES", false),
            ("YES", "YES", true),
        ]
        for item in cases {
            XCUIDevice.shared.appearance = item.dark ? .dark : .light
            let app = XCUIApplication()
            app.launchArguments = [
                "-LMRSkipSessionRestore",
                "-LMRColorScheme", item.dark ? "dark" : "light",
                "-LMRGrokSignIn", item.grok,
                "-LMRChatGPTSignIn", item.chatgpt,
            ]
            app.launch()

            let apple = app.buttons["sign-in-apple"]
            XCTAssertTrue(
                apple.waitForExistence(timeout: 20),
                "Sign in with Apple missing for grok=\(item.grok) chatgpt=\(item.chatgpt)"
            )

            let grok = app.buttons["sign-in-grok"]
            let chatgpt = app.buttons["sign-in-chatgpt"]
            if item.grok == "YES" {
                XCTAssertTrue(grok.waitForExistence(timeout: 5))
                XCTAssertEqual(grok.label, "Continue with Grok")
                XCTAssertLessThan(apple.frame.minY, grok.frame.minY)
                XCTAssertLessThanOrEqual(grok.frame.height, apple.frame.height + 1)
                XCTAssertLessThanOrEqual(grok.frame.width, apple.frame.width + 1)
            } else {
                XCTAssertFalse(grok.exists)
            }
            if item.chatgpt == "YES" {
                XCTAssertTrue(chatgpt.waitForExistence(timeout: 5))
                XCTAssertEqual(chatgpt.label, "Continue with ChatGPT")
                XCTAssertLessThan(apple.frame.minY, chatgpt.frame.minY)
                XCTAssertLessThanOrEqual(chatgpt.frame.height, apple.frame.height + 1)
                XCTAssertLessThanOrEqual(chatgpt.frame.width, apple.frame.width + 1)
            } else {
                XCTAssertFalse(chatgpt.exists)
            }

            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot)
            let mode = item.dark ? "dark" : "light"
            attachment.name = "signin-grok-\(item.grok)-chatgpt-\(item.chatgpt)-\(mode)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
