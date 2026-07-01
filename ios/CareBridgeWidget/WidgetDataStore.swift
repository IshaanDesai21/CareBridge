import Foundation
import WidgetKit

/// Call this from the main app whenever wellness data updates.
/// The widget extension reads from the same App Group container.
struct WidgetDataStore {
    static let suiteName = "group.com.carebridge.app"

    static func update(patientName: String, wellnessScore: Int, energy: Int? = nil, mood: Int? = nil) {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(patientName, forKey: "widget_patient_name")
        defaults?.set(wellnessScore, forKey: "widget_wellness_score")
        if let e = energy { defaults?.set(e, forKey: "widget_energy") }
        if let m = mood { defaults?.set(m, forKey: "widget_mood") }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        defaults?.set(formatter.string(from: .now), forKey: "widget_last_checkin")

        WidgetCenter.shared.reloadAllTimelines()
    }
}
