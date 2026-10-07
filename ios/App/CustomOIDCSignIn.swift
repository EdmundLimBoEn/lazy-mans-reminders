import Foundation

/// Shared Supabase custom-OIDC sign-in for providers the pinned supabase-swift
/// release cannot name. Identity scopes only. The app never asks for a refresh
/// token or for permission to spend a provider plan.
enum CustomOIDCSignIn {
    static let identityScopes = "openid profile email"

    /// Scopes that would authorize token or plan spend, or a long-lived grant.
    static let spendScopes = [
        "offline_access",
        "resource.invoke",
        "chatgpt.tokens.use.direct",
        "api:access",
        "grok-cli:access",
        "conversations:read",
        "conversations:write",
    ]

    struct Provider: Equatable, Sendable {
        let supabaseIdentifier: String
        let infoKey: String
        /// Debug-only launch argument, used by the simulator UI test.
        let launchArgument: String

        static let grok = Provider(
            supabaseIdentifier: "custom:grok",
            infoKey: "GROK_SIGN_IN_ENABLED",
            launchArgument: "-LMRGrokSignIn"
        )
        static let chatgpt = Provider(
            supabaseIdentifier: "custom:chatgpt",
            infoKey: "CHATGPT_SIGN_IN_ENABLED",
            launchArgument: "-LMRChatGPTSignIn"
        )
    }

    enum AuthorizeURLError: Error, Equatable {
        case malformed
        case missingPKCE
    }

    static func isEnabled(_ provider: Provider) -> Bool {
        isEnabled(
            provider,
            infoValue: Bundle.main.object(forInfoDictionaryKey: provider.infoKey),
            launchArguments: ProcessInfo.processInfo.arguments,
            allowLaunchOverride: isDebugBuild
        )
    }

    /// `allowLaunchOverride` is on only for Debug builds, so a TestFlight
    /// binary cannot be flipped from its xcconfig flag.
    static func isEnabled(
        _ provider: Provider,
        infoValue: Any?,
        launchArguments: [String],
        allowLaunchOverride: Bool
    ) -> Bool {
        if allowLaunchOverride,
           let override = launchFlag(provider.launchArgument, in: launchArguments) {
            return override
        }
        return flag(infoValue)
    }

    static func flag(_ infoValue: Any?) -> Bool {
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
    /// Supabase also replaces a custom provider's configured scopes with this
    /// `scopes` parameter, so every request pins the identity scopes.
    static func authorizeURL(rewriting url: URL, provider: Provider) throws -> URL {
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
        items.insert(URLQueryItem(name: "provider", value: provider.supabaseIdentifier), at: 0)
        items.insert(URLQueryItem(name: "scopes", value: identityScopes), at: 1)
        components.queryItems = items
        guard let rewritten = components.url else { throw AuthorizeURLError.malformed }
        return rewritten
    }

    static func requestedScopes(in url: URL) -> Set<String> {
        let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "scopes" }?
            .value ?? ""
        return Set(raw.split(separator: " ").map(String.init))
    }

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

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static func launchFlag(_ name: String, in arguments: [String]) -> Bool? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
            return nil
        }
        return flag(arguments[index + 1])
    }
}

enum GrokSignIn {
    static let supabaseProvider = CustomOIDCSignIn.Provider.grok.supabaseIdentifier
    static let scopes = CustomOIDCSignIn.identityScopes
    typealias AuthorizeURLError = CustomOIDCSignIn.AuthorizeURLError

    static var isEnabled: Bool { CustomOIDCSignIn.isEnabled(.grok) }

    static func isEnabled(infoValue: Any?) -> Bool {
        CustomOIDCSignIn.flag(infoValue)
    }

    static func authorizeURL(rewriting url: URL) throws -> URL {
        try CustomOIDCSignIn.authorizeURL(rewriting: url, provider: .grok)
    }

    static func identitySummary(claims: [String: String]) -> String {
        CustomOIDCSignIn.identitySummary(claims: claims)
    }
}

enum ChatGPTSignIn {
    static let supabaseProvider = CustomOIDCSignIn.Provider.chatgpt.supabaseIdentifier
    static let issuer = "https://auth.openai.com"
    static let scopes = CustomOIDCSignIn.identityScopes
    typealias AuthorizeURLError = CustomOIDCSignIn.AuthorizeURLError

    static var isEnabled: Bool { CustomOIDCSignIn.isEnabled(.chatgpt) }

    static func authorizeURL(rewriting url: URL) throws -> URL {
        try CustomOIDCSignIn.authorizeURL(rewriting: url, provider: .chatgpt)
    }
}
