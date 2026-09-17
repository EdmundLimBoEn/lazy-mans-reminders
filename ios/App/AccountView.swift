import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOut = false
    @State private var showDeleteAccount = false
    @State private var isDeletingAccount = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }

                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(accountTitle)
                                .font(.headline)
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
                    Button("Delete Account…", role: .destructive) {
                        showDeleteAccount = true
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
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteAccount,
                titleVisibility: .visible
            ) {
                Button("Delete Permanently", role: .destructive) {
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
