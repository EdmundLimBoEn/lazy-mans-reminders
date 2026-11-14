import Foundation

/// No board cache, widget publication, or scheduler work belongs in this store.
actor RoutineStore {
    static let shared = RoutineStore()
    static let columns = "id,text,interval_days,start_date,local_time,timezone,enabled,next_run_at"
    private let sessionStore: ReminderStore
    private let serviceURL: URL?
    private let anonKey: String?
    private let requestData: (URLRequest) async throws -> (Data, URLResponse)

    init(sessionStore: ReminderStore = .shared, serviceURL: URL? = nil, anonKey: String? = nil,
         requestData: @escaping (URLRequest) async throws -> (Data, URLResponse) = {
             try await URLSession.shared.data(for: $0)
         }) {
        self.sessionStore = sessionStore
        self.serviceURL = serviceURL
        self.anonKey = anonKey
        self.requestData = requestData
    }

    enum StoreError: LocalizedError {
        case invalidResponse, unavailable, requestFailed(Int), server(String)
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "The reminders service returned an invalid response."
            case .unavailable: return "This routine is no longer available. Refresh and try again."
            case .requestFailed(let code): return "The reminders service returned HTTP \(code)."
            case .server(let message): return message
            }
        }
    }

    func list(userID: UUID) async throws -> [Routine] {
        let data = try await request(method: "GET", userID: userID)
        return try ReminderJSON.decoder.decode([Routine].self, from: data)
    }

    func save(_ draft: RoutineDraft, userID: UUID) async throws {
        let values = try draft.values()
        var body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(values)) as! [String: Any]
        if draft.original == nil {
            body["user_id"] = userID.uuidString
            body["enabled"] = true
        }
        let data = try await request(method: draft.original == nil ? "POST" : "PATCH", userID: userID,
                                     id: draft.original?.id, body: JSONSerialization.data(withJSONObject: body))
        try acknowledge(data, id: draft.original?.id)
    }

    func setEnabled(_ enabled: Bool, id: UUID, userID: UUID) async throws {
        let data = try await request(method: "PATCH", userID: userID, id: id,
                                     body: JSONSerialization.data(withJSONObject: ["enabled": enabled]))
        try acknowledge(data, id: id)
    }

    func delete(id: UUID, userID: UUID) async throws {
        // Deleting this definition preserves the generated reminder on the board.
        _ = try await request(method: "DELETE", userID: userID, id: id)
    }

    private func acknowledge(_ data: Data, id: UUID?) throws {
        struct Acknowledgement: Decodable { let id: UUID }
        guard let rows = try? JSONDecoder().decode([Acknowledgement].self, from: data) else {
            throw StoreError.invalidResponse
        }
        guard !rows.isEmpty else { throw StoreError.unavailable }
        guard rows.count == 1, id == nil || rows[0].id == id else { throw StoreError.invalidResponse }
    }

    private func request(method: String, userID: UUID, id: UUID? = nil, body: Data? = nil) async throws -> Data {
        let snapshot = try await sessionStore.requestSession(for: userID)
        try Task.checkCancellation()
        var components = URLComponents(url: (serviceURL ?? AppConfig.supabaseURL)
            .appending(path: "rest/v1/routine_reminders"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")]
        if let id { components.queryItems?.append(URLQueryItem(name: "id", value: "eq.\(id.uuidString)")) }
        if method == "GET" {
            components.queryItems?.append(URLQueryItem(name: "select", value: Self.columns))
            components.queryItems?.append(URLQueryItem(name: "order", value: "created_at.asc"))
        } else if method != "DELETE" {
            components.queryItems?.append(URLQueryItem(name: "select", value: "id"))
        }
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("ios", forHTTPHeaderField: "x-notepad-client")
        request.setValue(anonKey ?? AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(snapshot.session.accessToken)", forHTTPHeaderField: "Authorization")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if method == "POST" || method == "PATCH" {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        let (data, response) = try await requestData(request)
        try Task.checkCancellation()
        try await sessionStore.validateRequestSession(snapshot)
        guard let http = response as? HTTPURLResponse else { throw StoreError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            struct ServerError: Decodable { let message: String }
            if let error = try? JSONDecoder().decode(ServerError.self, from: data) {
                throw StoreError.server(error.message)
            }
            throw StoreError.requestFailed(http.statusCode)
        }
        return data
    }
}
