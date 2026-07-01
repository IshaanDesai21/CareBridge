
import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}

class APIService {
    static let shared = APIService()
    
    private let baseURL = "http://localhost:3000/api"
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
    
    private init() {}
    
    // MARK: - Authentication
    
    func login(email: String, password: String) async throws -> (user: User, token: String) {
        struct LoginRequest: Codable {
            let email: String
            let password: String
        }
        
        struct LoginResponse: Codable {
            let user: User
            let token: String
        }
        
        let request = LoginRequest(email: email, password: password)
        let response: LoginResponse = try await post(endpoint: "/auth/login", body: request)
        return (response.user, response.token)
    }
    
    func register(email: String, password: String, role: String, firstName: String, lastName: String) async throws -> (user: User, token: String) {
        struct RegisterRequest: Codable {
            let email: String
            let password: String
            let role: String
            let firstName: String
            let lastName: String
        }
        
        struct RegisterResponse: Codable {
            let user: User
            let token: String
        }
        
        let request = RegisterRequest(email: email, password: password, role: role, firstName: firstName, lastName: lastName)
        let response: RegisterResponse = try await post(endpoint: "/auth/register", body: request)
        return (response.user, response.token)
    }
    
    func getCurrentUser(token: String) async throws -> User {
        struct UserResponse: Codable {
            let user: User
        }
        
        let response: UserResponse = try await get(endpoint: "/auth/me", token: token)
        return response.user
    }
    
    // MARK: - Wellness
    
    func getTodayCheckin(patientId: Int, token: String) async throws -> WellnessCheckin? {
        struct CheckinResponse: Codable {
            let checkin: WellnessCheckin?
            let completed: Bool
        }
        
        let response: CheckinResponse = try await get(endpoint: "/wellness/\(patientId)/today", token: token)
        return response.checkin
    }
    
    func createWellnessCheckin(patientId: Int, energy: Int, fatigue: Int, pain: Int, mood: Int, sleepQuality: Int, breathing: Int, mobility: Int, balance: Int, speechClarity: Int, appetite: Int, hydration: Int, swallowingDifficulty: Int, notes: String?, token: String) async throws -> WellnessCheckin {
        struct CheckinRequest: Codable {
            let patientId: Int
            let energy: Int
            let fatigue: Int
            let pain: Int
            let mood: Int
            let sleepQuality: Int
            let breathing: Int
            let mobility: Int
            let balance: Int
            let speechClarity: Int
            let appetite: Int
            let hydration: Int
            let swallowingDifficulty: Int
            let notes: String?
        }
        
        struct CheckinResponse: Codable {
            let checkin: WellnessCheckin
            let wellnessScore: Int
        }
        
        let request = CheckinRequest(
            patientId: patientId,
            energy: energy,
            fatigue: fatigue,
            pain: pain,
            mood: mood,
            sleepQuality: sleepQuality,
            breathing: breathing,
            mobility: mobility,
            balance: balance,
            speechClarity: speechClarity,
            appetite: appetite,
            hydration: hydration,
            swallowingDifficulty: swallowingDifficulty,
            notes: notes
        )
        
        let response: CheckinResponse = try await post(endpoint: "/wellness", body: request, token: token)
        return response.checkin
    }
    
    func getWellnessHistory(patientId: Int, days: Int = 30, token: String) async throws -> [WellnessCheckin] {
        struct HistoryResponse: Codable {
            let checkins: [WellnessCheckin]
        }
        
        let response: HistoryResponse = try await get(endpoint: "/wellness/\(patientId)?days=\(days)", token: token)
        return response.checkins
    }
    
    // MARK: - Medications
    
    func getMedications(patientId: Int, token: String) async throws -> [Medication] {
        struct MedicationsResponse: Codable {
            let medications: [Medication]
        }
        
        let response: MedicationsResponse = try await get(endpoint: "/medications/\(patientId)", token: token)
        return response.medications
    }
    
    // MARK: - Appointments
    
    func getAppointments(patientId: Int, token: String) async throws -> [Appointment] {
        struct AppointmentsResponse: Codable {
            let appointments: [Appointment]
        }
        
        let response: AppointmentsResponse = try await get(endpoint: "/appointments/\(patientId)", token: token)
        return response.appointments
    }
    
    // MARK: - Journal
    
    func getJournalEntries(patientId: Int, token: String) async throws -> [JournalEntry] {
        struct JournalResponse: Codable {
            let entries: [JournalEntry]
        }
        
        let response: JournalResponse = try await get(endpoint: "/journal/\(patientId)", token: token)
        return response.entries
    }
    
    func createJournalEntry(patientId: Int, title: String?, content: String, mood: String?, token: String) async throws -> JournalEntry {
        struct JournalRequest: Codable {
            let patientId: Int
            let title: String?
            let content: String
            let mood: String?
        }
        
        struct JournalResponse: Codable {
            let entry: JournalEntry
        }
        
        let request = JournalRequest(patientId: patientId, title: title, content: content, mood: mood)
        let response: JournalResponse = try await post(endpoint: "/journal", body: request, token: token)
        return response.entry
    }
    
    // MARK: - Generic Request Methods
    
    private func get<T: Codable>(endpoint: String, token: String? = nil) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await performRequest(request)
    }
    
    private func post<T: Codable, U: Codable>(endpoint: String, body: T, token: String? = nil) async throws -> U {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await performRequest(request)
    }
    
    private func performRequest<T: Codable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let errorResponse = try? decoder.decode([String: String].self, from: data),
                   let errorMessage = errorResponse["error"] {
                    throw APIError.serverError(errorMessage)
                }
                throw APIError.invalidResponse
            }
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}
