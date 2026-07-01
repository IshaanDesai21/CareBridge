import Foundation

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var token: String?
    
    private let apiService = APIService.shared
    
    init() {
        // Check for saved token
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
        
        await MainActor.run {
            self.token = response.token
            self.currentUser = response.user
            self.isAuthenticated = true
            
            // Save token
            UserDefaults.standard.set(response.token, forKey: "authToken")
        }
    }
    
    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        let response = try await apiService.register(
            email: email,
            password: password,
            role: "patient",
            firstName: firstName,
            lastName: lastName
        )
        
        await MainActor.run {
            self.token = response.token
            self.currentUser = response.user
            self.isAuthenticated = true
            
            // Save token
            UserDefaults.standard.set(response.token, forKey: "authToken")
        }
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
            await MainActor.run {
                self.currentUser = user
            }
        } catch {
            await MainActor.run {
                self.logout()
            }
        }
    }
}
