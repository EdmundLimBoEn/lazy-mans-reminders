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
            Button(isRefreshing ? "Refreshing…" : "Refresh Board Now") {
                Task { await refreshBoard() }
            }
            .disabled(isRefreshing)
            if let result { Text(result).font(.footnote).accessibilityAddTraits(.updatesFrequently) }
            Button("Open App Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            DisclosureGroup("Add a lasting widget") {
                Text("Home Screen: touch and hold an empty area, choose Edit → Add Widget, then Lazy Man’s Reminders → Board.")
                Text("Lock Screen: touch and hold it, choose Customize → Lock Screen → Add Widgets, then Lazy Man’s Reminders.")
                Text("Widgets keep the last synced board visible. iOS decides when they refresh, so changes may take time to appear.")
            }
            .font(.footnote)
        } header: {
            Text("Keep Your Board Visible")
        } footer: {
            Text("iOS limits each Live Activity to eight hours. We try to renew it automatically, but renewal can be delayed. Background App Refresh helps sync when iOS allows; it does not keep the app running. Leave the app in the background instead of swiping it away. Use a widget for reminders you want visible overnight.")
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
