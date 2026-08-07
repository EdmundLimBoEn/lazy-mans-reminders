import AuthenticationServices
import SwiftUI
import WidgetKit

private let brandAccent = Color(red: 0.84, green: 0.32, blue: 0.24)

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView()
            } else if auth.session == nil {
                SignInView()
            } else {
                ReminderListView()
            }
        }
        .tint(brandAccent)
        .task(id: auth.session?.accessToken) {
            if let token = AppDelegate.latestDeviceToken {
                await auth.registerDevice(token: token)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRegisterPushToken)) { notification in
            guard let token = notification.object as? String else { return }
            Task { await auth.registerDevice(token: token) }
        }
    }
}

private struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var email = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                    .padding(.top, 12)

                Text("Lazy Man's\nReminders")
                    .font(.system(.title, design: .serif, weight: .bold))

                Text("Sign in with Apple, Google, or the same email you use on the web.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SignInWithAppleButton(.signIn) { request in
                    auth.configureAppleRequest(request)
                } onCompletion: { result in
                    Task { await auth.handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(auth.isLoading)
                .accessibilityLabel("Sign in with Apple")

                Button {
                    Task { await auth.signInWithGoogle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        Text("Continue with Google")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(auth.isLoading)

                HStack {
                    Rectangle().fill(Color(.separator)).frame(height: 1)
                    Text("or email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle().fill(Color(.separator)).frame(height: 1)
                }
                .padding(.vertical, 2)

                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await auth.sendMagicLink(to: email.trimmingCharacters(in: .whitespacesAndNewlines)) }
                } label: {
                    Text(auth.isLoading ? "Working…" : "Send sign-in link")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || auth.isLoading)

                if let message = auth.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 8) {
                    Link("Privacy", destination: URL(string: "https://lmr.edmundlim.systems/privacy")!)
                    Link("Terms", destination: URL(string: "https://lmr.edmundlim.systems/terms")!)
                    Link("Support", destination: URL(string: "https://lmr.edmundlim.systems/support")!)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }
}

private struct ReminderListView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var reminders: [Reminder] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var completingIDs: Set<UUID> = []
    @State private var showDeleteAccount = false
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && reminders.isEmpty {
                    ProgressView()
                } else if reminders.isEmpty {
                    ContentUnavailableView {
                        Label("All clear", systemImage: "checkmark.circle")
                    } description: {
                        Text("Nothing waiting on your lock screen. Add reminders from the web board.")
                            .font(.subheadline)
                    }
                } else {
                    List {
                        ForEach(reminders) { reminder in
                            ReminderRow(
                                reminder: reminder,
                                isCompleting: completingIDs.contains(reminder.id)
                            ) {
                                Task { await markDone(reminder) }
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Your board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign out") { Task { await auth.signOut() } }
                        .font(.subheadline)
                        .disabled(isDeletingAccount)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if isDeletingAccount {
                            ProgressView()
                        } else {
                            Button {
                                Task { await refresh() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("Refresh")

                            Menu {
                                Link("Privacy", destination: URL(string: "https://lmr.edmundlim.systems/privacy")!)
                                Link("Terms", destination: URL(string: "https://lmr.edmundlim.systems/terms")!)
                                Link("Support", destination: URL(string: "https://lmr.edmundlim.systems/support")!)
                                Divider()
                                Button("Delete account…", role: .destructive) {
                                    showDeleteAccount = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .accessibilityLabel("More")
                        }
                    }
                }
            }
            .refreshable { await refresh() }
            .task { await refresh() }
            .alert("Couldn't update", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
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
                Text("This permanently deletes your reminders, device registrations, and sign-in. This can’t be undone.")
            }
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

    private func markDone(_ reminder: Reminder) async {
        guard !completingIDs.contains(reminder.id) else { return }
        completingIDs.insert(reminder.id)
        do {
            let updated = try await ReminderStore.shared.markDone(id: reminder.id)
            withAnimation(.easeInOut(duration: 0.2)) {
                reminders = updated
            }
            WidgetCenter.shared.reloadAllTimelines()
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
        HStack(alignment: .center, spacing: 12) {
            Button(action: onComplete) {
                ZStack {
                    Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(isCompleting ? brandAccent : .secondary)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isCompleting)
            .accessibilityLabel("Mark \"\(reminder.text)\" complete")

            Text(reminder.text)
                .font(.body)
                .strikethrough(isCompleting)
                .foregroundStyle(isCompleting ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .opacity(isCompleting ? 0.55 : 1)
    }
}
