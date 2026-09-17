import SwiftUI
import UserNotifications

struct AccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSignOut = false
    @State private var showDeleteAccount = false
    @State private var isDeletingAccount = false
    @State private var error: String?
    @State private var notificationAccess = NotificationAccessPolicy.Access.ask

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }

                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(accountTitle)
                                .font(.headline)
                                .textSelection(.enabled)
                            if let subtitle = accountSubtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    } icon: {
                        Image(systemName: "person.crop.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)
                            .imageScale(.large)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accountAccessibilityLabel)
                }

                Section {
                    notificationRow
                } footer: {
                    Text(NotificationAccessPolicy.footer(notificationAccess))
                }

                Section {
                    Button {
                        showSignOut = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(isDeletingAccount)
                    .accessibilityHint("Signs you out on this iPhone")
                }

                Section {
                    Link(destination: LMRWeb.privacy) {
                        Label("Privacy", systemImage: "hand.raised")
                    }
                    Link(destination: LMRWeb.terms) {
                        Label("Terms", systemImage: "doc.plaintext")
                    }
                    Link(destination: LMRWeb.support) {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                    Link(destination: LMRWeb.dataExport) {
                        Label("Download My Data", systemImage: "square.and.arrow.down")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAccount = true
                    } label: {
                        Label("Delete Account…", systemImage: "trash")
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    Text("Deletes reminders, device registrations, lock-screen prefs, agent access, and this sign-in.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isDeletingAccount)
            .sensoryFeedback(.error, trigger: error)
            .task { await refreshNotificationAccess() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refreshNotificationAccess() }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isDeletingAccount {
                        ProgressView()
                            .accessibilityLabel("Deleting account")
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .disabled(isDeletingAccount)
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign Out") {
                    Task { await auth.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can sign back in with Apple, Google, or email.")
            }
            .alert("Delete Account?", isPresented: $showDeleteAccount) {
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your reminders, device registrations, lock-screen prefs, agent access, and sign-in. This can’t be undone.")
            }
        }
    }

    private var accountEmail: String? {
        let email = auth.session?.user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let email, !email.isEmpty { return email }
        return nil
    }

    private var accountTitle: String {
        accountEmail ?? "Signed In"
    }

    private var accountSubtitle: String? {
        if let caption = AccountSessionCaption.methodCaption(
            providers: auth.session?.user.identities?.map(\.provider) ?? []
        ) {
            return caption
        }
        if accountEmail != nil {
            return "Signed in on this iPhone"
        }
        return nil
    }

    private var accountAccessibilityLabel: String {
        if let accountEmail {
            return "Account, \(accountEmail)"
        }
        return "Account, signed in"
    }

    @ViewBuilder
    private var notificationRow: some View {
        switch notificationAccess {
        case .allowed:
            LabeledContent("Notifications", value: NotificationAccessPolicy.value(notificationAccess))
        case .ask:
            Button("Allow Notifications") {
                Task {
                    await AppDelegate.requestPushIfNeeded()
                    await refreshNotificationAccess()
                }
            }
        case .blocked:
            Button {
                if let url = NotificationAccessPolicy.notificationSettingsURL() {
                    openURL(url)
                }
            } label: {
                HStack {
                    Text("Notifications")
                    Spacer()
                    Text(NotificationAccessPolicy.value(notificationAccess))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHint("Opens Settings so you can allow notifications")
        }
    }

    private func refreshNotificationAccess() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAccess = NotificationAccessPolicy.access(for: settings.authorizationStatus)
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        do {
            try await auth.deleteAccount()
        } catch {
            self.error = error.localizedDescription
            isDeletingAccount = false
        }
    }
}
