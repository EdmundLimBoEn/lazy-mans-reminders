import AuthenticationServices
import SwiftUI
import UIKit
import WidgetKit

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView("Loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading")
            } else if auth.session == nil {
                SignInView()
            } else {
                ReminderListView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task(id: auth.session?.accessToken) {
            await auth.syncLockScreenPrefs()
            if auth.session != nil {
                await AppDelegate.requestPushIfNeeded()
            }
            if let token = AppDelegate.latestDeviceToken {
                await auth.registerDevice(token: token)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRegisterPushToken)) { notification in
            guard let token = notification.object as? String else { return }
            Task { await auth.registerDevice(token: token) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRegisterPushToStartToken)) { notification in
            AppDelegate.latestPushToStartToken = notification.object as? String
            Task { await auth.registerLiveActivityTokens() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRegisterActivityPushToken)) { notification in
            AppDelegate.latestActivityPushToken = notification.object as? String
            Task { await auth.registerLiveActivityTokens() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, auth.session != nil else { return }
            Task {
                await AppDelegate.requestPushIfNeeded()
                if let token = AppDelegate.latestDeviceToken {
                    await auth.registerDevice(token: token)
                }
            }
        }
    }
}

private struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SignInWithAppleButton(.signIn) { request in
                        auth.configureAppleRequest(request)
                    } onCompletion: { result in
                        Task { await auth.handleAppleSignIn(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .disabled(auth.isLoading)
                    .accessibilityLabel("Sign in with Apple")

                    Button {
                        Task { await auth.signInWithGoogle() }
                    } label: {
                        Label("Continue with Google", systemImage: "g.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(auth.isLoading)
                    .accessibilityHint("Opens Google sign-in in a secure browser sheet")
                } header: {
                    Text("Sign in")
                } footer: {
                    Text("Use Apple, Google, or the same email you use on the web.")
                }

                Section("Email") {
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Email address")

                    Button {
                        Task {
                            await auth.sendMagicLink(
                                to: email.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }
                    } label: {
                        Text(auth.isLoading ? "Working…" : "Send sign-in link")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || auth.isLoading)

                    if let message = auth.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }

                Section {
                    Link("Privacy", destination: URL(string: "https://lmr.edmundlim.systems/privacy")!)
                    Link("Terms", destination: URL(string: "https://lmr.edmundlim.systems/terms")!)
                    Link("Support", destination: URL(string: "https://lmr.edmundlim.systems/support")!)
                }
            }
            .navigationTitle("Lazy Man's Reminders")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct ReminderListView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reminders: [Reminder] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var error: String?
    @State private var completingIDs: Set<UUID> = []
    @State private var showDeleteAccount = false
    @State private var isDeletingAccount = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && reminders.isEmpty {
                    ProgressView("Loading reminders")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading reminders")
                } else if reminders.isEmpty {
                    ContentUnavailableView(
                        "All clear",
                        systemImage: "checkmark.circle",
                        description: Text("Nothing on your board yet. Type below to add one.")
                    )
                } else {
                    List {
                        ForEach(reminders) { reminder in
                            ReminderRow(
                                reminder: reminder,
                                isCompleting: completingIDs.contains(reminder.id)
                            ) {
                                Task { await markDone(reminder) }
                            }
                        }

                        Section {
                            Text(ReminderBoardLimits.postItHint)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(ReminderBoardLimits.postItHint)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your board")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out") {
                        Task { await auth.signOut() }
                    }
                    .disabled(isDeletingAccount || isAdding)
                    .accessibilityHint("Signs you out on this device")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isDeletingAccount {
                        ProgressView()
                            .accessibilityLabel("Deleting account")
                    } else {
                        Button {
                            Task { await refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isAdding)
                        .accessibilityLabel("Refresh reminders")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Link("Privacy", destination: URL(string: "https://lmr.edmundlim.systems/privacy")!)
                        Link("Terms", destination: URL(string: "https://lmr.edmundlim.systems/terms")!)
                        Link("Support", destination: URL(string: "https://lmr.edmundlim.systems/support")!)
                        Link("Download my data", destination: URL(string: "https://lmr.edmundlim.systems/")!)
                        Divider()
                        Button("Delete Account…", role: .destructive) {
                            showDeleteAccount = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isDeletingAccount)
                    .accessibilityLabel("More options")
                }
            }
            .refreshable { await refresh() }
            .task { await refresh() }
            .alert("Couldn't update", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK", role: .cancel) { error = nil }
            } message: {
                Text(error ?? "")
            }
            .confirmationDialog(
                "Delete account",
                isPresented: $showDeleteAccount,
                titleVisibility: .visible
            ) {
                Button("Delete permanently", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your reminders, device registrations, lock-screen prefs, agent access, and sign-in. This can’t be undone.")
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if atCapacity {
                Text(ReminderBoardLimits.postItHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
                    .accessibilityAddTraits(.isStaticText)
            }

            HStack(alignment: .center, spacing: 8) {
                TextField(
                    atCapacity ? "Board full — combine lines instead" : "New reminder",
                    text: $draft,
                    axis: .vertical
                )
                .font(.body)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .focused($composerFocused)
                .disabled(atCapacity)
                .submitLabel(.send)
                .accessibilityLabel("New reminder")
                .accessibilityHint(
                    atCapacity
                        ? "Board is full. Complete a reminder or combine lines."
                        : "Add a reminder to your board and Lock Screen"
                )
                .onSubmit { Task { await addReminder() } }

                Button {
                    Task { await addReminder() }
                } label: {
                    Group {
                        if isAdding {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Adding reminder")
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.bold))
                                .foregroundStyle(canAdd ? Color.white : Color.secondary)
                        }
                    }
                    // Visual control stays compact; hit target meets HIG ≥44×44.
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(canAdd ? Color.accentColor : Color(.tertiarySystemFill))
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel("Add reminder")
                .accessibilityHint("Saves the text as a new reminder")
            }
            .padding(.leading, 14)
            .padding(.trailing, 5)
            .padding(.vertical, 5)
            .background {
                composerFieldBackground
            }
            .accessibilityElement(children: .contain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var composerFieldBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                }
        }
    }

    private var atCapacity: Bool {
        ReminderBoardLimits.isAtCapacity(reminders.count)
    }

    private var canAdd: Bool {
        !isAdding
            && !isDeletingAccount
            && !atCapacity
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func animateBoard(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.easeInOut(duration: 0.2), updates)
        }
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        do {
            try await auth.deleteAccount()
        } catch {
            self.error = error.localizedDescription
        }
        isDeletingAccount = false
    }

    private func refresh() async {
        isLoading = true
        do {
            reminders = try await ReminderStore.shared.refresh()
            WidgetCenter.shared.reloadAllTimelines()
            await ReminderLiveActivityController.sync(reminders: reminders)
        } catch {
            reminders = await ReminderStore.shared.cached()
            self.error = error.localizedDescription
            await ReminderLiveActivityController.sync(reminders: reminders)
        }
        isLoading = false
    }

    private func addReminder() async {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAdd, let userID = auth.session?.user.id else { return }
        if atCapacity {
            error = ReminderBoardLimits.postItHint
            return
        }
        isAdding = true
        draft = ""
        do {
            let updated = try await ReminderStore.shared.create(text: value, userID: userID)
            animateBoard { reminders = updated }
            WidgetCenter.shared.reloadAllTimelines()
            await ReminderLiveActivityController.sync(reminders: reminders)
            composerFocused = true
            UIAccessibility.post(
                notification: .announcement,
                argument: "Reminder added"
            )
        } catch {
            draft = value
            self.error = error.localizedDescription
        }
        isAdding = false
    }

    private func markDone(_ reminder: Reminder) async {
        guard !completingIDs.contains(reminder.id) else { return }
        completingIDs.insert(reminder.id)
        do {
            let updated = try await ReminderStore.shared.markDone(id: reminder.id)
            animateBoard { reminders = updated }
            WidgetCenter.shared.reloadAllTimelines()
            await ReminderLiveActivityController.sync(reminders: reminders)
            UIAccessibility.post(
                notification: .announcement,
                argument: "Completed \(reminder.text)"
            )
        } catch {
            completingIDs.remove(reminder.id)
            self.error = error.localizedDescription
        }
    }
}

private struct ReminderRow: View {
    let reminder: Reminder
    let isCompleting: Bool
    let onComplete: () -> Void

    var body: some View {
        Button(action: onComplete) {
            Label {
                Text(reminder.text)
                    .foregroundStyle(isCompleting ? .secondary : .primary)
                    .strikethrough(isCompleting)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleting ? Color.accentColor : .secondary)
                    .imageScale(.large)
                    .frame(minWidth: 44, minHeight: 44, alignment: .center)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(isCompleting)
        .opacity(isCompleting ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reminder.text)
        .accessibilityValue(isCompleting ? "Completing" : "Active")
        .accessibilityHint("Double tap to mark complete")
        .accessibilityAddTraits(.isButton)
    }
}
