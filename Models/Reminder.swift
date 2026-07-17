import Foundation
import SwiftData

// MARK: - Reminder Model
@Model
final class Reminder {
    // CloudKit uyumu için tüm non-optional alanlara property seviyesinde default verildi.
    var id: UUID = UUID()
    var vehicleId: UUID = UUID()
    var typeRaw: String = ReminderType.custom.rawValue
    var title: String = ""
    var dueDate: Date?
    var dueOdometer: Int?
    var repeatRuleRaw: String?
    var priorityRaw: String = ReminderPriority.info.rawValue
    var statusRaw: String = ReminderStatus.active.rawValue
    var completedAt: Date?
    /// addedToHistoryAt != nil → Geçmiş tabında görünür.
    /// addedToHistoryAt == nil → sadece tamamlandı, Geçmiş'te gösterilmez.
    var addedToHistoryAt: Date?
    var notes: String = ""
    /// Belge formundan otomatik oluşturulan hatırlatıcının kaynak belgesi.
    /// Optional alan, mevcut 1.0.1 kayıtları ve CloudKit migration'ı ile uyumludur.
    var sourceDocumentId: UUID?
    var createdAt: Date = Date()

    // MARK: Computed — Enum dönüşümleri
    var type: ReminderType {
        get { ReminderType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    var priority: ReminderPriority {
        get { ReminderPriority(rawValue: priorityRaw) ?? .info }
        set { priorityRaw = newValue.rawValue }
    }

    var status: ReminderStatus {
        get { ReminderStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    // MARK: Computed — Repeat rule
    var repeatRule: ReminderRepeatRule {
        ReminderRepeatEngine.shared.rule(from: repeatRuleRaw)
    }

    // MARK: Computed properties
    var isOverdue: Bool {
        guard statusRaw != ReminderStatus.completed.rawValue,
              statusRaw != ReminderStatus.archived.rawValue,
              let dueDate else { return false }
        return dueDate < Date()
    }

    // MARK: Km-based durum
    /// Km eşiği olan aktif hatırlatıcının, aracın mevcut km'sine göre gecikmiş olup olmadığını döner.
    func isKmOverdue(vehicleOdometer: Int) -> Bool {
        guard let dueOdometer,
              statusRaw != ReminderStatus.completed.rawValue,
              statusRaw != ReminderStatus.archived.rawValue else { return false }
        return vehicleOdometer >= dueOdometer
    }

    /// Km eşiğine yaklaşan (belirtilen km aralığında) aktif hatırlatıcı.
    func isKmUpcoming(vehicleOdometer: Int, withinKm: Int = 2000) -> Bool {
        guard let dueOdometer,
              statusRaw != ReminderStatus.completed.rawValue,
              statusRaw != ReminderStatus.archived.rawValue else { return false }
        let remaining = dueOdometer - vehicleOdometer
        return remaining > 0 && remaining <= withinKm
    }

    var isToday: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isUpcoming: Bool {
        guard let dueDate, !isOverdue, !isToday else { return false }
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 999
        return daysUntil <= 30
    }

    /// Gecikme gün sayısı. Gelecekse 0, gecikmişse pozitif.
    var daysOverdue: Int {
        guard let dueDate, isOverdue else { return 0 }
        return Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
    }

    /// Kalan gün. Gecikmişse negatif.
    var daysRemaining: Int {
        guard let dueDate else { return 999 }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 999
    }

    // MARK: Group helper
    enum GroupKey: String {
        case overdue = "Geciken"
        case today = "Bugün"
        case upcoming = "Önümüzdeki 30 Gün"
        case later = "Daha Sonra"
    }

    var groupKey: GroupKey {
        if statusRaw == ReminderStatus.completed.rawValue { return .later }
        if isOverdue { return .overdue }
        if isToday { return .today }
        if isUpcoming { return .upcoming }
        return .later
    }

    var isAddedToHistory: Bool {
        statusRaw == ReminderStatus.completed.rawValue && addedToHistoryAt != nil
    }

    static func snoozedDueDate(
        currentDueDate: Date?,
        days: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        let baseDate: Date
        if let currentDueDate {
            let dueDay = calendar.startOfDay(for: currentDueDate)
            baseDate = dueDay > today ? dueDay : today
        } else {
            baseDate = today
        }
        return calendar.date(byAdding: .day, value: days, to: baseDate) ?? baseDate
    }

    func completeAndAddToHistory(now: Date = Date()) {
        statusRaw = ReminderStatus.completed.rawValue
        completedAt = now
        addedToHistoryAt = now
    }

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        type: ReminderType = .custom,
        title: String = "",
        dueDate: Date? = nil,
        dueOdometer: Int? = nil,
        repeatRule: String? = nil,
        priority: ReminderPriority = .info,
        status: ReminderStatus = .active,
        completedAt: Date? = nil,
        addedToHistoryAt: Date? = nil,
        notes: String = "",
        sourceDocumentId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.typeRaw = type.rawValue
        self.title = title
        self.dueDate = dueDate
        self.dueOdometer = dueOdometer
        self.repeatRuleRaw = repeatRule
        self.priorityRaw = priority.rawValue
        self.statusRaw = status.rawValue
        self.completedAt = completedAt
        self.addedToHistoryAt = addedToHistoryAt
        self.notes = notes
        self.sourceDocumentId = sourceDocumentId
        self.createdAt = createdAt
    }
}
