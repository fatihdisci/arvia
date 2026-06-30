import Foundation

// MARK: - Reminder Repeat Engine
// Tekrarlayan hatırlatıcılar için bir sonraki tarihi hesaplar.
// Tamamen side-effect free, test edilebilir bir yapı.

enum ReminderRepeatRule: String, CaseIterable {
    case none
    case monthly
    case quarterly
    case biannual
    case yearly
    case custom // UI'da gösterilmez, özel periyot için ayrılmıştır.

    var displayName: String {
        switch self {
        case .none: return "Tekrar Yok"
        case .monthly: return "Her Ay"
        case .quarterly: return "3 Ayda Bir"
        case .biannual: return "6 Ayda Bir"
        case .yearly: return "Her Yıl"
        case .custom: return "Özel"
        }
    }
}

struct ReminderRepeatEngine {
    static let shared = ReminderRepeatEngine()

    private init() {}

    /// Verilen tarihe ve tekrar kuralına göre bir sonraki due date'i hesaplar.
    /// - Parameters:
    ///   - date: Baz alınacak tarih (genellikle mevcut dueDate veya tamamlanma anı).
    ///   - rule: Tekrar kuralı.
    /// - Returns: Bir sonraki due date, veya tekrar yoksa/saptanamazsa nil.
    func nextDueDate(from date: Date, rule: ReminderRepeatRule) -> Date? {
        let calendar = Calendar.current
        switch rule {
        case .none:
            return nil
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .biannual:
            return calendar.date(byAdding: .month, value: 6, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        case .custom:
            // Özel periyot üretimde kapalı; güvenli nil dönüş.
            return nil
        }
    }

    /// Reminder modelindeki `repeatRuleRaw` string'ini parse eder.
    func rule(from rawValue: String?) -> ReminderRepeatRule {
        guard let raw = rawValue else { return .none }
        return ReminderRepeatRule(rawValue: raw) ?? .none
    }
}
