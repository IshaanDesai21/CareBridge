
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
    static var isDemoMode = false
    static var demoUserRole = "patient"

    // Update this once the Render service is live — see render.yaml / DEPLOYMENT.md
    // for the exact hostname (e.g. https://api.carebridge.ftcblueprint.com).
    static let defaultServerURL = "https://api.carebridge.ftcblueprint.com"
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
        if APIService.isDemoMode {
            return (APIService.demoUser(for: APIService.demoUserRole), "demo-token")
        }
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
        if APIService.isDemoMode {
            return (APIService.demoUser(for: role), "demo-token")
        }
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
    
    func loginWithGoogle(idToken: String, role: String) async throws -> (user: User, token: String) {
        if APIService.isDemoMode {
            return (APIService.demoUser(for: role), "demo-token")
        }
        struct GoogleRequest: Codable {
            let idToken: String
            let role: String
        }
        struct GoogleResponse: Codable {
            let user: User
            let token: String
        }
        let request = GoogleRequest(idToken: idToken, role: role)
        let response: GoogleResponse = try await post(endpoint: "/auth/google", body: request)
        return (response.user, response.token)
    }

    func loginWithApple(identityToken: String, firstName: String? = nil, lastName: String? = nil, role: String = "patient") async throws -> (user: User, token: String) {
        if APIService.isDemoMode {
            return (APIService.demoUser(for: role), "demo-token")
        }
        struct AppleRequest: Codable {
            let identityToken: String
            let firstName: String?
            let lastName: String?
            let role: String
        }
        struct AppleResponse: Codable {
            let user: User
            let token: String
        }
        let request = AppleRequest(identityToken: identityToken, firstName: firstName, lastName: lastName, role: role)
        let response: AppleResponse = try await post(endpoint: "/auth/apple", body: request)
        return (response.user, response.token)
    }

    /// Permanently deletes the signed-in user's account and all their data
    /// (App Store Review Guideline 5.1.1(v) requires this to be available in-app).
    func deleteAccount(token: String) async throws {
        if APIService.isDemoMode { return }
        struct DeleteResponse: Codable { let success: Bool }
        let _: DeleteResponse = try await delete(endpoint: "/auth/account", token: token)
    }

    func getCurrentUser(token: String) async throws -> User {
        if APIService.isDemoMode {
            return APIService.demoUser(for: APIService.demoUserRole)
        }
        struct UserResponse: Codable {
            let user: User
        }
        let response: UserResponse = try await get(endpoint: "/auth/me", token: token)
        return response.user
    }
    
    // MARK: - Wellness
    
    func getTodayCheckin(patientId: Int, token: String) async throws -> WellnessCheckin? {
        if APIService.isDemoMode { return nil }
        struct CheckinResponse: Codable {
            let checkin: WellnessCheckin?
            let completed: Bool
        }
        let response: CheckinResponse = try await get(endpoint: "/wellness/\(patientId)/today", token: token)
        return response.checkin
    }
    
    func createWellnessCheckin(patientId: Int, energy: Int, fatigue: Int, pain: Int, mood: Int, sleepQuality: Int, breathing: Int, mobility: Int, balance: Int, speechClarity: Int, appetite: Int, hydration: Int, swallowingDifficulty: Int, weight: Double? = nil, notes: String?, token: String) async throws -> WellnessCheckin {
        if APIService.isDemoMode {
            let now = APIService.demoDateStr(daysOffset: 0)
            return WellnessCheckin(id: 100, patientId: patientId, date: now,
                                   energy: energy, fatigue: fatigue, pain: pain, mood: mood,
                                   sleepQuality: sleepQuality, breathing: breathing, mobility: mobility,
                                   balance: balance, speechClarity: speechClarity, appetite: appetite,
                                   hydration: hydration, swallowingDifficulty: swallowingDifficulty,
                                   weight: weight, notes: notes, createdAt: now)
        }
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
        if APIService.isDemoMode { return }
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
        if APIService.isDemoMode { return APIService.demoWellnessHistory }
        struct HistoryResponse: Codable {
            let checkins: [WellnessCheckin]
        }
        let response: HistoryResponse = try await get(endpoint: "/wellness/\(patientId)?days=\(days)", token: token)
        return response.checkins
    }
    
    // MARK: - Medications
    
    func getMedications(patientId: Int, token: String) async throws -> [Medication] {
        if APIService.isDemoMode { return APIService.demoMedications }
        struct MedicationsResponse: Codable {
            let medications: [Medication]
        }
        let response: MedicationsResponse = try await get(endpoint: "/medications/\(patientId)", token: token)
        return response.medications
    }

    func addMedication(patientId: Int, name: String, dosage: String, frequency: String, instructions: String? = nil, token: String) async throws -> Medication {
        if APIService.isDemoMode {
            return Medication(id: Int.random(in: 100...999), patientId: patientId,
                              name: name, dosage: dosage, frequency: frequency,
                              instructions: instructions, isActive: 1)
        }
        struct MedRequest: Codable {
            let patientId: Int
            let name: String
            let dosage: String
            let frequency: String
            let instructions: String?
        }
        struct MedResponse: Codable {
            let medication: Medication
        }
        let req = MedRequest(patientId: patientId, name: name, dosage: dosage, frequency: frequency, instructions: instructions)
        let response: MedResponse = try await post(endpoint: "/medications", body: req, token: token)
        return response.medication
    }
    
    // MARK: - Appointments
    
    func getAppointments(patientId: Int, token: String) async throws -> [Appointment] {
        if APIService.isDemoMode { return APIService.demoAppointments }
        struct AppointmentsResponse: Codable {
            let appointments: [Appointment]
        }
        let response: AppointmentsResponse = try await get(endpoint: "/appointments/\(patientId)", token: token)
        return response.appointments
    }
    
    // MARK: - Journal
    
    func getJournalEntries(patientId: Int, token: String) async throws -> [JournalEntry] {
        if APIService.isDemoMode { return APIService.demoJournalEntries }
        struct JournalResponse: Codable {
            let entries: [JournalEntry]
        }
        let response: JournalResponse = try await get(endpoint: "/journal/\(patientId)", token: token)
        return response.entries
    }
    
    func createJournalEntry(patientId: Int, title: String?, content: String, mood: String?, token: String) async throws -> JournalEntry {
        if APIService.isDemoMode {
            let now = APIService.demoDateStr(daysOffset: 0)
            return JournalEntry(id: Int.random(in: 100...999), patientId: patientId,
                                title: title, content: content, mood: mood,
                                isShared: false, createdAt: now)
        }
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
        if APIService.isDemoMode { return }
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
        if APIService.isDemoMode { return APIService.demoAlerts }
        struct AlertsResponse: Codable { let alerts: [PatientAlert] }
        let response: AlertsResponse = try await get(endpoint: "/alerts", token: token)
        return response.alerts
    }

    func acknowledgeAlert(id: Int, token: String) async throws {
        if APIService.isDemoMode { return }
        struct Empty: Codable {}
        struct SuccessResponse: Codable { let success: Bool }
        let _: SuccessResponse = try await put(endpoint: "/alerts/\(id)/acknowledge", body: Empty(), token: token)
    }

    // MARK: - Patients list (for caregiver)

    func getPatients(token: String) async throws -> [Patient] {
        if APIService.isDemoMode { return APIService.demoCaregiverPatients }
        struct PatientsResponse: Codable { let patients: [Patient] }
        let response: PatientsResponse = try await get(endpoint: "/patients", token: token)
        return response.patients
    }

    // MARK: - Family

    func getLinkedPatient(token: String) async throws -> Patient? {
        if APIService.isDemoMode { return APIService.demoPatient }
        struct FamilyResponse: Codable {
            let linked: Bool
            let patient: Patient?
        }
        let response: FamilyResponse = try await get(endpoint: "/family/patient", token: token)
        return response.patient
    }

    func getCareNotes(patientId: Int, token: String) async throws -> [CareNote] {
        if APIService.isDemoMode { return APIService.demoCareNotes }
        struct NotesResponse: Codable { let notes: [CareNote] }
        let response: NotesResponse = try await get(endpoint: "/care-notes/\(patientId)", token: token)
        return response.notes
    }

    // MARK: - Patient self-lookup

    func getMyPatient(token: String) async throws -> Int {
        if APIService.isDemoMode { return 1 }
        struct MyPatientResponse: Codable { let patient: Patient }
        let response: MyPatientResponse = try await get(endpoint: "/patients/me", token: token)
        return response.patient.id
    }

    // MARK: - AI Chat

    func sendChatMessage(_ message: String, patientGender: String? = nil, history: [[String: String]] = [], token: String) async throws -> (reply: String, companionName: String) {
        if APIService.isDemoMode {
            try await Task.sleep(nanoseconds: 900_000_000)
            let replies = [
                "That's wonderful to hear! How have you been sleeping lately?",
                "I'm always here for you. Remember, small steps every day make a big difference.",
                "It sounds like you're making great progress. Your care team will be so pleased to hear that!",
                "Thank you for sharing that with me. Would you like to talk more about how you're feeling?",
                "You're doing amazingly well. Is there anything specific on your mind today?",
                "That sounds like it was a really good experience. Tell me more!",
            ]
            return (replies.randomElement()!, "Alex")
        }
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

    /// Restores the companion conversation the server remembers for this user,
    /// so reopening the chat continues where it left off instead of starting over.
    func getChatHistory(token: String) async throws -> [ChatHistoryMessage] {
        if APIService.isDemoMode { return [] }
        struct HistoryResponse: Codable { let messages: [ChatHistoryMessage] }
        let response: HistoryResponse = try await get(endpoint: "/ai/chat/history", token: token)
        return response.messages
    }

    // MARK: - Medication scanning

    func parseMedicationLabel(text: String, token: String) async throws -> ScannedMedication {
        if APIService.isDemoMode {
            try await Task.sleep(nanoseconds: 700_000_000)
            return ScannedMedication(name: "Lisinopril", dosage: "10mg", frequency: "Once daily", instructions: "Take with food", confidence: "high")
        }
        struct ParseRequest: Codable { let text: String }
        struct ParseResponse: Codable { let medication: ScannedMedication }
        let response: ParseResponse = try await post(endpoint: "/ai/parse-medication", body: ParseRequest(text: text), token: token)
        return response.medication
    }

    // MARK: - Patient Physical Details

    func getPatientDetails(patientId: Int, token: String) async throws -> PhysicalDetails {
        if APIService.isDemoMode { return APIService.demoPhysicalDetails }
        struct DetailsResponse: Codable { let details: PhysicalDetails }
        let response: DetailsResponse = try await get(endpoint: "/patients/\(patientId)/details", token: token)
        return response.details
    }

    func getPatientFamilyCode(patientId: Int, token: String) async throws -> String {
        if APIService.isDemoMode { return "DEMO-1234" }
        struct CodeResponse: Codable { let code: String }
        let response: CodeResponse = try await get(endpoint: "/patients/\(patientId)/join-code", token: token)
        return response.code
    }

    // MARK: - Notifications

    func getNotifications(token: String) async throws -> [AppNotification] {
        if APIService.isDemoMode { return [] }
        struct NotifResponse: Codable { let notifications: [AppNotification]; let unreadCount: Int }
        let response: NotifResponse = try await get(endpoint: "/alerts/notifications", token: token)
        return response.notifications
    }

    func markNotificationRead(id: Int, token: String) async throws {
        if APIService.isDemoMode { return }
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
    
    private func delete<T: Codable>(endpoint: String, token: String? = nil) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
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

// MARK: - Demo Data

extension APIService {
    static func demoDateStr(daysOffset: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: daysOffset, to: Date()) ?? Date()
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    static func demoUser(for role: String) -> User {
        switch role {
        case "caregiver":
            return User(id: 2, email: "caregiver@demo.com", role: "caregiver",
                        firstName: "Sarah", lastName: "Chen")
        case "family":
            return User(id: 3, email: "family@demo.com", role: "family",
                        firstName: "Michael", lastName: "Johnson")
        default:
            return User(id: 1, email: "patient@demo.com", role: "patient",
                        firstName: "Alice", lastName: "Johnson")
        }
    }

    static var demoPatient: Patient {
        Patient(id: 1, userId: 1, dateOfBirth: "1952-06-15", phone: "555-234-5678",
                emergencyContactName: "Michael Johnson", emergencyContactPhone: "555-345-6789",
                wellnessScore: 74, firstName: "Alice", lastName: "Johnson")
    }

    static var demoCaregiverPatients: [Patient] {
        [
            demoPatient,
            Patient(id: 2, userId: 4, dateOfBirth: "1948-03-22", phone: "555-111-2222",
                    emergencyContactName: "Jane Smith", emergencyContactPhone: "555-333-4444",
                    wellnessScore: 61, firstName: "Robert", lastName: "Davis"),
        ]
    }

    static var demoMedications: [Medication] {
        [
            Medication(id: 1, patientId: 1, name: "Lisinopril", dosage: "10 mg",
                       frequency: "Once daily", instructions: "Take with water in the morning", isActive: 1),
            Medication(id: 2, patientId: 1, name: "Metformin", dosage: "500 mg",
                       frequency: "Twice daily", instructions: "Take with meals", isActive: 1),
            Medication(id: 3, patientId: 1, name: "Atorvastatin", dosage: "20 mg",
                       frequency: "Once daily at bedtime", instructions: nil, isActive: 1),
        ]
    }

    static var demoAppointments: [Appointment] {
        [
            Appointment(id: 1, patientId: 1, title: "Primary Care Visit", type: "checkup",
                        providerName: "Dr. Emily Rodriguez", location: "Sunrise Medical Center",
                        appointmentDate: demoDateStr(daysOffset: 5), durationMinutes: 30,
                        notes: "Annual wellness checkup"),
            Appointment(id: 2, patientId: 1, title: "Physical Therapy", type: "therapy",
                        providerName: "Karen Mills, PT", location: "RehabCare Clinic",
                        appointmentDate: demoDateStr(daysOffset: 12), durationMinutes: 60,
                        notes: "Mobility and balance exercises"),
        ]
    }

    static var demoWellnessHistory: [WellnessCheckin] {
        // (energy, fatigue, pain, mood, sleep, breathing, mobility, balance, speech, appetite, hydration, swallowing)
        let metrics: [(Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int)] = [
            (7, 4, 3, 7, 8, 8, 7, 8, 7, 7, 8, 2),
            (6, 5, 4, 6, 7, 7, 7, 7, 6, 6, 7, 3),
            (8, 3, 2, 8, 9, 9, 8, 8, 8, 8, 9, 2),
            (5, 6, 5, 5, 6, 7, 6, 6, 6, 5, 7, 4),
            (7, 4, 3, 7, 8, 8, 7, 8, 7, 7, 8, 2),
            (6, 5, 4, 6, 7, 8, 7, 7, 7, 6, 7, 3),
            (8, 3, 2, 8, 9, 9, 8, 9, 8, 8, 9, 2),
        ]
        return metrics.enumerated().map { idx, m in
            let dateStr = demoDateStr(daysOffset: -idx)
            return WellnessCheckin(id: idx + 1, patientId: 1, date: dateStr,
                                   energy: m.0, fatigue: m.1, pain: m.2, mood: m.3,
                                   sleepQuality: m.4, breathing: m.5, mobility: m.6,
                                   balance: m.7, speechClarity: m.8, appetite: m.9,
                                   hydration: m.10, swallowingDifficulty: m.11,
                                   weight: 68.5 + Double(idx) * 0.1,
                                   notes: idx == 0 ? "Feeling good today!" : nil,
                                   createdAt: dateStr)
        }
    }

    static var demoJournalEntries: [JournalEntry] {
        [
            JournalEntry(id: 1, patientId: 1, title: "A Good Morning",
                         content: "Woke up feeling refreshed. Did some light stretching and had a nice breakfast. The physical therapy is really making a difference.",
                         mood: "happy", isShared: false, createdAt: demoDateStr(daysOffset: -1)),
            JournalEntry(id: 2, patientId: 1, title: "Physical Therapy Progress",
                         content: "My PT session went really well today. Karen says my mobility has improved significantly over the past month.",
                         mood: "hopeful", isShared: true, createdAt: demoDateStr(daysOffset: -3)),
            JournalEntry(id: 3, patientId: 1, title: "Family Visit",
                         content: "Michael came to visit. We watched a movie together and had dinner. It was so nice to spend time with family.",
                         mood: "grateful", isShared: false, createdAt: demoDateStr(daysOffset: -5)),
        ]
    }

    static var demoPhysicalDetails: PhysicalDetails {
        PhysicalDetails(id: 1, firstName: "Alice", lastName: "Johnson", gender: "female",
                        heightCm: 162.0, weightKg: 68.5,
                        hearingNotes: "Mild hearing loss in left ear, uses hearing aid",
                        visionScore: "20/40 corrected with glasses",
                        medicalHistory: "Type 2 diabetes diagnosed 2015, hypertension since 2010",
                        diagnoses: ["Type 2 Diabetes", "Hypertension", "Osteoarthritis (left knee)"],
                        allergies: ["Penicillin", "Sulfa drugs"],
                        aiCompanionName: "Alex",
                        emergencyContacts: [
                            EmergencyContact(name: "Michael Johnson", relation: "Son",
                                             phone: "555-345-6789", isPrimary: true),
                            EmergencyContact(name: "Sarah Chen", relation: "Caregiver",
                                             phone: "555-456-7890", isPrimary: false),
                        ],
                        careTeam: [
                            CareTeamMember(name: "Dr. Emily Rodriguez", role: "Primary Care Physician",
                                           organization: "Sunrise Medical Center", phone: "555-567-8901"),
                            CareTeamMember(name: "Karen Mills", role: "Physical Therapist",
                                           organization: "RehabCare Clinic", phone: "555-678-9012"),
                        ])
    }

    static var demoCareNotes: [CareNote] {
        [
            CareNote(id: 1, patientId: 1, caregiverId: 2, noteType: "observation",
                     content: "Patient is in good spirits today. Completed morning exercises without difficulty. Blood pressure 128/82.",
                     firstName: "Sarah", lastName: "Chen", createdAt: demoDateStr(daysOffset: -1)),
            CareNote(id: 2, patientId: 1, caregiverId: 2, noteType: "medication",
                     content: "All medications taken on schedule. No side effects noted. Patient asked about adjusting Metformin timing.",
                     firstName: "Sarah", lastName: "Chen", createdAt: demoDateStr(daysOffset: -2)),
        ]
    }

    static var demoAlerts: [PatientAlert] {
        [
            PatientAlert(id: 1, patientName: "Alice Johnson",
                         message: "Patient would like to speak with their caregiver",
                         isUrgent: 0, isAcknowledged: 0, createdAt: demoDateStr(daysOffset: -1))
        ]
    }
}
