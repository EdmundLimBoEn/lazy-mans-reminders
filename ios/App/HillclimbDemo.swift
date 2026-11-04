import SwiftUI

#if DEBUG
import Supabase
import UIKit
import UserNotifications

/// Explicit launch arguments are the only switch; normal Debug launches stay live.
enum HillclimbDemo {
    enum Mode: String, CaseIterable { case full, empty, composer, account, signin, longText = "long-text", activity }
    static func argument(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: key), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
    static let mode = argument("--hillclimb-demo").flatMap(Mode.init(rawValue:))
    static var isActive: Bool { mode != nil }
    static let defaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: "Notepad.Hillclimb.Demo")!
        defaults.removePersistentDomain(forName: "Notepad.Hillclimb.Demo")
        return defaults
    }()
    static func reminders(for mode: Mode) -> [Reminder] {
        guard mode != .empty && mode != .composer && mode != .signin else { return [] }
        return (1...ReminderBoardLimits.maxActive).map { index in
            Reminder(
                id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!,
                userID: UUID(uuidString: "00000000-0000-4000-8000-999999999999")!,
                text: "Demo \(index): " + String(repeating: "Review the sample notes and gather the details for tomorrow. ", count: mode == .longText ? 5 : 3),
                sortOrder: index, isDone: false, createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
    }
    @MainActor static func offlineClient() -> AuthSessionClient {
        precondition(AppConfig.appGroupID == "group.systems.edmundlim.NotepadHillclimb",
                     "Hillclimb requires isolated example Config.xcconfig; see hillclimb/harness.md")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HillclimbBlockedNetwork.self]
        return AuthSessionClient(supabaseURL: URL(string: "https://hillclimb.invalid")!,
                                 supabaseKey: "demo-only", storage: HillclimbEmptyAuthStorage(),
                                 authFetch: { _ in throw URLError(.notConnectedToInternet) },
                                 globalSession: URLSession(configuration: config))
    }
}

private struct HillclimbEmptyAuthStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws { throw URLError(.notConnectedToInternet) }
    func retrieve(key: String) throws -> Data? { nil }
    func remove(key: String) throws {}
}
private final class HillclimbBlockedNetwork: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}

/// Forward normal Debug delegate callbacks unchanged; demo never constructs AppDelegate.
final class HillclimbLaunchDelegate: NSObject, UIApplicationDelegate {
    private let production: AppDelegate? = HillclimbDemo.isActive ? nil : AppDelegate()
    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (production?.responds(to: selector) ?? false)
    }
    override func forwardingTarget(for selector: Selector!) -> Any? {
        if production?.responds(to: selector) == true { return production }
        return super.forwardingTarget(for: selector)
    }
}

struct HillclimbRoot: View {
    var body: some View {
        Group {
            if HillclimbDemo.mode == .signin {
                SignInView()
            } else {
                ReminderListView(hillclimb: HillclimbDemo.mode)
            }
        }
        .task { await HillclimbActivityDemo.runIfRequested() }
        .defaultAppStorage(HillclimbDemo.defaults)
        .preferredColorScheme(HillclimbDemo.argument("--hillclimb-style") == "dark" ? .dark : .light)
        .modifier(HillclimbTypeSize())
        .overlay(alignment: .topLeading) { HillclimbGeometryExport().frame(width: 1, height: 1).allowsHitTesting(false) }
    }
}
private struct HillclimbTypeSize: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if HillclimbDemo.argument("--hillclimb-size") == "XXXL" {
            content.dynamicTypeSize(.xxxLarge)
        } else { content.dynamicTypeSize(.large) }
    }
}
#endif
