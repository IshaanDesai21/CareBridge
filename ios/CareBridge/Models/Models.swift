import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let role: String
    let firstName: String?
    let lastName: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email, role
        case firstName = "first_name"
        case lastName = "last_name"
    }
    
    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

struct Patient: Codable, Identifiable {
    let id: Int
    let userId: Int
    let dateOfBirth: String?
    let phone: String?
    let emergencyContactName: String?
    let emergencyContactPhone: String?
    let wellnessScore: Int
    let firstName: String?
    let lastName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dateOfBirth = "date_of_birth"
        case phone
        case emergencyContactName = "emergency_contact_name"
        case emergencyContactPhone = "emergency_contact_phone"
        case wellnessScore = "wellness_score"
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct WellnessCheckin: Codable, Identifiable {
    let id: Int
    let patientId: Int
    let date: String
    let energy: Int?
    let fatigue: Int?
    let pain: Int?
    let mood: Int?
    let sleepQuality: Int?
    let breathing: Int?
    let mobility: Int?
    let balance: Int?
    let speechClarity: Int?
    let appetite: Int?
    let hydration: Int?
    let swallowingDifficulty: Int?
    let weight: Double?
    let notes: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case date, energy, fatigue, pain, mood
        case sleepQuality = "sleep_quality"
        case breathing, mobility, balance
        case speechClarity = "speech_clarity"
        case appetite, hydration
        case swallowingDifficulty = "swallowing_difficulty"
        case weight, notes
        case createdAt = "created_at"
    }
}

struct Medication: Codable, Identifiable {
    let id: Int
    let patientId: Int
    let name: String
    let dosage: String?
    let frequency: String?
    let instructions: String?
    let isActive: Int  // SQLite returns 0/1 integer, not bool

    var active: Bool { isActive != 0 }

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case name, dosage, frequency, instructions
        case isActive = "is_active"
    }
}

struct Appointment: Codable, Identifiable {
    let id: Int
    let patientId: Int
    let title: String
    let type: String?
    let providerName: String?
    let location: String?
    let appointmentDate: String
    let durationMinutes: Int?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case title, type
        case providerName = "provider_name"
        case location
        case appointmentDate = "appointment_date"
        case durationMinutes = "duration_minutes"
        case notes
    }
}

struct JournalEntry: Codable, Identifiable {
    let id: Int
    let patientId: Int
    let title: String?
    let content: String?
    let mood: String?
    let isShared: Bool
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case title, content, mood
        case isShared = "is_shared"
        case createdAt = "created_at"
    }
}

struct PatientAlert: Codable, Identifiable {
    let id: Int
    let patientName: String?
    let message: String
    let isUrgent: Int
    let isAcknowledged: Int
    let createdAt: String

    var urgent: Bool { isUrgent != 0 }
    var acknowledged: Bool { isAcknowledged != 0 }

    enum CodingKeys: String, CodingKey {
        case id
        case patientName = "patient_name"
        case message
        case isUrgent = "is_urgent"
        case isAcknowledged = "is_acknowledged"
        case createdAt = "created_at"
    }
}

struct CareNote: Codable, Identifiable {
    let id: Int
    let patientId: Int
    let caregiverId: Int?
    let noteType: String
    let content: String
    let firstName: String?
    let lastName: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case caregiverId = "caregiver_id"
        case noteType = "note_type"
        case content
        case firstName = "first_name"
        case lastName = "last_name"
        case createdAt = "created_at"
    }
}

// MARK: - Emergency Contact

struct EmergencyContact: Codable, Identifiable {
    var id: String { name + phone }
    let name: String
    let relation: String
    let phone: String
    let isPrimary: Bool?

    enum CodingKeys: String, CodingKey {
        case name, relation, phone
        case isPrimary = "isPrimary"
    }
}

// MARK: - Care Team Member

struct CareTeamMember: Codable, Identifiable {
    var id: String { name + role }
    let name: String
    let role: String
    let organization: String?
    let phone: String?
}

// MARK: - Physical Details (caregiver dashboard)

struct PhysicalDetails: Codable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let gender: String?
    let heightCm: Double?
    let weightKg: Double?
    let hearingNotes: String?
    let visionScore: String?
    let medicalHistory: String?
    let diagnoses: [String]?
    let allergies: [String]?
    let aiCompanionName: String?
    let emergencyContacts: [EmergencyContact]?
    let careTeam: [CareTeamMember]?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case gender
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case hearingNotes = "hearing_notes"
        case visionScore = "vision_score"
        case medicalHistory = "medical_history"
        case diagnoses, allergies
        case aiCompanionName = "ai_companion_name"
        case emergencyContacts = "emergency_contacts"
        case careTeam = "care_team"
    }

    var heightFormatted: String {
        guard let h = heightCm else { return "—" }
        let inches = h / 2.54
        let feet = Int(inches / 12)
        let inch = Int(inches.truncatingRemainder(dividingBy: 12))
        return String(format: "%.0f cm  (%d′%d″)", h, feet, inch)
    }

    var weightFormatted: String {
        guard let w = weightKg else { return "—" }
        let lbs = w * 2.205
        return String(format: "%.1f kg  (%.1f lbs)", w, lbs)
    }
}

// MARK: - In-App Notification

struct AppNotification: Codable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
    let type: String
    let isRead: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, body, type
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - AI Chat History

struct ChatHistoryMessage: Codable, Identifiable {
    let id: Int
    let role: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case createdAt = "created_at"
    }
}

// MARK: - Scanned Medication (OCR result)

struct ScannedMedication: Codable {
    let name: String?
    let dosage: String?
    let frequency: String?
    let instructions: String?
    let confidence: String
    let rxcui: Int?
    let canonicalName: String?

    var isValid: Bool { (rxcui ?? 0) > 0 }
}
