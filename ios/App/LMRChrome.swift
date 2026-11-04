import SwiftUI

enum LMRWeb {
    static let origin = URL(string: "https://np.sillyapps.co")!
    static let privacy = URL(string: "https://np.sillyapps.co/privacy")!
    static let terms = URL(string: "https://np.sillyapps.co/terms")!
    static let support = URL(string: "https://np.sillyapps.co/support")!
    static let dataExport = origin
    /// Magic-link landing page. Safari cannot follow a 303 onto a custom
    /// scheme, so the email link opens this HTTPS page, which hands off to
    /// `lazymansreminders://auth/callback`. Must be in the Supabase Auth
    /// redirect allow list.
    static let iosAuthRedirect = URL(string: "https://np.sillyapps.co/auth/ios")!
}

/// Native outlined white fill keeps a visible boundary on both system backgrounds.
/// Keep the SDK overlay style type inside the View extension.
enum SignInAppleFill: Equatable {
    case whiteOutline

    static func fill(for colorScheme: ColorScheme) -> SignInAppleFill {
        .whiteOutline
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
