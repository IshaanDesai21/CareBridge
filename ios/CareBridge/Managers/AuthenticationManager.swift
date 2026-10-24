import Foundation
import Security

/// Stores the session token in the iOS Keychain (encrypted by the system and
/// tied to this device) rather than in UserDefaults, which is a plain file.
enum TokenStore {
    private static let service = "CareBridge"
    private static let account = "authToken"
    private static let installMarker = "carebridge_has_launched"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ token: String) {
        delete()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
            // Readable after the first unlock so live updates can reconnect in the
            // background; never synced to iCloud or restored to another device.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Keychain items outlive an app deletion, so on the first launch of a fresh
    /// install drop any token left behind; and move a token saved by older builds
    /// out of UserDefaults into the Keychain.
    static func prepareOnLaunch() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: installMarker) {
            delete()
            defaults.set(true, forKey: installMarker)
        }
        if let legacy = defaults.string(forKey: account) {
            save(legacy)
            defaults.removeObject(forKey: account)
        }
    }
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var token: String?

    private let apiService = APIService.shared

    init() {
        TokenStore.prepareOnLaunch()
        if let savedToken = TokenStore.load() {
            self.token = savedToken
            self.isAuthenticated = true
            if savedToken == "demo-token" {
                let role = UserDefaults.standard.string(forKey: "demoUserRole") ?? "patient"
                APIService.isDemoMode = true
                APIService.demoUserRole = role
                self.currentUser = APIService.demoUser(for: role)
            } else {
                Task {
                    await loadCurrentUser()
                }
            }
        }
        #if DEBUG
        // Scripted simulator walkthroughs: `-demoRole <patient|caregiver|family>`.
        if let role = UserDefaults.standard.string(forKey: "demoRole"),
           ["patient", "caregiver", "family"].contains(role) {
            loginAsDemo(role: role)
        }
        #endif
    }

    func login(email: String, password: String) async throws {
        let response = try await apiService.login(email: email, password: password)
        self.token = response.token
        self.currentUser = response.user
        self.isAuthenticated = true
        TokenStore.save(response.token)
    }

    func loginWithGoogle(idToken: String, role: String = "patient") async throws {
        let response = try await apiService.loginWithGoogle(idToken: idToken, role: role)
        self.token = response.token
        self.currentUser = response.user
        self.isAuthenticated = true
        TokenStore.save(response.token)
    }

    func loginWithApple(identityToken: String, firstName: String? = nil, lastName: String? = nil, role: String = "patient") async throws {
        let response = try await apiService.loginWithApple(identityToken: identityToken, firstName: firstName, lastName: lastName, role: role)
        self.token = response.token
        self.currentUser = response.user
        self.isAuthenticated = true
        TokenStore.save(response.token)
    }

    func deleteAccount() async throws {
        if let token = token, token != "demo-token" {
            try await apiService.deleteAccount(token: token)
        }
        logout()
    }

    func register(email: String, password: String, firstName: String, lastName: String, role: String = "patient", phone: String? = nil, joinCode: String? = nil) async throws {
        let response = try await apiService.register(
            email: email, password: password, role: role,
            firstName: firstName, lastName: lastName,
            phone: phone, joinCode: joinCode
        )
        self.token = response.token
        self.currentUser = response.user
        self.isAuthenticated = true
        TokenStore.save(response.token)
    }

    func loginAsDemo(role: String) {
        APIService.isDemoMode = true
        APIService.demoUserRole = role
        let user = APIService.demoUser(for: role)
        self.token = "demo-token"
        self.currentUser = user
        self.isAuthenticated = true
        TokenStore.save("demo-token")
        UserDefaults.standard.set(role, forKey: "demoUserRole")
    }

    func logout() {
        token = nil
        currentUser = nil
        isAuthenticated = false
        APIService.isDemoMode = false
        TokenStore.delete()
        UserDefaults.standard.removeObject(forKey: "demoUserRole")
    }

    private func loadCurrentUser() async {
        guard let token = token else { return }
        do {
            let user = try await apiService.getCurrentUser(token: token)
            self.currentUser = user
        } catch {
            self.logout()
        }
    }
}
