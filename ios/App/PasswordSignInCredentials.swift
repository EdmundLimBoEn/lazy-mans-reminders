import Foundation

struct PasswordSignInCredentials {
    let email: String
    let password: String

    init?(email: String, password: String) {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SignInEmail.isPlausible(address), !password.isEmpty else { return nil }
        self.email = address
        // Sign-in must preserve existing passwords, including spaces and older password lengths.
        self.password = password
    }
}
