
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
    
    func logVerification(medicationId: Int, status: String, pills: [[String: String]], token: String) async throws {
        if APIService.isDemoMode { return }
        struct VerifyRequest: Codable { let pills: [[String: String]] }
        struct VerifyResponse: Codable { let verification: [String: String] }
        let _: VerifyResponse = try await post(
            endpoint: "/verification/verify/\(medicationId)",
            body: VerifyRequest(pills: pills),
            token: token
        )
    }

    /// Look up a pill by imprint code using the NIH C3PI dataset (via RxImage API).
    func lookupPill(imprint: String, token: String) async throws -> Pill? {
        if APIService.isDemoMode { return nil }
        struct PillResponse: Codable { let pill: Pill }
        guard let encoded = imprint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let response: PillResponse = try await get(endpoint: "/medications/pill-lookup?imprint=\(encoded)", token: token)
        return response.pill
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
        if APIService.isDemoMode {
            // Family members only see their linked patient (mirrors GET /patients for family).
            return APIService.demoUserRole == "family" ? [APIService.demoPatient] : APIService.demoCaregiverPatients
        }
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
            return ScannedMedication(name: "Lisinopril", dosage: "10mg", frequency: "Once daily", instructions: "Take with food", confidence: "high", rxcui: 29046, canonicalName: "Lisinopril")
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

    // MARK: - Calendar

    /// Write routes answer with raw snake_case DB rows; callers re-fetch the
    /// day instead, so the body is decoded into this and discarded.
    private struct IgnoredResponse: Codable {}

    /// `month` is "YYYY-MM".
    func getCalendarMonth(patientId: Int, month: String, token: String) async throws -> CalendarMonth {
        if APIService.isDemoMode { return DemoCalendarStore.shared.month(patientId: patientId, month: month) }
        return try await get(endpoint: "/calendar/\(patientId)?month=\(month)", token: token)
    }

    /// `date` is "YYYY-MM-DD" (the patient's local date).
    func getCalendarDay(patientId: Int, date: String, token: String) async throws -> CalendarDay {
        if APIService.isDemoMode { return DemoCalendarStore.shared.day(patientId: patientId, date: date) }
        struct DayResponse: Codable { let day: CalendarDay }
        let response: DayResponse = try await get(endpoint: "/calendar/\(patientId)/day/\(date)", token: token)
        return response.day
    }

    /// Patient-authored note (patient role only).
    func addPatientNote(patientId: Int, content: String, localDate: String, token: String) async throws {
        if APIService.isDemoMode {
            DemoCalendarStore.shared.addNote(patientId: patientId, kind: "patient", content: content, localDate: localDate)
            return
        }
        struct Body: Codable { let patientId: Int; let content: String; let localDate: String }
        let _: IgnoredResponse = try await post(endpoint: "/patient-notes",
                                                body: Body(patientId: patientId, content: content, localDate: localDate),
                                                token: token)
    }

    /// Caregiver/organization-authored care note.
    func addCareNote(patientId: Int, content: String, localDate: String, token: String) async throws {
        if APIService.isDemoMode {
            DemoCalendarStore.shared.addNote(patientId: patientId, kind: "caregiver", content: content, localDate: localDate)
            return
        }
        struct Body: Codable { let patientId: Int; let content: String; let localDate: String }
        let _: IgnoredResponse = try await post(endpoint: "/care-notes",
                                                body: Body(patientId: patientId, content: content, localDate: localDate),
                                                token: token)
    }

    /// `kind` is a `DayNote.kind`: "patient" → /patient-notes, "caregiver" → /care-notes.
    func updateNote(kind: String, id: Int, content: String, token: String) async throws {
        if APIService.isDemoMode {
            DemoCalendarStore.shared.updateNote(kind: kind, id: id, content: content)
            return
        }
        struct Body: Codable { let content: String }
        let _: IgnoredResponse = try await put(endpoint: "/\(APIService.notesPath(kind))/\(id)",
                                               body: Body(content: content), token: token)
    }

    /// Only patient notes can be deleted; the backend has no DELETE for care notes.
    func deleteNote(kind: String, id: Int, token: String) async throws {
        guard kind != "caregiver" else { throw APIError.serverError("Caregiver notes cannot be deleted") }
        if APIService.isDemoMode {
            DemoCalendarStore.shared.deleteNote(kind: kind, id: id)
            return
        }
        let _: IgnoredResponse = try await delete(endpoint: "/\(APIService.notesPath(kind))/\(id)", token: token)
    }

    /// `mealType` is one of `Meal.types`.
    func addMeal(patientId: Int, mealType: String, description: String, localDate: String, token: String) async throws {
        if APIService.isDemoMode {
            DemoCalendarStore.shared.addMeal(patientId: patientId, mealType: mealType, description: description, localDate: localDate)
            return
        }
        struct Body: Codable { let patientId: Int; let mealType: String; let description: String; let localDate: String }
        let _: IgnoredResponse = try await post(endpoint: "/meals",
                                                body: Body(patientId: patientId, mealType: mealType,
                                                           description: description, localDate: localDate),
                                                token: token)
    }

    func updateMeal(id: Int, mealType: String, description: String, token: String) async throws {
        if APIService.isDemoMode {
            DemoCalendarStore.shared.updateMeal(id: id, mealType: mealType, description: description)
            return
        }
        struct Body: Codable { let mealType: String; let description: String }
        let _: IgnoredResponse = try await put(endpoint: "/meals/\(id)",
                                               body: Body(mealType: mealType, description: description), token: token)
    }

    func deleteMeal(id: Int, token: String) async throws {
        if APIService.isDemoMode {
            DemoCalendarStore.shared.deleteMeal(id: id)
            return
        }
        let _: IgnoredResponse = try await delete(endpoint: "/meals/\(id)", token: token)
    }

    private static func notesPath(_ kind: String) -> String {
        kind == "caregiver" ? "care-notes" : "patient-notes"
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

    /// Demo month summary (backed by `DemoCalendarStore`, so it reflects demo writes).
    static func demoCalendarMonth(for month: String, patientId: Int = 1) -> CalendarMonth {
        DemoCalendarStore.shared.month(patientId: patientId, month: month)
    }

    /// Demo day payload: today is full, three days ago carries an unresolved flag.
    static func demoCalendarDay(date: String, patientId: Int = 1) -> CalendarDay {
        DemoCalendarStore.shared.day(patientId: patientId, date: date)
    }

    static var demoAlerts: [PatientAlert] {
        [
            PatientAlert(id: 1, patientName: "Alice Johnson",
                         message: "Patient would like to speak with their caregiver",
                         isUrgent: 0, isAcknowledged: 0, createdAt: demoDateStr(daysOffset: -1))
        ]
    }
}

// MARK: - Demo calendar store

/// In-memory, offline calendar data for demo mode. Days are generated lazily and
/// deterministically, then cached so demo writes (meals/notes) persist until relaunch.
final class DemoCalendarStore {
    static let shared = DemoCalendarStore()

    private var days: [String: CalendarDay] = [:]   // key: "patientId|yyyy-MM-dd"
    private var nextId = 1000
    private let lock = NSLock()

    private struct DemoMed {
        let id: Int, name: String, strength: String, dosesPerDay: Int, asNeeded: Bool
    }
    private let meds = [
        DemoMed(id: 1, name: "Lisinopril", strength: "10 mg", dosesPerDay: 1, asNeeded: false),
        DemoMed(id: 2, name: "Metformin", strength: "500 mg", dosesPerDay: 2, asNeeded: false),
        DemoMed(id: 3, name: "Atorvastatin", strength: "20 mg", dosesPerDay: 1, asNeeded: false),
        DemoMed(id: 4, name: "Acetaminophen", strength: "500 mg", dosesPerDay: 4, asNeeded: true),
    ]

    private var gregorian: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.autoupdatingCurrent
        return c
    }

    // MARK: Reads

    /// Dots on ~70% of past days; the unresolved-flag day is three days ago.
    func month(patientId: Int, month: String) -> CalendarMonth {
        lock.lock(); defer { lock.unlock() }
        let parts = month.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2,
              let first = gregorian.date(from: DateComponents(year: parts[0], month: parts[1], day: 1)),
              let range = gregorian.range(of: .day, in: .month, for: first) else {
            return CalendarMonth(month: month, days: [])
        }
        let summaries = range.map { d -> CalendarDaySummary in
            let date = month + "-" + String(format: "%02d", d)
            let day = cachedDay(patientId: patientId, date: date)
            return CalendarDaySummary(date: date,
                                      hasCheckin: day.checkin != nil,
                                      hasDoses: !day.doses.isEmpty,
                                      hasFlag: !day.flags.isEmpty,
                                      hasEntries: !day.meals.isEmpty || !day.notes.isEmpty)
        }
        return CalendarMonth(month: month, days: summaries)
    }

    func day(patientId: Int, date: String) -> CalendarDay {
        lock.lock(); defer { lock.unlock() }
        return cachedDay(patientId: patientId, date: date)
    }

    // MARK: Writes

    func addNote(patientId: Int, kind: String, content: String, localDate: String) {
        lock.lock(); defer { lock.unlock() }
        var day = cachedDay(patientId: patientId, date: localDate)
        let user = APIService.demoUser(for: APIService.demoUserRole)
        day.notes.append(DayNote(id: allocId(), kind: kind, content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                                 authorUserId: user.id, authorName: user.fullName,
                                 createdAt: CalendarTimestamp.string(from: Date())))
        store(day, patientId: patientId)
    }

    func updateNote(kind: String, id: Int, content: String) {
        lock.lock(); defer { lock.unlock() }
        mutateEach { day in
            if let i = day.notes.firstIndex(where: { $0.kind == kind && $0.id == id }) {
                day.notes[i].content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    func deleteNote(kind: String, id: Int) {
        lock.lock(); defer { lock.unlock() }
        mutateEach { day in day.notes.removeAll { $0.kind == kind && $0.id == id } }
    }

    func addMeal(patientId: Int, mealType: String, description: String, localDate: String) {
        lock.lock(); defer { lock.unlock() }
        var day = cachedDay(patientId: patientId, date: localDate)
        let user = APIService.demoUser(for: APIService.demoUserRole)
        day.meals.append(Meal(id: allocId(), mealType: mealType,
                              description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                              authorUserId: user.id, authorName: user.fullName,
                              createdAt: CalendarTimestamp.string(from: Date())))
        store(day, patientId: patientId)
    }

    func updateMeal(id: Int, mealType: String, description: String) {
        lock.lock(); defer { lock.unlock() }
        mutateEach { day in
            if let i = day.meals.firstIndex(where: { $0.id == id }) {
                day.meals[i].mealType = mealType
                day.meals[i].description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    func deleteMeal(id: Int) {
        lock.lock(); defer { lock.unlock() }
        mutateEach { day in day.meals.removeAll { $0.id == id } }
    }

    // MARK: Internals (call with lock held)

    private func key(_ patientId: Int, _ date: String) -> String { "\(patientId)|\(date)" }

    private func store(_ day: CalendarDay, patientId: Int) { days[key(patientId, day.date)] = day }

    private func mutateEach(_ body: (inout CalendarDay) -> Void) {
        for k in Array(days.keys) {
            if var day = days[k] { body(&day); days[k] = day }
        }
    }

    private func allocId() -> Int { nextId += 1; return nextId }

    private func cachedDay(patientId: Int, date: String) -> CalendarDay {
        if let day = days[key(patientId, date)] { return day }
        let day = generate(date: date)
        days[key(patientId, date)] = day
        return day
    }

    private func timestamp(_ date: String, _ hour: Int, _ minute: Int) -> String? {
        guard let midnight = Date.fromLocalDateString(date),
              let d = gregorian.date(bySettingHour: hour, minute: minute, second: 0, of: midnight) else { return nil }
        return CalendarTimestamp.string(from: d)
    }

    private func dose(_ medId: Int, _ date: String, _ h: Int, _ m: Int,
                      source: String = "photo", verified: Bool = true) -> DayDose {
        let med = meds.first { $0.id == medId } ?? meds[0]
        return DayDose(id: allocId(), medicationId: med.id, name: med.name, strength: med.strength,
                       pillCount: 1, source: source, strengthVerified: verified, givenAt: timestamp(date, h, m))
    }

    private func progress(for doses: [DayDose]) -> [MedicationProgress] {
        meds.sorted { $0.name < $1.name }.map { med in
            let given = doses.filter { $0.medicationId == med.id }.count
            return MedicationProgress(
                medicationId: med.id, name: med.name, strength: med.strength,
                given: given, dosesPerDay: med.dosesPerDay, asNeeded: med.asNeeded,
                label: med.asNeeded ? "\(given) doses given (max \(med.dosesPerDay))"
                                    : "\(given) of \(med.dosesPerDay) doses")
        }
    }

    private func checkin(_ date: String, mood: Int, energy: Int, pain: Int, sleep: Int, notes: String?) -> DayCheckin {
        DayCheckin(energy: energy, fatigue: 10 - energy, pain: pain, mood: mood, sleepQuality: sleep,
                   breathing: 9, mobility: 7, balance: 8, speechClarity: 9, appetite: 7, hydration: 6,
                   swallowingDifficulty: 1, notes: notes, createdAt: timestamp(date, 8, 0))
    }

    private func generate(date: String) -> CalendarDay {
        let empty = CalendarDay(date: date, checkin: nil, doses: [], progress: progress(for: []),
                                flags: [], meals: [], notes: [])
        let today = Date().localDateString
        guard date <= today,
              let dayDate = Date.fromLocalDateString(date),
              let todayDate = Date.fromLocalDateString(today) else { return empty }
        let offset = gregorian.dateComponents([.day], from: dayDate, to: todayDate).day ?? 0
        let alice = APIService.demoUser(for: "patient")
        let sarah = APIService.demoUser(for: "caregiver")

        switch offset {
        case 0:
            let doses = [
                dose(1, date, 8, 5),
                dose(2, date, 8, 10, source: "manual", verified: false),
                dose(4, date, 13, 30),
            ]
            return CalendarDay(
                date: date,
                checkin: checkin(date, mood: 8, energy: 7, pain: 2, sleep: 6,
                                 notes: "Slept a bit restless but feeling good this morning."),
                doses: doses, progress: progress(for: doses), flags: [],
                meals: [
                    Meal(id: allocId(), mealType: "breakfast", description: "Oatmeal with blueberries and tea",
                         authorUserId: alice.id, authorName: alice.fullName, createdAt: timestamp(date, 8, 30)),
                    Meal(id: allocId(), mealType: "lunch", description: "Turkey sandwich and vegetable soup",
                         authorUserId: sarah.id, authorName: sarah.fullName, createdAt: timestamp(date, 12, 45)),
                ],
                notes: [
                    DayNote(id: allocId(), kind: "patient",
                            content: "Felt a little dizzy after standing up quickly; it passed after a minute.",
                            authorUserId: alice.id, authorName: alice.fullName, createdAt: timestamp(date, 10, 15)),
                    DayNote(id: allocId(), kind: "caregiver",
                            content: "Walked 15 minutes in the garden. Steady on her feet; encouraged more water.",
                            authorUserId: sarah.id, authorName: sarah.fullName, createdAt: timestamp(date, 14, 0)),
                ])
        case 3:
            let doses = [dose(1, date, 8, 2), dose(2, date, 8, 6)]
            return CalendarDay(
                date: date,
                checkin: checkin(date, mood: 6, energy: 5, pain: 3, sleep: 5, notes: nil),
                doses: doses, progress: progress(for: doses),
                flags: [DayFlag(id: allocId(), createdAt: timestamp(date, 8, 4), source: "photo",
                                messages: ["Expected 1 pill but found 2.",
                                           "One pill did not match Metformin 500 mg."])],
                meals: [], notes: [])
        default:
            let parts = date.split(separator: "-").compactMap { Int($0) }
            let seed = parts.count == 3 ? (parts[0] * 372 + parts[1] * 31 + parts[2]) * 7919 % 100 : 0
            guard seed < 70 else { return empty }
            var doses = [dose(1, date, 8, 0), dose(2, date, 8, 5)]
            if seed % 2 == 0 { doses.append(dose(2, date, 19, 0)) }
            if seed % 3 == 0 { doses.append(dose(3, date, 21, 30)) }
            var day = CalendarDay(date: date, checkin: nil, doses: doses, progress: progress(for: doses),
                                  flags: [], meals: [], notes: [])
            if seed % 3 != 1 {
                day.checkin = checkin(date, mood: 5 + seed % 5, energy: 4 + seed % 6, pain: 1 + seed % 4,
                                      sleep: 5 + seed % 4, notes: nil)
            }
            if seed % 4 == 0 {
                day.meals.append(Meal(id: allocId(), mealType: "dinner", description: "Baked salmon with rice",
                                      authorUserId: alice.id, authorName: alice.fullName,
                                      createdAt: timestamp(date, 18, 30)))
            }
            if seed % 5 == 0 {
                day.notes.append(DayNote(id: allocId(), kind: "caregiver",
                                         content: "Routine visit. Vitals stable.",
                                         authorUserId: sarah.id, authorName: sarah.fullName,
                                         createdAt: timestamp(date, 15, 0)))
            }
            return day
        }
    }
}
