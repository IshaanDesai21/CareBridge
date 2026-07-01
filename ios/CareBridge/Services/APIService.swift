
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
    
    static let defaultServerURL = "http://192.168.87.196:3000"
    static let serverURLKey = "carebridge_server_url"

    private var baseURL: String {
        let host = UserDefaults.standard.string(forKey: APIService.serverURLKey) ?? APIService.defaultServerURL
        return host.hasSuffix("/") ? host + "api" : host + "/api"
    }
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
    
    func register(email: String, password: String, role: String, firstName: String, lastName: String, phone: String? = nil, joinCode: String? = nil) async throws -> (user: User, token: String) {
        struct RegisterRequest: Codable {
            let email, password, role, firstName, lastName: String
            let phone: String?
            let joinCode: String?
        }

        struct RegisterResponse: Codable {
            let user: User
            let token: String
        }

        let request = RegisterRequest(email: email, password: password, role: role, firstName: firstName, lastName: lastName, phone: phone, joinCode: joinCode)
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
    
    func createWellnessCheckin(patientId: Int, energy: Int, fatigue: Int, pain: Int, mood: Int, sleepQuality: Int, breathing: Int, mobility: Int, balance: Int, speechClarity: Int, appetite: Int, hydration: Int, swallowingDifficulty: Int, weight: Double? = nil, notes: String?, token: String) async throws -> WellnessCheckin {
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
            let weight: Double?
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
            weight: weight,
            notes: notes
        )

        let response: CheckinResponse = try await post(endpoint: "/wellness", body: request, token: token)
        return response.checkin
    }

    func updatePatientDetails(patientId: Int, gender: String? = nil, heightCm: Double? = nil, weightKg: Double? = nil, hearingNotes: String? = nil, visionScore: String? = nil, medicalHistory: String? = nil, diagnoses: [String]? = nil, allergies: [String]? = nil, aiCompanionName: String? = nil, aiCompanionGender: String? = nil, token: String) async throws {
        struct UpdateRequest: Codable {
            let gender: String?
            let heightCm: Double?
            let weightKg: Double?
            let hearingNotes: String?
            let visionScore: String?
            let medicalHistory: String?
            let diagnoses: [String]?
            let allergies: [String]?
            let aiCompanionName: String?
            let aiCompanionGender: String?
        }
        struct SuccessResponse: Codable { let success: Bool }
        let body = UpdateRequest(gender: gender, heightCm: heightCm, weightKg: weightKg, hearingNotes: hearingNotes, visionScore: visionScore, medicalHistory: medicalHistory, diagnoses: diagnoses, allergies: allergies, aiCompanionName: aiCompanionName, aiCompanionGender: aiCompanionGender)
        let _: SuccessResponse = try await patch(endpoint: "/patients/\(patientId)/details", body: body, token: token)
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

    func addMedication(patientId: Int, name: String, dosage: String, frequency: String, token: String) async throws -> Medication {
        struct MedRequest: Codable {
            let patientId: Int
            let name: String
            let dosage: String
            let frequency: String
        }
        struct MedResponse: Codable {
            let medication: Medication
        }
        let req = MedRequest(patientId: patientId, name: name, dosage: dosage, frequency: frequency)
        let response: MedResponse = try await post(endpoint: "/medications", body: req, token: token)
        return response.medication
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
    
    // MARK: - Alerts

    func sendAlert(message: String, isUrgent: Bool, token: String) async throws {
        struct AlertRequest: Codable {
            let message: String
            let isUrgent: Bool
        }
        struct AlertResponse: Codable {
            let alert: PatientAlert
        }
        let _: AlertResponse = try await post(endpoint: "/alerts", body: AlertRequest(message: message, isUrgent: isUrgent), token: token)
    }

    func getAlerts(token: String) async throws -> [PatientAlert] {
        struct AlertsResponse: Codable { let alerts: [PatientAlert] }
        let response: AlertsResponse = try await get(endpoint: "/alerts", token: token)
        return response.alerts
    }

    func acknowledgeAlert(id: Int, token: String) async throws {
        struct Empty: Codable {}
        struct SuccessResponse: Codable { let success: Bool }
        let _: SuccessResponse = try await put(endpoint: "/alerts/\(id)/acknowledge", body: Empty(), token: token)
    }

    // MARK: - Patients list (for caregiver)

    func getPatients(token: String) async throws -> [Patient] {
        struct PatientsResponse: Codable { let patients: [Patient] }
        let response: PatientsResponse = try await get(endpoint: "/patients", token: token)
        return response.patients
    }

    // MARK: - Family

    func getLinkedPatient(token: String) async throws -> Patient? {
        struct FamilyResponse: Codable {
            let linked: Bool
            let patient: Patient?
        }
        let response: FamilyResponse = try await get(endpoint: "/family/patient", token: token)
        return response.patient
    }

    func getCareNotes(patientId: Int, token: String) async throws -> [CareNote] {
        struct NotesResponse: Codable { let notes: [CareNote] }
        let response: NotesResponse = try await get(endpoint: "/care-notes/\(patientId)", token: token)
        return response.notes
    }

    // MARK: - Patient self-lookup

    func getMyPatient(token: String) async throws -> Int {
        struct MyPatientResponse: Codable { let patient: Patient }
        let response: MyPatientResponse = try await get(endpoint: "/patients/me", token: token)
        return response.patient.id
    }

    // MARK: - AI Chat

    func sendChatMessage(_ message: String, patientGender: String? = nil, history: [[String: String]] = [], token: String) async throws -> (reply: String, companionName: String) {
        struct ChatRequest: Codable {
            let message: String
            let patientGender: String?
            let history: [[String: String]]
        }
        struct ChatResponse: Codable { let message: String; let companionName: String?; let timestamp: String }
        let body = ChatRequest(message: message, patientGender: patientGender, history: history)
        let response: ChatResponse = try await post(endpoint: "/ai/chat", body: body, token: token)
        return (response.message, response.companionName ?? "Alex")
    }

    // MARK: - Patient Physical Details

    func getPatientDetails(patientId: Int, token: String) async throws -> PhysicalDetails {
        struct DetailsResponse: Codable { let details: PhysicalDetails }
        let response: DetailsResponse = try await get(endpoint: "/patients/\(patientId)/details", token: token)
        return response.details
    }

    func getPatientFamilyCode(patientId: Int, token: String) async throws -> String {
        struct CodeResponse: Codable { let code: String }
        let response: CodeResponse = try await get(endpoint: "/patients/\(patientId)/join-code", token: token)
        return response.code
    }

    // MARK: - Notifications

    func getNotifications(token: String) async throws -> [AppNotification] {
        struct NotifResponse: Codable { let notifications: [AppNotification]; let unreadCount: Int }
        let response: NotifResponse = try await get(endpoint: "/alerts/notifications", token: token)
        return response.notifications
    }

    func markNotificationRead(id: Int, token: String) async throws {
        struct Empty: Codable {}
        struct SuccessResponse: Codable { let success: Bool }
        let _: SuccessResponse = try await put(endpoint: "/alerts/notifications/\(id)/read", body: Empty(), token: token)
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
    
    private func patch<T: Codable, U: Codable>(endpoint: String, body: T, token: String? = nil) async throws -> U {
        guard let url = URL(string: baseURL + endpoint) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request)
    }

    private func put<T: Codable, U: Codable>(endpoint: String, body: T, token: String? = nil) async throws -> U {
        guard let url = URL(string: baseURL + endpoint) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
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
