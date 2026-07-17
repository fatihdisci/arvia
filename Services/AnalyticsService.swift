import Foundation
import OSLog

// MARK: - Analytics Service
// Merkezi, SDK'sız event kayıt soyutlaması. Bugün yalnızca DEBUG'ta OSLog'a yazar;
// ileride gerçek bir analytics SDK'sı bu protokolün arkasına eklenebilir — çağıran
// kod değişmez.
// Parametreler yalnızca tip-güvenli enum/bucket değerleri alır; serbest metin
// (plaka, isim, e-posta, not, dosya URL'i vb.) bu API üzerinden GÖNDERİLEMEZ.

enum AnalyticsEvent: String {
    case onboardingStarted = "onboarding_started"
    case onboardingGoalSelected = "onboarding_goal_selected"
    case onboardingVehicleStepStarted = "onboarding_vehicle_step_started"
    case onboardingVehicleAdded = "onboarding_vehicle_added"
    case onboardingNotificationPromptViewed = "onboarding_notification_prompt_viewed"
    case onboardingNotificationPermissionResult = "onboarding_notification_permission_result"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case vehicleAdded = "vehicle_added"
    case vehicleUpdated = "vehicle_updated"
    case vehicleDeleted = "vehicle_deleted"
    case mileageUpdated = "mileage_updated"
    case reminderAdded = "reminder_added"
    case reminderCompleted = "reminder_completed"
    case reminderDeleted = "reminder_deleted"
    case expenseAdded = "expense_added"
    case expenseUpdated = "expense_updated"
    case expenseDeleted = "expense_deleted"
    case maintenanceAdded = "maintenance_added"
    case documentUploadStarted = "document_upload_started"
    case documentUploadCompleted = "document_upload_completed"
    case documentUploadFailed = "document_upload_failed"
    case reportViewed = "report_viewed"
    case salesPdfCreated = "sales_pdf_created"
    case paywallViewed = "paywall_viewed"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case purchaseRestored = "purchase_restored"
    case subscriptionStatusChanged = "subscription_status_changed"
}

enum AnalyticsParameterKey: String {
    case primaryGoal = "primary_goal"
    case vehicleCountBucket = "vehicle_count_bucket"
    case reminderType = "reminder_type"
    case expenseCategory = "expense_category"
    case documentCategory = "document_category"
    case paywallPlacement = "paywall_placement"
    case paywallVariant = "paywall_variant"
    case subscriptionProduct = "subscription_product"
    case sourceScreen = "source_screen"
    case onboardingVersion = "onboarding_version"
    /// İzin/sonuç eventleri için (ör. bildirim izni verildi mi). Boolean değer.
    case granted = "granted"
}

/// Yalnızca tip-güvenli değerler. Serbest metin (kullanıcı girişi) buraya taşınmamalı —
/// çağıran taraf her zaman sabit bir enum/bucket değeri üretmelidir.
enum AnalyticsParameterValue {
    case string(String)
    case int(Int)
    case bool(Bool)

    fileprivate var loggableDescription: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .bool(let value): return String(value)
        }
    }
}

protocol AnalyticsLogging {
    func log(_ event: AnalyticsEvent, parameters: [AnalyticsParameterKey: AnalyticsParameterValue])
}

extension AnalyticsLogging {
    func log(_ event: AnalyticsEvent) {
        log(event, parameters: [:])
    }
}

final class AnalyticsService: AnalyticsLogging {
    static let shared = AnalyticsService()

    private static let logger = Logger(subsystem: "com.ruhsatim.app", category: "Analytics")

    private init() {}

    func log(_ event: AnalyticsEvent, parameters: [AnalyticsParameterKey: AnalyticsParameterValue] = [:]) {
        #if DEBUG
        let paramList = parameters
            .map { "\($0.key.rawValue)=\($0.value.loggableDescription)" }
            .sorted()
            .joined(separator: ", ")
        Self.logger.debug("\(event.rawValue, privacy: .public) [\(paramList, privacy: .public)]")
        #endif
        // Production: gerçek SDK bağlanana kadar sessizce yutulur (no-op).
        // Event/parametre sözleşmesi bu dosyada sabit kaldığı sürece SDK eklemek
        // yalnızca bu fonksiyonun gövdesini değiştirmeyi gerektirir.
    }

    // MARK: - Bucketing Helpers
    /// Ham araç sayısını bucket'a çevirir — tekil değerler yerine aralık raporlanır.
    static func vehicleCountBucket(_ count: Int) -> AnalyticsParameterValue {
        switch count {
        case 0: return .string("0")
        case 1: return .string("1")
        case 2...3: return .string("2-3")
        default: return .string("4+")
        }
    }
}
