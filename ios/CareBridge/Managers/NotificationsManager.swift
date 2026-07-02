import Foundation
import UserNotifications

/// Wraps UNUserNotificationCenter to turn the toggles in NotificationsSettingsView
/// into real, scheduled local notifications, and to surface notifications pushed
/// live over the WebSocket connection (see LiveNotificationsManager) as banners.
final class NotificationsManager: NSObject, ObservableObject {
    static let shared = NotificationsManager()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    // MARK: - Scheduled reminders

    private static let checkinReminderId = "carebridge.checkinReminder"
    private static let medicationReminderId = "carebridge.medicationReminder"

    /// Schedules (or cancels) the daily check-in reminder based on current settings.
    func syncCheckinReminder(enabled: Bool, hour: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.checkinReminderId])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Daily Check-In"
        content.body = "How are you feeling today? Take a minute for your wellness check-in."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: Self.checkinReminderId, content: content, trigger: trigger)
        center.add(request)
    }

    /// Schedules (or cancels) medication reminders, one per active medication's
    /// frequency-implied time slots. Falls back to a single daily 9am reminder
    /// when medications don't specify a parseable schedule.
    func syncMedicationReminders(enabled: Bool, medications: [Medication]) {
        center.removePendingNotificationRequests(withIdentifiers: (0..<50).map { "\(Self.medicationReminderId).\($0)" })
        guard enabled, !medications.isEmpty else { return }

        for (index, med) in medications.enumerated() where med.active {
            let content = UNMutableNotificationContent()
            content.title = "Medication Reminder"
            content.body = "Time to take \(med.name)\(med.dosage.map { " (\($0))" } ?? "")."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = 9
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(
                identifier: "\(Self.medicationReminderId).\(index)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - Immediate delivery (used for live-pushed notifications)

    func postLocal(title: String, body: String, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request)
    }
}

extension NotificationsManager: UNUserNotificationCenterDelegate {
    // Show banners even while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
