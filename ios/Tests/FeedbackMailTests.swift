import XCTest
@testable import LazyMansReminders

final class FeedbackMailTests: XCTestCase {
    func testMailtoURLForConcreteVersionBuildAndOS() {
        let info = FeedbackMail.AppInfo(version: "1.0", build: "7", osVersion: "18.2")
        XCTAssertEqual(
            FeedbackMail.url(info)?.absoluteString,
            "mailto:hello@edmundlim.systems"
                + "?subject=Lazy%20Man%27s%20Reminders%20feedback%20%281.0%20build%207%29"
                + "&body=%0A%0A---%0AApp%20version%3A%201.0%20%287%29%0AiOS%3A%2018.2%0A"
        )
    }

    func testMailtoURLRoundTripsThroughURLComponents() throws {
        let info = FeedbackMail.AppInfo(version: "1.2.3", build: "42", osVersion: "27.0.1")
        let url = try XCTUnwrap(FeedbackMail.url(info))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.path, "hello@edmundlim.systems")
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        XCTAssertEqual(items.keys.sorted(), ["body", "subject"])
        XCTAssertEqual(items["subject"], "Lazy Man's Reminders feedback (1.2.3 build 42)")
        XCTAssertEqual(items["body"], "\n\n---\nApp version: 1.2.3 (42)\niOS: 27.0.1\n")
    }

    func testQueryDelimitersInValuesAreEscaped() throws {
        // A hostile or odd build string must not inject extra mailto fields.
        let info = FeedbackMail.AppInfo(version: "1.0&cc=x@y.z", build: "7?bcc=a", osVersion: "18 + 1")
        let url = try XCTUnwrap(FeedbackMail.url(info))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.map(\.name), ["subject", "body"])
        XCTAssertFalse(url.absoluteString.contains("+"))
        XCTAssertEqual(
            components.queryItems?.first?.value,
            "Lazy Man's Reminders feedback (1.0&cc=x@y.z build 7?bcc=a)"
        )
    }

    func testAppInfoReadsBundleKeys() {
        let info = FeedbackMail.AppInfo(
            infoDictionary: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "7"],
            osVersion: "18.2"
        )
        XCTAssertEqual(info, FeedbackMail.AppInfo(version: "1.0", build: "7", osVersion: "18.2"))
        XCTAssertEqual(FeedbackMail.versionFooter(info), "Version 1.0 (7)")
    }

    func testAppInfoFallsBackWhenKeysMissingOrBlank() {
        let info = FeedbackMail.AppInfo(
            infoDictionary: ["CFBundleShortVersionString": "  ", "CFBundleVersion": 7],
            osVersion: ""
        )
        XCTAssertEqual(info, FeedbackMail.AppInfo(version: "unknown", build: "unknown", osVersion: "unknown"))
        XCTAssertEqual(FeedbackMail.versionFooter(info), "Version unknown (unknown)")
    }

    func testOSVersionStringMatchesSystemVersionFormat() {
        XCTAssertEqual(
            FeedbackMail.osVersionString(OperatingSystemVersion(majorVersion: 18, minorVersion: 2, patchVersion: 0)),
            "18.2"
        )
        XCTAssertEqual(
            FeedbackMail.osVersionString(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 1)),
            "27.0.1"
        )
    }

    func testCurrentReadsThisBuildsVersionAndBuild() {
        // The test host is the app, so Bundle.main carries project.yml's
        // MARKETING_VERSION / CURRENT_PROJECT_VERSION, never "unknown".
        let info = FeedbackMail.AppInfo.current
        XCTAssertNotEqual(info.version, "unknown")
        XCTAssertNotEqual(info.build, "unknown")
        XCTAssertTrue(info.osVersion.first?.isNumber ?? false, info.osVersion)
    }
}
