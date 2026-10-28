import AuthenticationServices
import Foundation
import Observation

/// Tracks whether the user signed in with Apple or chose to use the app without an account.
/// Tasks themselves sync through the device's iCloud account either way.
@Observable
@MainActor
final class AuthManager {
    enum Mode: String {
        case signedOut, apple, guest
    }

    private(set) var mode: Mode
    private(set) var displayName: String?
    private(set) var email: String?
    var lastError: String?

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var revokeObserver: NSObjectProtocol?

    private enum Key {
        static let mode = "auth.mode"
        static let name = "auth.name"
        static let email = "auth.email"
        static let appleUserID = "appleUserID"
    }

    init() {
        mode = Mode(rawValue: UserDefaults.standard.string(forKey: Key.mode) ?? "") ?? .signedOut
        displayName = UserDefaults.standard.string(forKey: Key.name)
        email = UserDefaults.standard.string(forKey: Key.email)
        revokeObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.signOut() }
        }
    }

    var isSignedIn: Bool { mode != .signedOut }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            Keychain.set(credential.user, for: Key.appleUserID)
            // Apple only sends the name and email the first time someone signs in.
            if let name = credential.fullName {
                let formatted = PersonNameComponentsFormatter().string(from: name)
                if !formatted.isEmpty { displayName = formatted }
            }
            if let email = credential.email { self.email = email }
            lastError = nil
            setMode(.apple)
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled { return }
            lastError = error.localizedDescription
        }
    }

    func continueWithoutAccount() {
        lastError = nil
        setMode(.guest)
    }

    func signOut() {
        Keychain.delete(Key.appleUserID)
        displayName = nil
        email = nil
        setMode(.signedOut)
    }

    /// Signs out if the Apple ID stopped authorizing this app (for example, removed in Settings).
    func refreshCredentialState() async {
        guard mode == .apple, let userID = Keychain.get(Key.appleUserID) else { return }
        guard let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID) else { return }
        if state == .revoked || state == .notFound {
            signOut()
        }
    }

    private func setMode(_ newMode: Mode) {
        mode = newMode
        defaults.set(newMode.rawValue, forKey: Key.mode)
        defaults.set(displayName, forKey: Key.name)
        defaults.set(email, forKey: Key.email)
    }
}

/// Minimal generic-password Keychain wrapper.
enum Keychain {
    private static let service = "com.wangminghai.todo"

    static func set(_ value: String, for account: String) {
        delete(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
