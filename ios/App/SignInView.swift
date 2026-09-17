import AuthenticationServices
import SwiftUI
import UIKit

struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var signInButtonHeight: CGFloat = 44
    @State private var email = ""
    @State private var pending: PendingSignIn?
    @State private var inboxPulse = 0
    @State private var errorPulse = 0
    @FocusState private var emailFocused: Bool

    private enum PendingSignIn {
        case apple, google, magicLink
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lazy Man's Reminders")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Your board on this iPhone, the web, and the Lock Screen.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    providerCard
                    emailCard
                    if case .error(let message) = auth.notice {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .symbolRenderingMode(.hierarchical)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { emailFocused = false }
                }
            }
        }
        .sensoryFeedback(.success, trigger: inboxPulse)
        .sensoryFeedback(.error, trigger: errorPulse)
        .onChange(of: email) { _, _ in
            if case .error = auth.notice {
                auth.clearNotice()
            }
        }
        .onChange(of: auth.notice) { _, notice in
            if case .checkInbox = notice {
                pending = nil
                emailFocused = false
                inboxPulse += 1
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Check your inbox for the sign-in link"
                )
            } else if case .error = notice {
                pending = nil
                errorPulse += 1
            }
        }
    }

    private var busy: Bool {
        pending != nil || auth.isAuthenticating
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emailIsPlausible: Bool {
        SignInEmail.isPlausible(normalizedEmail)
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
            .signInWithAppleFill(SignInAppleFill.fill(for: colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: max(44, signInButtonHeight))
            .disabled(busy)

            Button {
                pending = .google
                Task {
                    await auth.signInWithGoogle()
                    pending = nil
                }
            } label: {
                signInButtonLabel(
                    title: "Sign in with Google",
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
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityAddTraits(.updatesFrequently)
                Text("We sent a sign-in link to \(sentTo).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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
                    .accessibilityAddTraits(.isHeader)
                Text("Use the same address as the web board.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                emailField
                if !normalizedEmail.isEmpty && !emailIsPlausible {
                    Text("Enter a valid email address.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.updatesFrequently)
                }
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
                .disabled(!emailIsPlausible || busy)
            }
        }
    }

    private var emailField: some View {
        HStack(spacing: 0) {
            TextField("you@example.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .focused($emailFocused)
                .submitLabel(.send)
                .accessibilityLabel("Email address")
                .onSubmit { Task { await sendMagicLink() } }
                .disabled(busy)

            if !email.isEmpty {
                Button {
                    email = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .accessibilityLabel("Clear text")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, email.isEmpty ? 12 : 0)
        .frame(minHeight: 44)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsProgress ? "\(title), in progress" : title)
    }

    private func sendMagicLink() async {
        let value = normalizedEmail
        guard SignInEmail.isPlausible(value), !busy else { return }
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

private extension View {
    @ViewBuilder
    func signInWithAppleFill(_ fill: SignInAppleFill) -> some View {
        switch fill {
        case .black:
            signInWithAppleButtonStyle(.black)
        case .whiteOutline:
            signInWithAppleButtonStyle(.whiteOutline)
        }
    }
}
