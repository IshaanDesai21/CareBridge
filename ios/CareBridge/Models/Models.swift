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
    let isActive: Bool
    
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
