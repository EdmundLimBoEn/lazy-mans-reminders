import Foundation

/// Sign in with Grok goes through a Supabase custom OIDC provider whose issuer
/// is `https://auth.x.ai`. Supabase holds the xAI client secret, runs PKCE
/// against xAI, verifies the ID token, and links the identity; the app only
/// runs the usual Supabase PKCE leg. Identity scopes only: no xAI API,
/// conversation, or offline access.
enum GrokSignIn {
    /// Must match the identifier of the custom provider in Supabase Auth.
    static let supabaseProvider = "custom:grok"

    /// Supabase replaces a custom provider's configured scopes with the
    /// `scopes` query parameter, so the app pins them on every request.
    static let scopes = "openid profile email"

    enum AuthorizeURLError: Error, Equatable {
        case malformed
        case missingPKCE
    }

    static var isEnabled: Bool {
        isEnabled(infoValue: Bundle.main.object(forInfoDictionaryKey: "GROK_SIGN_IN_ENABLED"))
    }

    /// Off unless the build sets `GROK_SIGN_IN_ENABLED = YES`; an unset
    /// xcconfig value expands to an empty string.
    static func isEnabled(infoValue: Any?) -> Bool {
        if let value = infoValue as? Bool { return value }
        guard let raw = infoValue as? String else { return false }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "yes", "true", "1": return true
        default: return false
        }
    }

    /// supabase-swift 2.54's `Provider` is a closed enum without `custom:`
    /// identifiers. Its OAuth helper still owns the PKCE verifier, so the app
    /// asks it for a built-in provider URL and swaps the provider here.
    static func authorizeURL(rewriting url: URL) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthorizeURLError.malformed
        }
        var items = (components.queryItems ?? []).filter {
            $0.name != "provider" && $0.name != "scopes"
        }
        let challenge = items.first { $0.name == "code_challenge" }?.value ?? ""
        let method = items.first { $0.name == "code_challenge_method" }?.value?.lowercased()
        guard !challenge.isEmpty, method == "s256" else {
            throw AuthorizeURLError.missingPKCE
        }
        items.insert(URLQueryItem(name: "provider", value: supabaseProvider), at: 0)
        items.insert(URLQueryItem(name: "scopes", value: scopes), at: 1)
        components.queryItems = items
        guard let rewritten = components.url else { throw AuthorizeURLError.malformed }
        return rewritten
    }

    /// One line for Account: the name and email xAI shared at sign-in.
    static func identitySummary(claims: [String: String]) -> String {
        let name = claims["name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = claims["email"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch (name.isEmpty, email.isEmpty) {
        case (false, false) where name.caseInsensitiveCompare(email) != .orderedSame:
            return "\(name) · \(email)"
        case (_, false): return email
        case (false, true): return name
        case (true, true): return "Connected"
        }
    }
}
