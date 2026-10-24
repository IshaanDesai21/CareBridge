import Foundation

// Mirrors of the backend calendar payloads (backend/src/services/calendarAggregate.js).
// The server emits camelCase keys, so the synthesized CodingKeys match directly.

/// GET /api/calendar/:patientId?month=YYYY-MM
struct CalendarMonth: Codable {
    let month: String
    let days: [CalendarDaySummary]
}

struct CalendarDaySummary: Codable, Identifiable, Hashable {
    let date: String
    let hasCheckin: Bool
    let hasDoses: Bool
    let hasFlag: Bool
    let hasEntries: Bool

    var id: String { date }
}

/// GET /api/calendar/:patientId/day/:date → `{ day: CalendarDay }`
struct CalendarDay: Codable {
    let date: String
    var checkin: DayCheckin?
    var doses: [DayDose]
    var progress: [MedicationProgress]
    var flags: [DayFlag]
    var meals: [Meal]
    var notes: [DayNote]
}

struct DayCheckin: Codable {
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
    let notes: String?
    let createdAt: String?
}

struct DayDose: Codable, Identifiable {
    let id: Int
    let medicationId: Int
    let name: String?
    let strength: String?
    let pillCount: Int
    let source: String?
    let strengthVerified: Bool
    let givenAt: String?

    var isManual: Bool { source == "manual" }
}

struct MedicationProgress: Codable, Identifiable {
    let medicationId: Int
    let name: String
    let strength: String?
    let given: Int
    let dosesPerDay: Int
    let asNeeded: Bool
    let label: String

    var id: Int { medicationId }
}

struct DayFlag: Codable, Identifiable {
    let id: Int
    let createdAt: String?
    let source: String?
    let messages: [String]
}

struct Meal: Codable, Identifiable {
    let id: Int
    var mealType: String
    var description: String
    let authorUserId: Int?
    let authorName: String?
    let createdAt: String?

    static let types = ["breakfast", "lunch", "dinner", "snack"]
}

/// A note shown on a calendar day. `kind` is "patient" (patient_notes) or
/// "caregiver" (care_notes); ids are only unique within a kind.
struct DayNote: Codable, Identifiable {
    let id: Int
    let kind: String
    var content: String
    let authorUserId: Int?
    let authorName: String?
    let createdAt: String?

    var isCaregiverNote: Bool { kind == "caregiver" }
    /// Stable identity across both note tables.
    var uid: String { "\(kind)-\(id)" }
}

// MARK: - Timestamp helpers

enum CalendarTimestamp {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        return withFraction.date(from: string) ?? plain.date(from: string)
    }

    static func string(from date: Date) -> String {
        withFraction.string(from: date)
    }

    /// Short local time ("8:05 AM"), or nil when the timestamp is missing or unparseable.
    static func time(_ string: String?) -> String? {
        parse(string).map { timeFormatter.string(from: $0) }
    }
}
