import SwiftUI
import WidgetKit

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
        .tint(Color(red: 0.84, green: 0.32, blue: 0.24))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image(systemName: "rectangle.stack")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            Text("Lazy Man's\nReminders")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
            Text("Sign in with the same email you use on the web. No password needed.")
                .foregroundStyle(.secondary)
            TextField("you@example.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            Button {
                Task { await auth.sendMagicLink(to: email.trimmingCharacters(in: .whitespacesAndNewlines)) }
            } label: {
                Text(auth.isLoading ? "Sending…" : "Send sign-in link")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || auth.isLoading)
            if let message = auth.message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(28)
        .background(Color(.systemGroupedBackground))
    }
}

private struct ReminderListView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var reminders: [Reminder] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && reminders.isEmpty {
                    ProgressView()
                } else if reminders.isEmpty {
                    ContentUnavailableView(
                        "Nothing to remember",
                        systemImage: "checkmark.circle",
                        description: Text("Add reminders from your web board.")
                    )
                } else {
                    List(reminders) { reminder in
                        Label(reminder.text, systemImage: "circle")
                    }
                }
            }
            .navigationTitle("Your board")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign out") { Task { await auth.signOut() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await refresh() }
            .task { await refresh() }
            .alert("Couldn't refresh", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
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
}
