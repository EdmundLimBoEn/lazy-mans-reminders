import SwiftUI

enum LMRWeb {
    static let origin = URL(string: "https://lmr.edmundlim.systems")!
    static let privacy = URL(string: "https://lmr.edmundlim.systems/privacy")!
    static let terms = URL(string: "https://lmr.edmundlim.systems/terms")!
    static let support = URL(string: "https://lmr.edmundlim.systems/support")!
    static let dataExport = origin
}

/// Fill for `SignInWithAppleButton`. Dark mode uses `.black` so the control
/// matches the rest of a dark grouped card instead of a light-mode pill (#22).
/// Do not name `SignInWithAppleButtonStyle` here: on the iOS 27 SDK that type
/// lives in the `_AuthenticationServices_SwiftUI` overlay and is not in scope
/// as a return type even with `import AuthenticationServices`.
enum SignInAppleFill: Equatable {
    case black
    case white

    static func fill(for colorScheme: ColorScheme) -> SignInAppleFill {
        colorScheme == .dark ? .black : .white
    }
}

enum AccountSessionCaption {
    static func methodCaption(providers: [String]) -> String? {
        let set = Set(providers)
        if set.contains("apple") { return "Using Sign in with Apple" }
        if set.contains("google") { return "Using Google" }
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
