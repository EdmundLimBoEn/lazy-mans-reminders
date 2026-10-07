import XCTest
@testable import LazyMansReminders

final class ChatGPTSignInTests: XCTestCase {
    private let sdkURL = URL(
        string: "https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/authorize?provider=google&redirect_to=lazymansreminders://auth/callback&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=s256&scopes=openid%20offline_access%20resource.invoke%20chatgpt.tokens.use.direct"
    )!

    private func query(_ name: String, in url: URL) -> [String?] {
        (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .filter { $0.name == name }
            .map(\.value)
    }

    func testChatGPTAuthorizeURLPinsIdentityScopesAndDropsSpendScopes() throws {
        let url = try ChatGPTSignIn.authorizeURL(rewriting: sdkURL)

        XCTAssertEqual(query("provider", in: url), ["custom:chatgpt"])
        XCTAssertEqual(ChatGPTSignIn.supabaseProvider, "custom:chatgpt")
        XCTAssertEqual(ChatGPTSignIn.issuer, "https://auth.openai.com")
        XCTAssertEqual(query("scopes", in: url), ["openid profile email"])
        XCTAssertEqual(
            CustomOIDCSignIn.requestedScopes(in: url),
            ["openid", "profile", "email"]
        )
        let absolute = url.absoluteString
        for banned in CustomOIDCSignIn.spendScopes {
            XCTAssertFalse(
                CustomOIDCSignIn.requestedScopes(in: url).contains(banned),
                banned
            )
            XCTAssertFalse(absolute.contains(banned), banned)
        }
        XCTAssertEqual(query("code_challenge_method", in: url), ["s256"])
        XCTAssertEqual(query("redirect_to", in: url), ["lazymansreminders://auth/callback"])
    }

    func testGrokAndChatGPTRewritesDoNotShareAProvider() throws {
        let grok = try GrokSignIn.authorizeURL(rewriting: sdkURL)
        let chatgpt = try ChatGPTSignIn.authorizeURL(rewriting: sdkURL)
        XCTAssertEqual(query("provider", in: grok), ["custom:grok"])
        XCTAssertEqual(query("provider", in: chatgpt), ["custom:chatgpt"])
        XCTAssertEqual(query("scopes", in: grok), query("scopes", in: chatgpt))
    }

    func testFlagsReadSeparateInfoKeys() {
        let values = [
            "CHATGPT_SIGN_IN_ENABLED": "YES",
            "GROK_SIGN_IN_ENABLED": "NO",
        ]
        XCTAssertTrue(enabled(.chatgpt, values: values, arguments: []))
        XCTAssertFalse(enabled(.grok, values: values, arguments: []))

        let swapped = [
            "CHATGPT_SIGN_IN_ENABLED": "NO",
            "GROK_SIGN_IN_ENABLED": "YES",
        ]
        XCTAssertFalse(enabled(.chatgpt, values: swapped, arguments: []))
        XCTAssertTrue(enabled(.grok, values: swapped, arguments: []))
    }

    func testLaunchOverrideChangesOnlyTheNamedProvider() {
        let arguments = ["-LMRChatGPTSignIn", "YES", "-LMRGrokSignIn", "NO"]
        let values = [
            "CHATGPT_SIGN_IN_ENABLED": "NO",
            "GROK_SIGN_IN_ENABLED": "YES",
        ]
        XCTAssertTrue(enabled(.chatgpt, values: values, arguments: arguments))
        XCTAssertFalse(enabled(.grok, values: values, arguments: arguments))
        XCTAssertFalse(enabled(.chatgpt, values: values, arguments: arguments, allowLaunchOverride: false))
        XCTAssertTrue(enabled(.grok, values: values, arguments: arguments, allowLaunchOverride: false))
    }

    func testAppleStaysFirstAndEachFlagAddsOnlyItsButton() {
        let combinations: [(Bool, Bool, [SignInScreen.Control])] = [
            (false, false, [.apple, .google]),
            (true, false, [.apple, .grok, .google]),
            (false, true, [.apple, .chatgpt, .google]),
            (true, true, [.apple, .chatgpt, .grok, .google]),
        ]
        for (grok, chatgpt, expected) in combinations {
            let rows = SignInScreen.controls(grokEnabled: grok, chatgptEnabled: chatgpt)
            XCTAssertEqual(rows, expected)
            XCTAssertEqual(rows.first, .apple)
            XCTAssertEqual(rows.contains(.chatgpt), chatgpt)
            XCTAssertEqual(rows.contains(.grok), grok)
        }
    }

    private func enabled(
        _ provider: CustomOIDCSignIn.Provider,
        values: [String: String],
        arguments: [String],
        allowLaunchOverride: Bool = true
    ) -> Bool {
        CustomOIDCSignIn.isEnabled(
            provider,
            infoValue: values[provider.infoKey],
            launchArguments: arguments,
            allowLaunchOverride: allowLaunchOverride
        )
    }
}
