import Foundation

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var token: String?

    private let apiService = APIService.shared

    init() {
        if let savedToken = UserDefaults.standard.string(forKey: "authToken") {
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
        UserDefaults.standard.set(response.token, forKey: "authToken")
    }

    func loginWithGoogle(idToken: String, role: String = "patient") async throws {
        let response = try await apiService.loginWithGoogle(idToken: idToken, role: role)
        self.token = response.token
        self.currentUser = response.user
        self.isAuthenticated = true
        UserDefaults.standard.set(response.token, forKey: "authToken")
    }

    func loginWithApple(identityToken: String, firstName: String? = nil, lastName: String? = nil, role: String = "patient") async throws {
        let response = try await apiService.loginWithApple(identityToken: identityToken, firstName: firstName, lastName: lastName, role: role)
        self.token = response.token
        self.currentUser = response.user
        self.isAuthenticated = true
        UserDefaults.standard.set(response.token, forKey: "authToken")
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
        UserDefaults.standard.set(response.token, forKey: "authToken")
    }

    func loginAsDemo(role: String) {
        APIService.isDemoMode = true
        APIService.demoUserRole = role
        let user = APIService.demoUser(for: role)
        self.token = "demo-token"
        self.currentUser = user
        self.isAuthenticated = true
        UserDefaults.standard.set("demo-token", forKey: "authToken")
        UserDefaults.standard.set(role, forKey: "demoUserRole")
    }

    func logout() {
        token = nil
        currentUser = nil
        isAuthenticated = false
        APIService.isDemoMode = false
        UserDefaults.standard.removeObject(forKey: "authToken")
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
