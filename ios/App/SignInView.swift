import AuthenticationServices
import SwiftUI
import UIKit

struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var signInButtonHeight: CGFloat = 44
    @State private var email = ""
    @State private var pending: PendingSignIn?
    @FocusState private var emailFocused: Bool

    private enum PendingSignIn {
        case apple, google, magicLink
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    providerCard
                    emailCard
                    if case .error(let message) = auth.notice {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .symbolRenderingMode(.hierarchical)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { emailFocused = false }
                }
            }
        }
        .onChange(of: email) { _, _ in
            if case .error = auth.notice {
                auth.clearNotice()
            }
        }
        .onChange(of: auth.notice) { _, notice in
            if case .checkInbox = notice {
                pending = nil
                emailFocused = false
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Check your inbox for the sign-in link"
                )
            } else if case .error = notice {
                pending = nil
            }
        }
    }

    private var busy: Bool {
        pending != nil || auth.isAuthenticating
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lazy Man's Reminders")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Sign In")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Your board on this iPhone, the web, and the Lock Screen.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var providerCard: some View {
        SignInCard {
            SignInWithAppleButton(.signIn) { request in
                pending = .apple
                auth.configureAppleRequest(request)
            } onCompletion: { result in
                Task {
                    await auth.handleAppleSignIn(result)
                    if auth.session == nil {
                        pending = nil
                    }
                }
            }
            .signInWithAppleButtonStyle(SignInAppleFill.fill(for: colorScheme).buttonStyle)
            .frame(maxWidth: .infinity)
            .frame(height: max(44, signInButtonHeight))
            .disabled(busy)
            .accessibilityLabel("Sign in with Apple")

            Button {
                pending = .google
                Task {
                    await auth.signInWithGoogle()
                    pending = nil
                }
            } label: {
                signInButtonLabel(
                    title: "Continue with Google",
                    showsProgress: pending == .google
                )
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(44, signInButtonHeight))
            .disabled(busy)
            .accessibilityHint("Opens Google sign-in in a secure browser sheet")
        }
    }

    @ViewBuilder
    private var emailCard: some View {
        if case .checkInbox(let sentTo) = auth.notice {
            SignInCard {
                Label("Check Your Inbox", systemImage: "envelope.badge")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
                Text("We sent a sign-in link to \(sentTo).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Use a Different Email") {
                    auth.clearNotice()
                    pending = nil
                    emailFocused = true
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        } else {
            SignInCard {
                Text("Email")
                    .font(.headline)
                Text("Use the same address as the web board.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .focused($emailFocused)
                    .submitLabel(.send)
                    .accessibilityLabel("Email address")
                    .onSubmit { Task { await sendMagicLink() } }
                    .disabled(busy)

                Button {
                    Task { await sendMagicLink() }
                } label: {
                    signInButtonLabel(
                        title: "Send Sign-In Link",
                        showsProgress: pending == .magicLink
                    )
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(normalizedEmail.isEmpty || busy)
            }
        }
    }

    private var legalFooter: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                Link("Privacy", destination: LMRWeb.privacy)
                    .frame(minHeight: 44)
                Text("·")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Link("Terms", destination: LMRWeb.terms)
                    .frame(minHeight: 44)
                Text("·")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Link("Support", destination: LMRWeb.support)
                    .frame(minHeight: 44)
            }
            VStack(spacing: 0) {
                Link("Privacy", destination: LMRWeb.privacy)
                    .frame(minHeight: 44)
                Link("Terms", destination: LMRWeb.terms)
                    .frame(minHeight: 44)
                Link("Support", destination: LMRWeb.support)
                    .frame(minHeight: 44)
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func signInButtonLabel(title: String, showsProgress: Bool) -> some View {
        ZStack {
            Text(title)
                .opacity(showsProgress ? 0 : 1)
            if showsProgress {
                ProgressView()
                    .accessibilityLabel(title)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 22)
    }

    private func sendMagicLink() async {
        let value = normalizedEmail
        guard !value.isEmpty, !busy else { return }
        pending = .magicLink
        await auth.sendMagicLink(to: value)
        pending = nil
    }
}

private struct SignInCard<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}
