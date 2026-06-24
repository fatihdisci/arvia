import Foundation
import UserNotifications

// MARK: - Notification Service
// Yerel bildirimleri yönetir: izin isteme, schedule, iptal.
// Bildirimler yalnızca araçla ilgili önemli tarihler içindir — reklam/spam yok.

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var isAuthorized = false

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

        guard let dueDate = reminder.dueDate,
              reminder.statusRaw != ReminderStatus.completed.rawValue,
              reminder.statusRaw != ReminderStatus.archived.rawValue
        else { return }

        let status = await currentAuthorizationStatus()
        guard status == .authorized else { return }

        let offsets: [(Int, String)] = [
            (30, "30 gün kaldı"),
            (7, "7 gün kaldı"),
            (1, "Yarın"),
            (0, "Bugün"),
        ]

        for (daysBefore, label) in offsets {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: dueDate),
                  triggerDate > Date()
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = "\(label): \(reminder.title) — \(dueDate.formatted(date: .abbreviated, time: .omitted))"
            content.sound = reminder.priority == .critical ? .defaultCritical : .default
            content.badge = 1
            content.interruptionLevel = reminder.priority == .critical ? .timeSensitive : .active

            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let identifier = notificationIdentifier(for: reminder.id, daysBefore: daysBefore)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                print("NotificationService: schedule error for \(identifier): \(error)")
            }
        }
    }

    /// Hatırlatıcıya ait tüm bildirimleri iptal eder.
    func cancelReminder(_ reminder: Reminder) {
        var identifiers: [String] = []
        for daysBefore in [30, 7, 1, 0] {
            identifiers.append(notificationIdentifier(for: reminder.id, daysBefore: daysBefore))
        }
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

    // MARK: - Helpers
    private func notificationIdentifier(for reminderId: UUID, daysBefore: Int) -> String {
        "reminder-\(reminderId.uuidString)-\(daysBefore)d"
    }
}
