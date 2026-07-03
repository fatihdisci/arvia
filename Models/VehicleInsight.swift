import Foundation

// MARK: - Arvia Rehber Insight Models
// AI-ready surface: v1 uses only rule-based local insights.
// Faz 1.1 (Karar 4.2): 5 içerik tipi + opsiyonel action + dismiss/snooze.

struct VehicleInsight: Identifiable, Equatable {
    let id: String
    let type: VehicleInsightType
    let priority: VehicleInsightPriority
    let source: VehicleInsightSource
    let contentKind: VehicleInsightContentKind
    let title: String
    let body: String
    let action: VehicleInsightAction?
    let snoozeDays: Int?
    let relatedReminderId: UUID?

    init(
        type: VehicleInsightType,
        priority: VehicleInsightPriority,
        source: VehicleInsightSource = .ruleBased,
        contentKind: VehicleInsightContentKind = .callToAction,
        title: String,
        body: String,
        action: VehicleInsightAction?,
        snoozeDays: Int? = nil,
        relatedReminderId: UUID? = nil
    ) {
        self.id = relatedReminderId.map { "\(type.rawValue)-\($0.uuidString)" } ?? type.rawValue
        self.type = type
        self.priority = priority
        self.source = source
        self.contentKind = contentKind
        self.title = title
        self.body = body
        self.action = action
        self.snoozeDays = snoozeDays
        self.relatedReminderId = relatedReminderId
    }
}

// MARK: - Content Kind (Faz 1.1)
// 5 içerik tipi kategorisi — Gemini raporu Bölüm 5.1.
// Karar sınıfı: bu enum, kartın nasıl görüneceğini ve nasıl etkileşeceğini belirler.
enum VehicleInsightContentKind: String, Codable, CaseIterable {
    /// A. Eylem — zorunlu CTA, dismiss yok.
    case callToAction
    /// B. Bilgi — sadece dismiss butonu, CTA yok.
    case info
    /// C. Uyarı — geçmiş ekranı + dismiss.
    case warning
    /// D. Hatırlatma — pasif hatırlatma + dismiss.
    case reminder
    /// E. Yumuşak Soru — çift buton (Ekle + Şimdi Değil).
    case softQuestion
}

enum VehicleInsightType: String, CaseIterable {
    case maintenance
    case missingDocument
    case saleFileReadiness
    case odometerUpdate
    case overdueReminder
    case monthlyExpensePrompt
    case upcomingReminder
    case fuelTypeGuidance
    case transmissionGuidance
    case odometerMilestone
    case seasonalGuidance
    case calendarPeriod
    case quietGoodState
}

enum VehicleInsightPriority: String {
    case info
    case warning
    case important
}

enum VehicleInsightSource: String {
    case ruleBased
    case aiGenerated
}

enum VehicleInsightDisplayContext {
    case garageDaily
    case vehicleDetailGuide(excludingReminderIds: Set<UUID> = [])
}

enum VehicleInsightAction: String, CaseIterable {
    // Mevcut CTA aksiyonları (korunur — geriye uyumluluk)
    case addServiceRecord
    case addDocument
    case openSaleFile
    case updateOdometer
    case openTodos
    case addInspectionReport
    case addReminder
    case addMTVReminder
    case addExpense
    case addFuelExpense

    // Faz 1.1 (Karar 4.2) — yeni meta-aksiyonlar
    case dismissAndSnooze   // Kullanıcı dismiss + snooze
    case markAsRead         // Sadece okundu işaretle
    case acknowledge        // "Anlaşıldı"
    case noAction           // Pasif, göster ama etkileşim yok

    var title: String {
        switch self {
        case .addServiceRecord:
            return "Bakım Kaydı Ekle"
        case .addDocument:
            return "Belge Ekle"
        case .openSaleFile:
            return "Satış Dosyasına Git"
        case .updateOdometer:
            return "Km Güncelle"
        case .openTodos:
            return "Yapılacaklara Git"
        case .addInspectionReport:
            return "Ekspertiz Ekle"
        case .addReminder:
            return "Hatırlatıcı Ekle"
        case .addMTVReminder:
            return "MTV Hatırlatıcısı Ekle"
        case .addExpense:
            return "Masraf Ekle"
        case .addFuelExpense:
            return "Yakıt Ekle"
        case .acknowledge:
            return "Anlaşıldı"
        case .dismissAndSnooze, .markAsRead, .noAction:
            return ""
        }
    }

    var destinationKey: String {
        switch self {
        case .addServiceRecord:
            return "serviceRecordForm"
        case .addDocument:
            return "documentForm"
        case .openSaleFile:
            return "saleFile"
        case .updateOdometer:
            return "vehicleEdit"
        case .openTodos:
            return "todosTab"
        case .addInspectionReport:
            return "inspectionReportForm"
        case .addReminder:
            return "reminderForm"
        case .addMTVReminder:
            return "mtvReminderForm"
        case .addExpense:
            return "expenseForm"
        case .addFuelExpense:
            return "fuelExpenseForm"
        case .acknowledge, .dismissAndSnooze, .markAsRead, .noAction:
            return ""
        }
    }
}

struct VehicleUpcomingTask: Identifiable, Equatable {
    let id: UUID
    let title: String
    let relativeText: String
    let priority: VehicleInsightPriority
    let reminderId: UUID
}

struct MonthlyExpenseSummary: Equatable {
    let total: Double
    let count: Int
    let topCategory: ExpenseCategory?

    var isEmpty: Bool { count == 0 }
}

enum QuickOdometerValidationResult: Equatable {
    case valid
    case empty
    case invalid
    case negative
    case lowerNeedsConfirmation
}