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
    @State private var errorAnnouncements = AccountErrorAnnouncementPolicy()

    init() {
#if DEBUG
        _error = State(initialValue: AccountCaptureFixture.error)
#endif
    }
    @State private var notificationAccess = NotificationAccessPolicy.Access.ask
    private var appInfo: FeedbackMail.AppInfo { .current }

    var body: some View {
        NavigationStack {
            List {
                Group {
                    if let error {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("account.error")
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
                            Text(accountInitial)
                                .font(.headline)
                                .foregroundStyle(Color(.systemBackground))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.primary))
                        }
                        .listRowBackground(Color.clear)
                        .accountMeasure("identity.row")
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accountAccessibilityLabel)
                    }

                    Section {
                        notificationRow
                    } footer: {
                        Text(NotificationAccessPolicy.footer(notificationAccess))
                            .accountMeasure("notifications.footer")
                            .foregroundStyle(.primary.opacity(0.75))
                    }

                    BoardPersistenceSection(registration: auth.pushRegistration, fixtureRecovery: {
#if DEBUG
                        if AccountCaptureFixture.state == "error" {
                            error = error == nil ? AccountCaptureFixture.signOutError : nil
                        }
#endif
                    })

                    Section {
                        Button {
                            guard !hillclimbReadOnly else { return }
                            showSignOut = true
                        } label: {
                            AccountRow("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .disabled(isDeletingAccount)
                        .accessibilityHint("Signs you out on this iPhone")
                    }

                    Section {
                        Link(destination: LMRWeb.privacy) {
                            AccountRow("Privacy", systemImage: "hand.raised", external: true)
                        }
                        Link(destination: LMRWeb.terms) {
                            AccountRow("Terms", systemImage: "doc.plaintext", external: true)
                        }
                        Link(destination: LMRWeb.support) {
                            AccountRow("Support", systemImage: "questionmark.circle", external: true)
                        }
                        Link(destination: LMRWeb.dataExport) {
                            AccountRow("Download My Data", systemImage: "square.and.arrow.down", external: true)
                        }
                    }

                    Section {
                        if let feedbackURL = FeedbackMail.url(appInfo) {
                            Link(destination: feedbackURL) {
                                AccountRow("Send Feedback", systemImage: "envelope", external: true)
                            }
                            .accessibilityHint("Opens Mail with your app and iOS version filled in")
                        }
                    } footer: {
                        Text("Or email \(FeedbackMail.address)")
                            .accountMeasure("feedback.footer")
                            .foregroundStyle(.primary.opacity(0.75))
                            .textSelection(.enabled)
                    }

                    Section {
                        Button(role: .destructive) {
                            guard !hillclimbReadOnly else { return }
                            showDeleteAccount = true
                        } label: {
                            AccountRow("Delete Account…", systemImage: "trash", destructive: true)
                        }
                        .disabled(isDeletingAccount)
                    } footer: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Deletes reminders, device registrations, lock-screen prefs, agent access, and this sign-in.")
                                .accountMeasure("delete.footer")
                                .foregroundStyle(Color(.label))
                            Text(FeedbackMail.versionFooter(appInfo))
                                .accountMeasure("version.footer")
                                .foregroundStyle(Color(.label))
                                .textSelection(.enabled)
                                .accessibilityLabel("App \(FeedbackMail.versionFooter(appInfo))")
                        }
                    }
                }
                .disabled(hillclimbReadOnly && !AccountCaptureFixture.enabledAppearance)
                .allowsHitTesting(!hillclimbReadOnly || AccountCaptureFixture.enabledAppearance)
            }
            .accessibilityIdentifier("account.settings")
            .environment(\.defaultMinListRowHeight, 44)
            .listStyle(.insetGrouped)
            .modifier(AccountHardScrollEdge())
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .contentMargins(.top, 8, for: .scrollContent)
            // Neutral rows; colour is reserved for state and destructive actions.
            .tint(.primary)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isDeletingAccount)
            .sensoryFeedback(.error, trigger: error)
            .task { await refreshNotificationAccess() }
            .onChange(of: error, initial: true) { _, message in
                if let announcement = errorAnnouncements.announcement(for: message) {
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                }
            }
            .environment(\.openURL, OpenURLAction { url in
                guard !hillclimbReadOnly else { return .discarded }
                openURL(url)
                return .handled
            })
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
                        Button { dismiss() } label: {
                            Text("Done")
                                // Medium sheets scale content; retain a 44pt on-screen target.
                                .frame(minWidth: 46, minHeight: 46)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                    guard !hillclimbReadOnly else { return }
                    Task {
                        error = nil
                        _ = errorAnnouncements.announcement(for: nil)
                        if !(await auth.signOut()) {
                            error = "Couldn’t disconnect notifications. You’re still signed in. Reconnect and try signing out again before giving this iPhone to someone else."
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("An internet connection is required to disconnect notifications before signing out. You can sign back in with Apple, Google, or email.")
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
        .presentationBackground(Color(.systemGroupedBackground))
        .modifier(AccountCaptureProbe())
    }

    private var hillclimbReadOnly: Bool {
#if DEBUG
        HillclimbDemo.isActive
#else
        false
#endif
    }

    private var accountEmail: String? {
        let email = auth.session?.user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let email, !email.isEmpty { return email }
        return nil
    }

    private var accountTitle: String {
        guard let accountEmail else { return "Signed In" }
        // Store-screenshot harness only: launched with this environment key so
        // captures never show the review account's address. Real users always
        // see their own email.
        if ProcessInfo.processInfo.environment["LMR_SCREENSHOT_MASK_EMAIL"] == "1" {
            return "you@example.com"
        }
        return accountEmail
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

    private var accountInitial: String {
        accountTitle.first.map { String($0).uppercased() } ?? "•"
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
                guard !hillclimbReadOnly else { return }
                Task {
                    await AppDelegate.requestPushIfNeeded()
                    await refreshNotificationAccess()
                }
            }
        case .blocked:
            Button {
                if !hillclimbReadOnly, let url = NotificationAccessPolicy.notificationSettingsURL() {
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
#if DEBUG
        if HillclimbDemo.isActive { notificationAccess = .ask; return }
#endif
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAccess = NotificationAccessPolicy.access(for: settings.authorizationStatus)
    }

    private func deleteAccount() async {
        guard !hillclimbReadOnly else { return }
        isDeletingAccount = true
        error = nil
        _ = errorAnnouncements.announcement(for: nil)
        do {
            try await AppleRevocation.deleteAccount(using: auth)
        } catch {
            self.error = error.localizedDescription
            isDeletingAccount = false
        }
    }
}

/// Neutral settings row: primary text, grey glyph, optional quiet
/// external-link arrow. Keeps the sheet from reading as a wall of links.
private struct AccountRow: View {
    let title: String
    let systemImage: String
    var external = false
    var destructive = false

    init(_ title: String, systemImage: String, external: Bool = false, destructive: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.external = external
        self.destructive = destructive
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(destructive ? Color.red : Color.secondary)
                .frame(width: 24)
                .accountMeasure("\(title).icon")
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(Color.primary)
                .accountMeasure("\(title).title")
            Spacer(minLength: 8)
            if external {
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

private struct AccountHardScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            content
        }
    }
}
