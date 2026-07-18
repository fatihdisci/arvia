import Foundation
import UserNotifications
import OSLog

// MARK: - Notification Service
// Yerel bildirimleri yönetir: izin isteme, schedule, iptal.
// Bildirimler yalnızca kullanıcı tarafından girilen araç hatırlatıcıları içindir — reklam/spam yok.

final class NotificationService {
    static let shared = NotificationService()
    private static let logger = Logger(subsystem: "com.ruhsatim.app", category: "Notifications")

    private let center = UNUserNotificationCenter.current()
    private var isAuthorized = false

    static let reminderOffsets: [Int] = [30, 7, 1, 0]

    struct ReminderFireDate: Equatable {
        let daysBefore: Int
        let date: Date
    }

    private init() {}

    // MARK: - Authorization
    /// İzin istemeden önce kullanıcıya neden bildirim gönderdiğimizi açıklayan bir ön prompt.
    /// Asıl sistem prompt'u yalnızca kullanıcı kabul ederse gösterilir.
    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
    }

    func currentAuthorizationStatus() async -> AuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        @unknown default: return .notDetermined
        }
    }

    /// Sistem bildirim iznini ister. Kullanıcıya önce uygulama içi açıklama yapılmalıdır.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Scheduling
    /// Bir hatırlatıcı için çoklu offset'te bildirim planlar:
    /// 30 gün, 7 gün, 1 gün, aynı gün (due date'ten önce)
    func scheduleReminder(_ reminder: Reminder) async {
        // Önce eski bildirimleri temizle
        cancelReminder(reminder)

        guard RetentionNotificationService.shared.isImportantDatesEnabled else { return }
        guard let dueDate = reminder.dueDate,
              reminder.statusRaw != ReminderStatus.completed.rawValue,
              reminder.statusRaw != ReminderStatus.archived.rawValue
        else { return }

        let status = await currentAuthorizationStatus()
        guard status == .authorized else { return }

        for fireDate in Self.reminderFireDates(dueDate: dueDate) {
            let content = UNMutableNotificationContent()
            content.title = "Hatırlatıcı"
            content.body = "\(Self.reminderLabel(daysBefore: fireDate.daysBefore)): \(reminder.title) — \(dueDate.formatted(date: .abbreviated, time: .omitted))"
            content.sound = reminder.priority == .critical ? .defaultCritical : .default
            content.interruptionLevel = reminder.priority == .critical ? .timeSensitive : .active
            content.userInfo = [
                "deepLink": "reminder",
                "vehicleId": reminder.vehicleId.uuidString,
                "reminderId": reminder.id.uuidString,
            ]

            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate.date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let identifier = notificationIdentifier(for: reminder.id, daysBefore: fireDate.daysBefore)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                Self.logger.error("Notification schedule failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Hatırlatıcıya ait tüm bildirimleri iptal eder.
    func cancelReminder(_ reminder: Reminder) {
        cancelReminder(id: reminder.id)
    }

    /// Silinmiş SwiftData nesnesine tekrar erişmeden bildirimleri iptal eder.
    func cancelReminder(id: UUID) {
        let identifiers = Self.reminderNotificationIdentifiers(for: id)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func cancelReminders(_ reminders: [Reminder]) {
        cancelReminders(ids: reminders.map(\.id))
    }

    func cancelReminders(ids: [UUID]) {
        let identifiers = ids.flatMap(Self.reminderNotificationIdentifiers(for:))
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// Tüm bildirimleri temizler.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Badge
    func updateBadge(count: Int) {
        Task { @MainActor in
            UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    func clearBadge() {
        updateBadge(count: 0)
    }

    // MARK: - Helpers
    static func reminderNotificationIdentifiers(for reminderId: UUID) -> [String] {
        reminderOffsets.map { "reminder-\(reminderId.uuidString)-\($0)d" }
    }

    static func reminderFireDates(
        dueDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ReminderFireDate] {
        reminderOffsets.compactMap { daysBefore in
            guard let rawDate = calendar.date(byAdding: .day, value: -daysBefore, to: dueDate) else { return nil }
            let adjusted = RetentionNotificationService.adjustedForQuietHours(rawDate, calendar: calendar)
            guard adjusted > now else { return nil }
            return ReminderFireDate(daysBefore: daysBefore, date: adjusted)
        }
    }

    static func reminderLabel(daysBefore: Int) -> String {
        switch daysBefore {
        case 30: return "30 gün kaldı"
        case 7: return "7 gün kaldı"
        case 1: return "Yarın"
        default: return "Bugün"
        }
    }

    private func notificationIdentifier(for reminderId: UUID, daysBefore: Int) -> String {
        "reminder-\(reminderId.uuidString)-\(daysBefore)d"
    }
}
