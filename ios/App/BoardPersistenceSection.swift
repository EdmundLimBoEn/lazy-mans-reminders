import ActivityKit
import SwiftUI

struct BoardPersistenceSection: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var registration: PushTokenRegistrar
    @State private var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @State private var backgroundRefresh = UIApplication.shared.backgroundRefreshStatus
    @State private var isRefreshing = false
    @State private var result: String?
    @State private var announcements = AccountErrorAnnouncementPolicy()
    var fixtureRecovery: () -> Void = {}

    init(registration: PushTokenRegistrar, fixtureRecovery: @escaping () -> Void = {}) {
        self.registration = registration
        self.fixtureRecovery = fixtureRecovery
#if DEBUG
        _result = State(initialValue: AccountCaptureFixture.state == "refresh-error" ? AccountCaptureFixture.refreshError : nil)
#endif
    }

    var body: some View {
        Section {
            LabeledContent("Live Activities", value: liveActivitiesEnabled ? "Allowed" : "Off")
            LabeledContent("Background App Refresh", value: refreshStatus)
            if let lastSuccess = registration.lastSuccess {
                LabeledContent("Live Activity connection") {
                    Text(lastSuccess, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }
            if registration.needsRetry {
                Text("The Live Activity connection needs another try. Check your connection and refresh the board.")
                    .font(.footnote)
            }
            Button {
                Task { await refreshBoard() }
            } label: {
                Text(isRefreshing ? "Refreshing…" : "Refresh Board Now")
                    .accountMeasure("refresh.title")
            }
            .disabled(isRefreshing)
            if let result { Text(result).font(.footnote).foregroundStyle(.primary).accessibilityIdentifier("account.refreshResult") }
            Button("Open App Settings") {
                if !AccountCaptureFixture.readOnly, let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            DisclosureGroup {
                Text("Home Screen: touch and hold an empty area, choose Edit → Add Widget, then Notepad → Board.")
                    .accountMeasure("home.helper")
                    .font(.footnote)
                    .foregroundStyle(.primary.opacity(0.75))
                Text("Lock Screen: touch and hold it, choose Customize → Lock Screen → Add Widgets, then Notepad.")
                    .accountMeasure("lock.helper")
                    .font(.footnote)
                    .foregroundStyle(.primary.opacity(0.75))
                Text("Widgets keep the last synced board visible. iOS decides when they refresh, so changes may take time to appear.")
                    .accountMeasure("widget.helper")
                    .font(.footnote)
                    .foregroundStyle(.primary.opacity(0.75))
            } label: {
                Text("Add a lasting widget")
                    .accountMeasure("disclosure.title")
            }
        } header: {
            Text("Keep Your Board Visible")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(AccountGuidance.activity)
                    .fixedSize(horizontal: false, vertical: true)
                    .accountMeasure("persistence.activity")
                    .accessibilityIdentifier("account.guidance.activity")
                Text(AccountGuidance.background)
                    .fixedSize(horizontal: false, vertical: true)
                    .accountMeasure("persistence.background")
                    .accessibilityIdentifier("account.guidance.background")
            }
            .accountMeasure("persistence.footer")
            .foregroundStyle(.primary.opacity(0.75))
        }
        .onChange(of: result, initial: true) { _, message in
            if let announcement = announcements.announcement(for: message) {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
            backgroundRefresh = UIApplication.shared.backgroundRefreshStatus
        }
    }

    private var refreshStatus: String {
        switch backgroundRefresh {
        case .available: return "Available"
        case .denied: return "Off or Low Power Mode"
        case .restricted: return "Restricted"
        @unknown default: return "Unavailable"
        }
    }

    @MainActor
    private func refreshBoard() async {
        if AccountCaptureFixture.readOnly {
#if DEBUG
            if AccountCaptureFixture.enabledAppearance {
                fixtureRecovery()
                if AccountCaptureFixture.state == "refresh-error" {
                    result = result == nil ? AccountCaptureFixture.refreshError : nil
                }
            }
#endif
            return
        }
        result = nil
        _ = announcements.announcement(for: nil)
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            await auth.registerLiveActivityTokens()
            let reminders = try await ReminderStore.shared.refresh()
            await ReminderBoardSync.apply(reminders)
            result = "Board refreshed."
        } catch {
            result = "Couldn’t refresh. Your saved board is still available."
        }
    }
}

enum AccountGuidance {
    static let activity = "iOS limits each Live Activity to eight hours. We try to renew it automatically, but renewal can be delayed."
    static let background = "Background App Refresh helps sync when iOS allows; it does not keep the app running. Leave the app in the background instead of swiping it away. Use a widget for reminders you want visible overnight."
}
