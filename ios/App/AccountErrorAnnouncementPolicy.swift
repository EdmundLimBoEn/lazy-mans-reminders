import SwiftUI

struct AccountErrorAnnouncementPolicy {
    private var presentedMessage: String?

    mutating func announcement(for message: String?) -> String? {
        guard let message else {
            presentedMessage = nil
            return nil
        }
        guard message != presentedMessage else { return nil }
        presentedMessage = message
        return message
    }
}

enum AccountCaptureFixture {
    static var readOnly: Bool {
#if DEBUG
        HillclimbDemo.isActive
#else
        false
#endif
    }
    static var enabledAppearance: Bool {
#if DEBUG
        readOnly && HillclimbDemo.argument("--hillclimb-account-appearance") == "enabled"
#else
        false
#endif
    }
#if DEBUG
    static let signOutError = "Couldn’t disconnect notifications. You’re still signed in. Reconnect and try signing out again before giving this iPhone to someone else."
    static let refreshError = "Couldn’t refresh. Your saved board is still available."
    static var state: String? { readOnly ? HillclimbDemo.argument("--hillclimb-account-state") : nil }
    static var error: String? { state == "error" ? signOutError : nil }
#endif
}

private struct AccountFramePreference: PreferenceKey {
    static var defaultValue: [String: [Double]] = [:]
    static func reduce(value: inout [String: [Double]], nextValue: () -> [String: [Double]]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    @ViewBuilder func accountMeasure(_ key: String) -> some View {
#if DEBUG
        background(GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Color.clear.preference(key: AccountFramePreference.self,
                                   value: [key: [frame.minX, frame.minY, frame.width, frame.height]])
        })
#else
        self
#endif
    }
}

struct AccountCaptureProbe: ViewModifier {
#if DEBUG
    @State private var frames: [String: [Double]] = [:]
#endif
    func body(content: Content) -> some View {
#if DEBUG
        content.onPreferenceChange(AccountFramePreference.self) { frames = $0 }
            .overlay(alignment: .topLeading) {
                if AccountCaptureFixture.readOnly {
                    Color.clear.frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier("account.geometry")
                        .accessibilityValue(String(data: (try? JSONSerialization.data(withJSONObject: frames, options: [.sortedKeys])) ?? Data(), encoding: .utf8) ?? "{}")
                        .allowsHitTesting(false)
                }
            }
#else
        content
#endif
    }
}
