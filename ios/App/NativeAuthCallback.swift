import Foundation

/// Structural validation only; the SDK still verifies the PKCE code and verifier.
enum NativeAuthCallback: Equatable {
    case code
    case error

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "lazymansreminders",
              components.host?.lowercased() == "auth",
              components.percentEncodedPath == "/callback",
              components.user == nil, components.password == nil, components.port == nil
        else { return nil }

        // Match the SDK's query/fragment inputs, but reject ambiguous duplicates.
        var fragment = URLComponents()
        fragment.percentEncodedQuery = components.percentEncodedFragment
        let items = (components.queryItems ?? []) + (fragment.queryItems ?? [])
        let allowed: Set<String> = ["code", "type", "sb", "sb_flow_id",
                                    "error", "error_code", "error_description"]
        var parameters: [String: String] = [:]
        for item in items {
            guard allowed.contains(item.name), parameters[item.name] == nil,
                  let value = item.value else { return nil }
            parameters[item.name] = value
        }

        let errors = ["error", "error_code", "error_description"]
        if errors.contains(where: { parameters[$0] != nil }) {
            guard parameters["code"] == nil,
                  let error = parameters["error"],
                  !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  errors.allSatisfy({ key in
                      parameters[key].map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? true
                  })
            else { return nil }
            self = .error
        } else {
            // AuthSessionClient uses the SDK's default PKCE flow, not implicit tokens.
            guard let code = parameters["code"], !code.isEmpty,
                  code.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
            else { return nil }
            self = .code
        }
    }
}
