import SwiftUI
import XCTest
@testable import LazyMansReminders

final class LMRChromeTests: XCTestCase {
    func testAppleFillIsBlackInDarkMode() {
        XCTAssertEqual(SignInAppleFill.fill(for: .dark), .black)
    }

    func testAppleFillIsWhiteOutlineInLightMode() {
        XCTAssertEqual(SignInAppleFill.fill(for: .light), .whiteOutline)
    }

    func testLegalPageURLs() {
        XCTAssertEqual(LMRWeb.privacy.absoluteString, "https://lmr.edmundlim.systems/privacy")
        XCTAssertEqual(LMRWeb.terms.absoluteString, "https://lmr.edmundlim.systems/terms")
        XCTAssertEqual(LMRWeb.support.absoluteString, "https://lmr.edmundlim.systems/support")
        XCTAssertEqual(LMRWeb.dataExport.absoluteString, "https://lmr.edmundlim.systems")
    }

    func testAuthNoticeEquality() {
        XCTAssertEqual(
            AuthNotice.checkInbox(email: "you@example.com"),
            AuthNotice.checkInbox(email: "you@example.com")
        )
        XCTAssertNotEqual(
            AuthNotice.checkInbox(email: "you@example.com"),
            AuthNotice.error("nope")
        )
    }

    func testAccountCaptionPrefersApple() {
        XCTAssertEqual(
            AccountSessionCaption.methodCaption(providers: ["google", "apple"]),
            "Using Sign in with Apple"
        )
        XCTAssertEqual(
            AccountSessionCaption.methodCaption(providers: ["google"]),
            "Using Google"
        )
        XCTAssertEqual(
            AccountSessionCaption.methodCaption(providers: ["email"]),
            "Using Email"
        )
        XCTAssertNil(AccountSessionCaption.methodCaption(providers: ["phone"]))
    }

    func testSignInEmailRequiresBothSidesOfAtSign() {
        XCTAssertFalse(SignInEmail.isPlausible(""))
        XCTAssertFalse(SignInEmail.isPlausible("nope"))
        XCTAssertFalse(SignInEmail.isPlausible("@example.com"))
        XCTAssertFalse(SignInEmail.isPlausible("you@"))
        XCTAssertTrue(SignInEmail.isPlausible("you@example.com"))
        XCTAssertTrue(SignInEmail.isPlausible("  you@example.com  "))
    }
}
