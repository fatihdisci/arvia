import Foundation
import UserNotifications

// MARK: - Retention Notification Service
// Kullanıcıyı uygulamaya geri döndürmek için akıllı bildirim sistemi.
// Tüm bildirimler kullanıcı tarafından Settings'ten kapatılabilir.
// Anti-spam: cooldown, sessiz saatler, aynı gün dedup, stable identifier.

final class RetentionNotificationService {
    static let shared = RetentionNotificationService()

    private let center = UNUserNotificationCenter.current()
    fileprivate let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Preferences Keys
    private enum PrefKey: String {
        case importantDates = "notif_pref_important_dates"
        case kmUpdate = "notif_pref_km_update"
        case monthlySummary = "notif_pref_monthly_summary"
        case documentCompleteness = "notif_pref_doc_complete"
        case seasonal = "notif_pref_seasonal"
        case saleFile = "notif_pref_sale_file"
        case kmUpdateFrequency = "notif_pref_km_freq"
    }

    // MARK: - Preference Accessors
    var isImportantDatesEnabled: Bool {
        get { defaults.object(forKey: PrefKey.importantDates.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PrefKey.importantDates.rawValue) }
    }

    var isKmUpdateEnabled: Bool {
        get { defaults.object(forKey: PrefKey.kmUpdate.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PrefKey.kmUpdate.rawValue) }
    }

    var isMonthlySummaryEnabled: Bool {
        get { defaults.object(forKey: PrefKey.monthlySummary.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PrefKey.monthlySummary.rawValue) }
    }

    var isDocumentCompletenessEnabled: Bool {
        get { defaults.object(forKey: PrefKey.documentCompleteness.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PrefKey.documentCompleteness.rawValue) }
    }

    var isSeasonalEnabled: Bool {
        get { defaults.object(forKey: PrefKey.seasonal.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PrefKey.seasonal.rawValue) }
    }

    var isSaleFileReminderEnabled: Bool {
        get { defaults.object(forKey: PrefKey.saleFile.rawValue) as? Bool ?? false }
        set { defaults.set(newValue, forKey: PrefKey.saleFile.rawValue) }
    }

    enum KmUpdateFrequency: String, CaseIterable {
        case weekly = "weekly"
        case monthly = "monthly"
        case quarterly = "quarterly"
        case biannual = "biannual"

        var displayName: String {
            switch self {
            case .weekly: return "Haftada 1"
            case .monthly: return "Ayda 1"
            case .quarterly: return "3 Ayda 1"
            case .biannual: return "6 Ayda 1"
            }
        }

        func nextDate(from date: Date) -> Date? {
            let calendar = Calendar.current
            switch self {
            case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
            case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
            case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date)
            case .biannual: return calendar.date(byAdding: .month, value: 6, to: date)
            }
        }
    }

    var kmUpdateFrequency: KmUpdateFrequency {
        get {
            guard let raw = defaults.string(forKey: PrefKey.kmUpdateFrequency.rawValue),
                  let freq = KmUpdateFrequency(rawValue: raw) else {
                return .quarterly
            }
            return freq
        }
        set { defaults.set(newValue.rawValue, forKey: PrefKey.kmUpdateFrequency.rawValue) }
    }

    // MARK: - Identifier Prefixes
    private enum IdPrefix: String {
        case kmUpdate = "retention-km"
        case monthlySummary = "retention-summary"
        case docCompleteness = "retention-doc"
        case seasonal = "retention-seasonal"
        case saleFile = "retention-salefile"
    }

    // MARK: - Quiet Hours (21:00 - 09:00)
    static let quietHourStart = 21
    static let quietHourEnd = 9

    /// Bir tarihi sessiz saatler dışına ayarlar. Testable static method.
    static func adjustedForQuietHours(_ date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour >= quietHourStart || hour < quietHourEnd {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = quietHourEnd
            components.minute = 0
            components.second = 0
            if let adjusted = calendar.date(from: components) {
                if adjusted < date {
                    return calendar.date(byAdding: .day, value: 1, to: adjusted) ?? adjusted
                }
                return adjusted
            }
        }
        return date
    }

    // MARK: - Reschedule All
    func rescheduleAll(vehicles: [Vehicle], fileScores: [UUID: Int] = [:]) async {
        cancelRetentionNotifications()

        let status = await NotificationService.shared.currentAuthorizationStatus()
        guard status == .authorized else { return }

        await scheduleKmUpdateReminder(vehicles: vehicles)
        await scheduleMonthlySummaryReminder(vehicleCount: vehicles.count)
        await scheduleDocumentCompletenessReminder(vehicles: vehicles, fileScores: fileScores)
        await scheduleSeasonalReminders()
        await scheduleSaleFileReminderIfEligible(vehicles: vehicles)
    }

    // MARK: - Km Update
    func scheduleKmUpdateReminder(vehicles: [Vehicle]) async {
        guard isKmUpdateEnabled else { return }

        for vehicle in vehicles {
            guard vehicle.currentOdometer > 0,
                  vehicle.archivedAt == nil else { continue }
            await scheduleKmUpdateForVehicle(vehicle)
        }
    }

    private func scheduleKmUpdateForVehicle(_ vehicle: Vehicle) async {
        guard let nextDate = kmUpdateFrequency.nextDate(from: Date()) else { return }
        let fireDate = Self.adjustedForQuietHours(nextDate)

        let id = "\(IdPrefix.kmUpdate.rawValue)-\(vehicle.id.uuidString)"
        guard !(await isAlreadyScheduled(identifier: id)) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Kilometre Güncelleme"
        content.body = "Aracının güncel kilometresini girmeyi unutma. Düzenli km takibi masraf ve bakım planlamana yardımcı olur."
        content.sound = .default
        content.badge = 1
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["deepLink": "vehicleDetail", "vehicleId": vehicle.id.uuidString]

        schedule(id: id, content: content, date: fireDate)
    }

    // MARK: - Monthly Summary
    func scheduleMonthlySummaryReminder(vehicleCount: Int) async {
        guard isMonthlySummaryEnabled, vehicleCount > 0 else { return }

        let id = monthlySummaryIdentifier()
        guard !(await isAlreadyScheduled(identifier: id)),
              !wasMonthlySummarySentThisMonth() else { return }

        var components = Calendar.current.dateComponents([.year, .month], from: Date())
        components.day = 2
        components.hour = 10
        components.minute = 0
        guard let fireDate = Calendar.current.date(from: components),
              fireDate > Date() else { return }

        let adjusted = Self.adjustedForQuietHours(fireDate)
        guard adjusted > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Aylık Garaj Özetin"
        content.body = "Bu ay araçlarının masraf ve bakım özetini görüntülemek için Garajım'a göz at."
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["deepLink": "records"]

        schedule(id: id, content: content, date: adjusted)
    }

    func monthlySummaryIdentifier() -> String {
        let month = Calendar.current.component(.month, from: Date())
        let year = Calendar.current.component(.year, from: Date())
        return "\(IdPrefix.monthlySummary.rawValue)-\(year)-\(month)"
    }

    func wasMonthlySummarySentThisMonth() -> Bool {
        let key = "retention_last_monthly_summary"
        let lastSent = defaults.string(forKey: key) ?? ""
        let current = String(ISO8601DateFormatter().string(from: Date()).prefix(7))
        if lastSent == current { return true }
        return false
    }

    func markMonthlySummarySent() {
        let key = "retention_last_monthly_summary"
        let current = String(ISO8601DateFormatter().string(from: Date()).prefix(7))
        defaults.set(current, forKey: key)
    }

    // MARK: - Document Completeness
    func scheduleDocumentCompletenessReminder(vehicles: [Vehicle], fileScores: [UUID: Int]) async {
        guard isDocumentCompletenessEnabled else { return }

        for vehicle in vehicles {
            guard vehicle.archivedAt == nil else { continue }
            let score = fileScores[vehicle.id] ?? 0
            guard score < 70 else { continue }

            let id = "\(IdPrefix.docCompleteness.rawValue)-\(vehicle.id.uuidString)"
            guard !(await isAlreadyScheduled(identifier: id)),
                  !isInCooldown(vehicleId: vehicle.id, category: "doc", days: 30) else { continue }

            guard let fireDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) else { continue }
            let adjusted = Self.adjustedForQuietHours(fireDate)

            let content = UNMutableNotificationContent()
            content.title = "Araç Dosyanı Tamamla"
            content.body = "Aracının dosyası %\(score) tamlık seviyesinde. Eksik bilgileri tamamlayarak satışa hazır hale getirebilirsin."
            content.sound = .default
            content.interruptionLevel = .active
            content.userInfo = ["deepLink": "vehicleDetail", "vehicleId": vehicle.id.uuidString]

            schedule(id: id, content: content, date: adjusted)
            markCooldown(vehicleId: vehicle.id, category: "doc")
        }
    }

    // MARK: - Seasonal
    func scheduleSeasonalReminders() async {
        guard isSeasonalEnabled else { return }
        guard seasonalCountForCurrentYear() < 4 else { return }

        let seasons: [(String, Int, String, String)] = [
            ("kis", 12, "Kış Bakımı", "Kış öncesi antifriz, akü ve lastik kontrolü yapmayı unutma."),
            ("ilkbahar", 3, "İlkbahar Bakımı", "Kış sonrası süspansiyon ve klima kontrolü için iyi bir zaman."),
            ("yaz", 6, "Yaz Bakımı", "Yaz öncesi klima ve soğutma sistemi kontrolünü ihmal etme."),
            ("sonbahar", 9, "Sonbahar Bakımı", "Kışa hazırlık için fren ve ısıtma sistemi kontrolü yaptır."),
        ]

        for (key, month, title, body) in seasons {
            let id = "\(IdPrefix.seasonal.rawValue)-\(key)-\(Calendar.current.component(.year, from: Date()))"
            guard !(await isAlreadyScheduled(identifier: id)) else { continue }

            var components = DateComponents()
            components.year = Calendar.current.component(.year, from: Date())
            components.month = month
            components.day = 1
            components.hour = 10
            components.minute = 0
            guard let baseDate = Calendar.current.date(from: components),
                  let fireDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: baseDate),
                  fireDate > Date() else { continue }

            let adjusted = Self.adjustedForQuietHours(fireDate)
            guard adjusted > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.interruptionLevel = .active
            content.userInfo = ["deepLink": "records"]

            schedule(id: id, content: content, date: adjusted)
        }
    }

    func seasonalCountForCurrentYear() -> Int {
        let key = "retention_seasonal_count_\(Calendar.current.component(.year, from: Date()))"
        return defaults.integer(forKey: key)
    }

    func markSeasonalSent() {
        let year = Calendar.current.component(.year, from: Date())
        let key = "retention_seasonal_count_\(year)"
        let count = defaults.integer(forKey: key)
        defaults.set(count + 1, forKey: key)
    }

    // MARK: - Sale File
    func scheduleSaleFileReminderIfEligible(vehicles: [Vehicle]) async {
        guard isSaleFileReminderEnabled else { return }

        for vehicle in vehicles {
            guard vehicle.archivedAt == nil else { continue }
            let id = "\(IdPrefix.saleFile.rawValue)-\(vehicle.id.uuidString)"
            guard !(await isAlreadyScheduled(identifier: id)),
                  !isInCooldown(vehicleId: vehicle.id, category: "salefile", days: 90) else { continue }

            guard let fireDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) else { continue }
            let adjusted = Self.adjustedForQuietHours(fireDate)

            let content = UNMutableNotificationContent()
            content.title = "Satış Dosyası Hazırla"
            content.body = "Aracının satış dosyasını oluşturmak için belgelerini ve bilgilerini tamamla. Potansiyel alıcılara hazır bir dosya sun."
            content.sound = .default
            content.interruptionLevel = .active
            content.userInfo = ["deepLink": "vehicleDetail", "vehicleId": vehicle.id.uuidString]

            schedule(id: id, content: content, date: adjusted)
            markCooldown(vehicleId: vehicle.id, category: "salefile")
        }
    }

    // MARK: - Cancel
    func cancelRetentionNotifications() {
        let prefixPatterns = [
            IdPrefix.kmUpdate.rawValue,
            IdPrefix.monthlySummary.rawValue,
            IdPrefix.docCompleteness.rawValue,
            IdPrefix.seasonal.rawValue,
            IdPrefix.saleFile.rawValue,
        ]
        center.getPendingNotificationRequests { [weak self] requests in
            let toRemove = requests.filter { req in
                prefixPatterns.contains { req.identifier.hasPrefix($0) }
            }.map { $0.identifier }
            self?.center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }

    // Tüm retention notification'ları ve reminder notification'ları iptal et.
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Pending Count
    func pendingRetentionCount(completion: @escaping (Int) -> Void) {
        let prefixPatterns = [
            IdPrefix.kmUpdate.rawValue,
            IdPrefix.monthlySummary.rawValue,
            IdPrefix.docCompleteness.rawValue,
            IdPrefix.seasonal.rawValue,
            IdPrefix.saleFile.rawValue,
        ]
        center.getPendingNotificationRequests { requests in
            let count = requests.filter { req in
                prefixPatterns.contains { req.identifier.hasPrefix($0) }
            }.count
            completion(count)
        }
    }

    // MARK: - Internal Helpers

    func isAlreadyScheduled(identifier: String) async -> Bool {
        let requests = await center.pendingNotificationRequests()
        return requests.contains { $0.identifier == identifier }
    }

    func isInCooldown(vehicleId: UUID, category: String, days: Int) -> Bool {
        let key = "retention_cooldown_\(category)_\(vehicleId.uuidString)"
        guard let lastSent = defaults.object(forKey: key) as? Date else { return false }
        let cooldownEnd = Calendar.current.date(byAdding: .day, value: days, to: lastSent) ?? lastSent
        return Date() < cooldownEnd
    }

    func markCooldown(vehicleId: UUID, category: String) {
        let key = "retention_cooldown_\(category)_\(vehicleId.uuidString)"
        defaults.set(Date(), forKey: key)
    }

    private func schedule(id: String, content: UNMutableNotificationContent, date: Date) {
        guard date > Date() else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("RetentionNotificationService: schedule error for \(id): \(error)")
            }
        }
    }
}
