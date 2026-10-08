import SwiftUI

enum LMRWeb {
    static let origin = URL(string: "https://lmr.sillyapps.co")!
    static let privacy = URL(string: "https://lmr.sillyapps.co/privacy")!
    static let terms = URL(string: "https://lmr.sillyapps.co/terms")!
    static let support = URL(string: "https://lmr.sillyapps.co/support")!
    static let dataExport = origin
    /// Magic-link landing page. Safari cannot follow a 303 onto a custom
    /// scheme, so the email link opens this HTTPS page, which hands off to
    /// `lazymansreminders://auth/callback`. Must be in the Supabase Auth
    /// redirect allow list.
    static let iosAuthRedirect = URL(string: "https://lmr.sillyapps.co/auth/ios")!
}

/// Fill for `SignInWithAppleButton`. Dark mode uses `.black` so the control
/// matches the rest of a dark grouped card instead of a light-mode pill (#22).
/// Light mode uses `.whiteOutline` so a white fill still has a bezel on a
/// light grouped card. Do not name `SignInWithAppleButtonStyle` here: on the
/// iOS 27 SDK that type lives in the `_AuthenticationServices_SwiftUI`
/// overlay and is not in scope as a return type even with
/// `import AuthenticationServices`.
enum SignInAppleFill: Equatable {
    case black
    case whiteOutline

    static func fill(for colorScheme: ColorScheme) -> SignInAppleFill {
        colorScheme == .dark ? .black : .whiteOutline
    }
}

enum AccountSessionCaption {
    static func methodCaption(providers: [String]) -> String? {
        let set = Set(providers)
        if set.contains("apple") { return "Using Sign in with Apple" }
        if set.contains("google") { return "Using Google" }
        if set.contains("email") { return "Using Email" }
        return nil
    }
}

enum SignInEmail {
    static func isPlausible(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return !parts[0].isEmpty && !parts[1].isEmpty
    }
}
