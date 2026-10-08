import Foundation

/// Builds the Account → Send Feedback `mailto:` link and the version footer.
/// Kept free of SwiftUI so tests can feed concrete version/build/iOS values.
enum FeedbackMail {
    static let address = "hello@edmundlim.systems"

    struct AppInfo: Equatable {
        var version: String
        var build: String
        var osVersion: String

        /// Reads `CFBundleShortVersionString` / `CFBundleVersion`. Missing or
        /// blank values become "unknown" so the mail still says something.
        init(infoDictionary: [String: Any]?, osVersion: String) {
            version = FeedbackMail.clean(infoDictionary?["CFBundleShortVersionString"])
            build = FeedbackMail.clean(infoDictionary?["CFBundleVersion"])
            self.osVersion = FeedbackMail.clean(osVersion)
        }

        init(version: String, build: String, osVersion: String) {
            self.version = version
            self.build = build
            self.osVersion = osVersion
        }

        static var current: AppInfo {
            AppInfo(
                infoDictionary: Bundle.main.infoDictionary,
                osVersion: FeedbackMail.osVersionString(ProcessInfo.processInfo.operatingSystemVersion)
            )
        }
    }

    /// "18.2" for 18.2.0, "18.2.1" when there is a patch number (same as
    /// `UIDevice.systemVersion`, without needing the main actor).
    static func osVersionString(_ version: OperatingSystemVersion) -> String {
        let base = "\(version.majorVersion).\(version.minorVersion)"
        return version.patchVersion == 0 ? base : "\(base).\(version.patchVersion)"
    }

    static func subject(_ info: AppInfo) -> String {
        "Lazy Man's Reminders feedback (\(info.version) build \(info.build))"
    }

    static func body(_ info: AppInfo) -> String {
        "\n\n---\nApp version: \(info.version) (\(info.build))\niOS: \(info.osVersion)\n"
    }

    /// Footer text under the Account list, e.g. "Version 1.0 (7)".
    static func versionFooter(_ info: AppInfo) -> String {
        "Version \(info.version) (\(info.build))"
    }

    /// `mailto:` URL with subject and body percent-encoded. Only RFC 3986
    /// unreserved characters are left as-is, so spaces become %20 (never +),
    /// newlines %0A, and `&`, `=`, `?`, `'` cannot break the query.
    static func url(_ info: AppInfo) -> URL? {
        guard
            let subject = encode(subject(info)),
            let body = encode(body(info))
        else { return nil }
        return URL(string: "mailto:\(address)?subject=\(subject)&body=\(body)")
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private static func encode(_ value: String) -> String? {
        value.addingPercentEncoding(withAllowedCharacters: unreserved)
    }

    fileprivate static func clean(_ raw: Any?) -> String {
        let value = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "unknown" : value
    }
}
