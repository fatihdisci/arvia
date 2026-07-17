import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - Analytics Service Tests
// Event/parametre isim sözleşmesinin CLAUDE.md standardıyla eşleştiğini ve
// bucket yardımcılarının doğru çalıştığını doğrular.
final class AnalyticsServiceTests: XCTestCase {

    // 1 — onboarding event isimleri standarda uygun.
    func testOnboardingEventRawValues() {
        XCTAssertEqual(AnalyticsEvent.onboardingStarted.rawValue, "onboarding_started")
        XCTAssertEqual(AnalyticsEvent.onboardingGoalSelected.rawValue, "onboarding_goal_selected")
        XCTAssertEqual(AnalyticsEvent.onboardingVehicleStepStarted.rawValue, "onboarding_vehicle_step_started")
        XCTAssertEqual(AnalyticsEvent.onboardingVehicleAdded.rawValue, "onboarding_vehicle_added")
        XCTAssertEqual(AnalyticsEvent.onboardingNotificationPromptViewed.rawValue, "onboarding_notification_prompt_viewed")
        XCTAssertEqual(AnalyticsEvent.onboardingNotificationPermissionResult.rawValue, "onboarding_notification_permission_result")
        XCTAssertEqual(AnalyticsEvent.onboardingCompleted.rawValue, "onboarding_completed")
        XCTAssertEqual(AnalyticsEvent.onboardingSkipped.rawValue, "onboarding_skipped")
    }

    // 2 — kayıt yaşam döngüsü eventleri.
    func testRecordLifecycleEventRawValues() {
        XCTAssertEqual(AnalyticsEvent.vehicleAdded.rawValue, "vehicle_added")
        XCTAssertEqual(AnalyticsEvent.vehicleUpdated.rawValue, "vehicle_updated")
        XCTAssertEqual(AnalyticsEvent.vehicleDeleted.rawValue, "vehicle_deleted")
        XCTAssertEqual(AnalyticsEvent.mileageUpdated.rawValue, "mileage_updated")
        XCTAssertEqual(AnalyticsEvent.reminderAdded.rawValue, "reminder_added")
        XCTAssertEqual(AnalyticsEvent.reminderCompleted.rawValue, "reminder_completed")
        XCTAssertEqual(AnalyticsEvent.reminderDeleted.rawValue, "reminder_deleted")
        XCTAssertEqual(AnalyticsEvent.expenseAdded.rawValue, "expense_added")
        XCTAssertEqual(AnalyticsEvent.expenseUpdated.rawValue, "expense_updated")
        XCTAssertEqual(AnalyticsEvent.expenseDeleted.rawValue, "expense_deleted")
        XCTAssertEqual(AnalyticsEvent.maintenanceAdded.rawValue, "maintenance_added")
    }

    // 3 — belge ve rapor eventleri.
    func testDocumentAndReportEventRawValues() {
        XCTAssertEqual(AnalyticsEvent.documentUploadStarted.rawValue, "document_upload_started")
        XCTAssertEqual(AnalyticsEvent.documentUploadCompleted.rawValue, "document_upload_completed")
        XCTAssertEqual(AnalyticsEvent.documentUploadFailed.rawValue, "document_upload_failed")
        XCTAssertEqual(AnalyticsEvent.reportViewed.rawValue, "report_viewed")
        XCTAssertEqual(AnalyticsEvent.salesPdfCreated.rawValue, "sales_pdf_created")
    }

    // 4 — paywall/abonelik eventleri.
    func testPaywallEventRawValues() {
        XCTAssertEqual(AnalyticsEvent.paywallViewed.rawValue, "paywall_viewed")
        XCTAssertEqual(AnalyticsEvent.purchaseStarted.rawValue, "purchase_started")
        XCTAssertEqual(AnalyticsEvent.purchaseCompleted.rawValue, "purchase_completed")
        XCTAssertEqual(AnalyticsEvent.purchaseFailed.rawValue, "purchase_failed")
        XCTAssertEqual(AnalyticsEvent.purchaseRestored.rawValue, "purchase_restored")
        XCTAssertEqual(AnalyticsEvent.subscriptionStatusChanged.rawValue, "subscription_status_changed")
    }

    // 5 — parametre anahtarları standarda uygun.
    func testParameterKeyRawValues() {
        XCTAssertEqual(AnalyticsParameterKey.primaryGoal.rawValue, "primary_goal")
        XCTAssertEqual(AnalyticsParameterKey.vehicleCountBucket.rawValue, "vehicle_count_bucket")
        XCTAssertEqual(AnalyticsParameterKey.reminderType.rawValue, "reminder_type")
        XCTAssertEqual(AnalyticsParameterKey.expenseCategory.rawValue, "expense_category")
        XCTAssertEqual(AnalyticsParameterKey.documentCategory.rawValue, "document_category")
        XCTAssertEqual(AnalyticsParameterKey.paywallPlacement.rawValue, "paywall_placement")
        XCTAssertEqual(AnalyticsParameterKey.paywallVariant.rawValue, "paywall_variant")
        XCTAssertEqual(AnalyticsParameterKey.subscriptionProduct.rawValue, "subscription_product")
        XCTAssertEqual(AnalyticsParameterKey.sourceScreen.rawValue, "source_screen")
        XCTAssertEqual(AnalyticsParameterKey.onboardingVersion.rawValue, "onboarding_version")
    }

    // 6 — araç sayısı bucket sınırları.
    func testVehicleCountBucketing() {
        guard case .string(let zero) = AnalyticsService.vehicleCountBucket(0) else {
            return XCTFail("beklenen .string case")
        }
        XCTAssertEqual(zero, "0")

        guard case .string(let one) = AnalyticsService.vehicleCountBucket(1) else {
            return XCTFail("beklenen .string case")
        }
        XCTAssertEqual(one, "1")

        guard case .string(let two) = AnalyticsService.vehicleCountBucket(2) else {
            return XCTFail("beklenen .string case")
        }
        XCTAssertEqual(two, "2-3")

        guard case .string(let three) = AnalyticsService.vehicleCountBucket(3) else {
            return XCTFail("beklenen .string case")
        }
        XCTAssertEqual(three, "2-3")

        guard case .string(let many) = AnalyticsService.vehicleCountBucket(4) else {
            return XCTFail("beklenen .string case")
        }
        XCTAssertEqual(many, "4+")

        guard case .string(let evenMore) = AnalyticsService.vehicleCountBucket(50) else {
            return XCTFail("beklenen .string case")
        }
        XCTAssertEqual(evenMore, "4+")
    }

    // 7 — log() parametresiz varyant çökmeden çalışır (no-op sözleşmesi).
    func testLogWithoutParametersDoesNotCrash() {
        AnalyticsService.shared.log(.onboardingStarted)
        AnalyticsService.shared.log(.vehicleAdded, parameters: [.vehicleCountBucket: .string("1")])
    }

    // 8 — protokol soyutlaması üzerinden mock kayıt (event mapping test edilebilir).
    func testMockRecorderCapturesLoggedEvent() {
        final class RecordingAnalytics: AnalyticsLogging {
            private(set) var loggedEvents: [(AnalyticsEvent, [AnalyticsParameterKey: AnalyticsParameterValue])] = []
            func log(_ event: AnalyticsEvent, parameters: [AnalyticsParameterKey: AnalyticsParameterValue]) {
                loggedEvents.append((event, parameters))
            }
        }

        let recorder = RecordingAnalytics()
        recorder.log(.reminderAdded, parameters: [.reminderType: .string("inspection")])

        XCTAssertEqual(recorder.loggedEvents.count, 1)
        XCTAssertEqual(recorder.loggedEvents.first?.0, .reminderAdded)
        if case .string(let value) = recorder.loggedEvents.first?.1[.reminderType] {
            XCTAssertEqual(value, "inspection")
        } else {
            XCTFail("beklenen .string parametre değeri")
        }
    }
}
