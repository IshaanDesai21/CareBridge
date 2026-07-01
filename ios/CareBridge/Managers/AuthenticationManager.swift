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
            Task {
                await loadCurrentUser()
            }
        }
    }

    func login(email: String, password: String) async throws {
        let response = try await apiService.login(email: email, password: password)
        self.token = response.token
        self.currentUser = response.user
        self.isAuthenticated = true
        UserDefaults.standard.set(response.token, forKey: "authToken")
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

    func logout() {
        token = nil
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "authToken")
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
