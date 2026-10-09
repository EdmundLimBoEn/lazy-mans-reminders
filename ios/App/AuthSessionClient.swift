import Foundation
import Supabase

/// Uses the existing auth storage but keeps all token refresh reads caller-controlled.
@MainActor
final class AuthSessionClient {
    let auth: AuthClient
    private let dataClient: SupabaseClient

    init(supabaseURL: URL = AppConfig.supabaseURL,
         supabaseKey: String = AppConfig.supabaseAnonKey,
         storage: any AuthLocalStorage = AuthClient.Configuration.defaultLocalStorage,
         authFetch: @escaping AuthClient.FetchHandler = { try await URLSession.shared.data(for: $0) },
         globalSession: URLSession = .shared) {
        // Preserve SupabaseClient's existing Keychain namespace.
        let storageKey = "sb-\(supabaseURL.host!.split(separator: ".")[0])-auth-token"
        let auth = AuthClient(
            url: supabaseURL.appending(path: "auth/v1"),
            headers: ["apikey": supabaseKey,
                      "Authorization": "Bearer \(supabaseKey)"],
            storageKey: storageKey,
            localStorage: storage,
            fetch: authFetch,
            autoRefreshToken: false
        )
        self.auth = auth
        // The SDK's internal auth listener can refresh outside our session gate.
        // A supplied token callback disables that listener; never use dataClient.auth.
        dataClient = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: .init(auth: .init(storage: storage, storageKey: storageKey,
                                       autoRefreshToken: false, accessToken: {
                try await auth.session.accessToken
            }), global: .init(session: globalSession))
        )
    }

    func from(_ table: String) -> PostgrestQueryBuilder { dataClient.from(table) }

    var functions: FunctionsClient { dataClient.functions }
}
