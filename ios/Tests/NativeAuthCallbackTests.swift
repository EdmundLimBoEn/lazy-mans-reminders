import XCTest
@testable import LazyMansReminders

final class NativeAuthCallbackTests: XCTestCase {
    private let base = "lazymansreminders://auth/callback"

    func testAcceptsPKCEQueryAndFragmentCallbacks() {
        for suffix in ["?code=test-code", "#code=test-code",
                       "?code=test-code&type=magiclink#sb=",
                       "?code=test-code&sb_flow_id=test-flow"] {
            XCTAssertEqual(NativeAuthCallback(url: URL(string: base + suffix)!), .code)
        }
    }

    func testRejectsUnrelatedOrMalformedCallbackAddresses() {
        for address in ["https://auth/callback", "other://auth/callback",
                        "lazymansreminders://board", "lazymansreminders://other/callback",
                        "lazymansreminders://auth/other", base + "/",
                        "lazymansreminders://auth/%63allback",
                        "lazymansreminders://user@auth/callback",
                        "lazymansreminders://auth:123/callback"] {
            XCTAssertNil(NativeAuthCallback(url: URL(string: address + "?code=test-code")!))
        }
    }

    func testRejectsMissingEmptyAmbiguousAndUnsupportedParameters() {
        for suffix in ["", "?other=value", "?code", "?code=", "?code=%20",
                       "?code=test%0Acode", "?code=one&code=two", "?code=one#code=two",
                       "?code=one&%63ode=two", "?code=one&unexpected=value",
                       "?error=", "?error_description=expired", "?error_code=expired",
                       "?error=expired&error_description=", "?code=one#error=expired",
                       "#access_token=test&refresh_token=test&expires_in=3600&token_type=bearer"] {
            XCTAssertNil(NativeAuthCallback(url: URL(string: base + suffix)!))
        }
    }

    func testErrorsAreClassifiedSeparatelyFromAuthentication() {
        for suffix in ["?error=access_denied",
                       "#error=access_denied&error_code=otp_expired&error_description=Expired&sb="] {
            XCTAssertEqual(NativeAuthCallback(url: URL(string: base + suffix)!), .error)
        }
    }
}
