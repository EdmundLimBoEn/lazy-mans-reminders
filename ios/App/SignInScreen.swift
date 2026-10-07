import Foundation

/// Which sign-in controls the screen shows, in order. Sign in with Apple is
/// always first so it stays at least as prominent as ChatGPT or Grok.
enum SignInScreen {
    enum Control: String, CaseIterable, Identifiable, Equatable {
        case apple
        case chatgpt
        case grok
        case google

        var id: String { rawValue }

        var accessibilityIdentifier: String { "sign-in-\(rawValue)" }
    }

    static func controls(grokEnabled: Bool, chatgptEnabled: Bool) -> [Control] {
        var rows: [Control] = [.apple]
        if chatgptEnabled { rows.append(.chatgpt) }
        if grokEnabled { rows.append(.grok) }
        rows.append(.google)
        return rows
    }
}
