import Combine
import Foundation

/// Owns the pending registration independently of any SwiftUI scene.
@MainActor
final class PushTokenRegistrar: ObservableObject {
    struct Registration: Encodable, Equatable {
        let token: String
        let userID: UUID
        let environment: String
        let pushToStartToken: String?
        let activityPushToken: String?

        enum CodingKeys: String, CodingKey {
            case token, environment
            case userID = "user_id"
            case pushToStartToken = "push_to_start_token"
            case activityPushToken = "activity_push_token"
        }
    }

    private struct Pending: Codable {
        var deviceToken: String?
        var userID: UUID?
        var pushToStartToken: String?
        var activityPushToken: String?
        var lastSuccess: Date?
    }

    @Published private(set) var lastSuccess: Date?
    @Published private(set) var needsRetry = false
    private let defaults: UserDefaults
    private let key: String
    private let environment: String
    private let upload: (Registration) async throws -> Void
    private let retryDelay: () async throws -> Void
    private var pending: Pending
    private var revision = 0
    private var isUploading = false

    init(
        defaults: UserDefaults = .standard,
        environment: String = PushTokenRegistrar.environment,
        retryDelay: @escaping () async throws -> Void = { try await Task.sleep(nanoseconds: 500_000_000) },
        upload: @escaping (Registration) async throws -> Void
    ) {
        self.defaults = defaults
        self.environment = environment
        self.key = "push-registration-\(environment)"
        self.upload = upload
        self.retryDelay = retryDelay
        self.pending = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(Pending.self, from: $0) } ?? Pending()
        self.lastSuccess = pending.lastSuccess
        self.needsRetry = pending.activityPushToken != nil
    }

    nonisolated static var environment: String {
#if DEBUG
        "development"
#else
        "production"
#endif
    }

    var deviceToken: String? { pending.deviceToken }

    func bind(userID: UUID?) {
        guard pending.userID != userID || userID == nil else { return }
        if userID == nil || pending.userID != nil {
            pending.activityPushToken = nil
            pending.lastSuccess = nil
            lastSuccess = nil
        }
        pending.userID = userID
        save()
    }

    func recordDeviceToken(_ token: String) {
        pending.deviceToken = token
        save()
    }

    func recordPushToStartToken(_ token: String) {
        pending.pushToStartToken = token
        save()
    }

    func recordActivityToken(_ token: String) {
        pending.activityPushToken = token
        needsRetry = true
        save()
    }

    func flush() async {
        guard !isUploading else { return }
        isUploading = true
        defer { isUploading = false }
        while let deviceToken = pending.deviceToken, let userID = pending.userID {
            let sentRevision = revision
            let registration = Registration(
                token: deviceToken, userID: userID, environment: environment,
                pushToStartToken: pending.pushToStartToken,
                activityPushToken: pending.activityPushToken
            )
            var succeeded = false
            for attempt in 0..<3 {
                do {
                    try Task.checkCancellation()
                    try await upload(registration)
                    succeeded = true
                    break
                } catch {
                    guard !Task.isCancelled else { return }
                    if revision != sentRevision { break }
                    if attempt < 2 { try? await retryDelay() }
                }
            }
            guard revision == sentRevision else { continue }
            needsRetry = !succeeded
            if succeeded {
                // Replaying an acknowledged old token could undo the server's renewal handoff.
                pending.activityPushToken = nil
                pending.lastSuccess = Date()
                lastSuccess = pending.lastSuccess
                save()
            }
            return
        }
    }

    private func save() {
        revision += 1
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: key)
        }
    }
}
