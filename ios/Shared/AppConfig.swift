import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: value)
        else { fatalError("SUPABASE_URL is missing from Config.xcconfig") }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !value.isEmpty
        else { fatalError("SUPABASE_ANON_KEY is missing from Config.xcconfig") }
        return value
    }()

    static let appGroupID: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String,
              !value.isEmpty
        else { fatalError("APP_GROUP_ID is missing from Config.xcconfig") }
        return value
    }()
}
