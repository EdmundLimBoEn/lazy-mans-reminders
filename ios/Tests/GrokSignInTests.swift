import XCTest
@testable import LazyMansReminders

final class GrokSignInTests: XCTestCase {
    private let sdkURL = URL(
        string: "https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/authorize?provider=google&redirect_to=lazymansreminders://auth/callback&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=s256"
    )!

    private func query(_ url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    private func values(_ name: String, in url: URL) -> [String?] {
        query(url).filter { $0.name == name }.map(\.value)
    }

    func testRewriteTargetsGrokProviderAndKeepsPKCEAndRedirect() throws {
        let url = try GrokSignIn.authorizeURL(rewriting: sdkURL)

        XCTAssertEqual(url.host, "biwmsxbqrevtjwgsvsmu.supabase.co")
        XCTAssertEqual(url.path, "/auth/v1/authorize")
        XCTAssertEqual(values("provider", in: url), ["custom:grok"])
        XCTAssertEqual(values("redirect_to", in: url), ["lazymansreminders://auth/callback"])
        XCTAssertEqual(values("code_challenge", in: url), ["E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"])
        XCTAssertEqual(values("code_challenge_method", in: url), ["s256"])
    }

    func testRewritePinsIdentityScopesEvenIfWiderScopesWereRequested() throws {
        var components = URLComponents(url: sdkURL, resolvingAgainstBaseURL: false)!
        components.queryItems?.append(URLQueryItem(name: "scopes", value: "openid offline_access api:access"))
        components.queryItems?.append(URLQueryItem(name: "provider", value: "custom:other"))

        let url = try GrokSignIn.authorizeURL(rewriting: components.url!)

        XCTAssertEqual(values("scopes", in: url), ["openid profile email"])
        XCTAssertEqual(values("provider", in: url), ["custom:grok"])
        let scopes = Set((values("scopes", in: url).first ?? nil)?.split(separator: " ").map(String.init) ?? [])
        XCTAssertEqual(scopes, ["openid", "profile", "email"])
    }

    func testRewriteRefusesURLWithoutS256Challenge() {
        var noChallenge = URLComponents(url: sdkURL, resolvingAgainstBaseURL: false)!
        noChallenge.queryItems = noChallenge.queryItems?.filter { !$0.name.hasPrefix("code_challenge") }
        XCTAssertThrowsError(try GrokSignIn.authorizeURL(rewriting: noChallenge.url!)) { error in
            XCTAssertEqual(error as? GrokSignIn.AuthorizeURLError, .missingPKCE)
        }

        var plain = URLComponents(url: sdkURL, resolvingAgainstBaseURL: false)!
        plain.queryItems = plain.queryItems?.map {
            $0.name == "code_challenge_method" ? URLQueryItem(name: $0.name, value: "plain") : $0
        }
        XCTAssertThrowsError(try GrokSignIn.authorizeURL(rewriting: plain.url!)) { error in
            XCTAssertEqual(error as? GrokSignIn.AuthorizeURLError, .missingPKCE)
        }
    }

    func testFeatureFlagIsOffUnlessExplicitlyEnabled() {
        XCTAssertFalse(GrokSignIn.isEnabled(infoValue: nil))
        XCTAssertFalse(GrokSignIn.isEnabled(infoValue: ""))
        XCTAssertFalse(GrokSignIn.isEnabled(infoValue: "NO"))
        XCTAssertFalse(GrokSignIn.isEnabled(infoValue: "$(GROK_SIGN_IN_ENABLED)"))
        XCTAssertTrue(GrokSignIn.isEnabled(infoValue: "YES"))
        XCTAssertTrue(GrokSignIn.isEnabled(infoValue: " yes "))
        XCTAssertTrue(GrokSignIn.isEnabled(infoValue: "true"))
        XCTAssertTrue(GrokSignIn.isEnabled(infoValue: true))
    }

    func testIdentitySummaryPrefersNameAndEmail() {
        XCTAssertEqual(
            GrokSignIn.identitySummary(claims: ["name": "Edmund Lim", "email": "e@example.com"]),
            "Edmund Lim · e@example.com"
        )
        XCTAssertEqual(
            GrokSignIn.identitySummary(claims: ["name": "e@example.com", "email": "E@example.com"]),
            "E@example.com"
        )
        XCTAssertEqual(GrokSignIn.identitySummary(claims: ["email": " e@example.com "]), "e@example.com")
        XCTAssertEqual(GrokSignIn.identitySummary(claims: ["name": "Edmund"]), "Edmund")
        XCTAssertEqual(GrokSignIn.identitySummary(claims: ["name": "  "]), "Connected")
    }
}
