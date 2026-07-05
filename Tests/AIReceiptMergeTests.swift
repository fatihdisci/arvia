import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - AI Receipt Merge Tests
// AI-vs-kullanıcı düzenlemesi birleştirme kuralları + degrade yolları.
final class AIReceiptMergeTests: XCTestCase {

    // 1 — boş alan, kullanıcı düzenlememiş → AI uygula.
    func testAppliesToEmptyField() {
        XCTAssertTrue(AIReceiptMerge.shouldApply(currentIsEmpty: true, userEdited: false, localConfidence: 0.9, aiHasValue: true))
    }

    // 2 — dolu ama düşük güven, düzenlenmemiş → AI uygula.
    func testAppliesToLowConfidenceField() {
        XCTAssertTrue(AIReceiptMerge.shouldApply(currentIsEmpty: false, userEdited: false, localConfidence: 0.3, aiHasValue: true))
    }

    // 3 — dolu + yüksek güven, düzenlenmemiş → dokunma.
    func testSkipsHighConfidenceField() {
        XCTAssertFalse(AIReceiptMerge.shouldApply(currentIsEmpty: false, userEdited: false, localConfidence: 0.9, aiHasValue: true))
    }

    // 4 — kullanıcı düzenlemiş → asla üzerine yazma.
    func testNeverOverwritesUserEdit() {
        XCTAssertFalse(AIReceiptMerge.shouldApply(currentIsEmpty: true, userEdited: true, localConfidence: 0.1, aiHasValue: true))
    }

    // 5 — AI değeri yoksa → uygulama.
    func testSkipsWhenAIHasNoValue() {
        XCTAssertFalse(AIReceiptMerge.shouldApply(currentIsEmpty: true, userEdited: false, localConfidence: 0.1, aiHasValue: false))
    }

    // 6 — maintenance kararı: uyumlu ise otomatik, çelişki/dokunma ise nötr.
    func testMaintenanceDecision() {
        XCTAssertEqual(AIReceiptMerge.maintenanceDecision(aiIsMaintenance: true, aiCategory: "maintenance", toggleTouched: false), true)
        XCTAssertEqual(AIReceiptMerge.maintenanceDecision(aiIsMaintenance: false, aiCategory: "fuel", toggleTouched: false), false)
        XCTAssertNil(AIReceiptMerge.maintenanceDecision(aiIsMaintenance: true, aiCategory: "fuel", toggleTouched: false)) // belirsiz
        XCTAssertNil(AIReceiptMerge.maintenanceDecision(aiIsMaintenance: true, aiCategory: "maintenance", toggleTouched: true)) // kullanıcı seçti
    }

    // 7 — kategori eşleme.
    func testCategoryMapping() {
        XCTAssertEqual(AIReceiptMerge.category(from: "fuel"), .fuel)
        XCTAssertEqual(AIReceiptMerge.category(from: "maintenance"), .service)
        XCTAssertEqual(AIReceiptMerge.category(from: "insurance"), .insurance)
        XCTAssertEqual(AIReceiptMerge.category(from: "tire"), .tire)
        XCTAssertNil(AIReceiptMerge.category(from: "unknown"))
        XCTAssertNil(AIReceiptMerge.category(from: nil))
    }

    // MARK: - Degrade paths
    func testAutoEscalateOnlyWhenLowConfidenceAndAvailable() {
        XCTAssertTrue(AIReceiptEscalation.shouldAutoEscalate(overallConfidence: 0.5, aiAvailable: true))
        XCTAssertFalse(AIReceiptEscalation.shouldAutoEscalate(overallConfidence: 0.5, aiAvailable: false))
        XCTAssertFalse(AIReceiptEscalation.shouldAutoEscalate(overallConfidence: 0.7, aiAvailable: true))
    }

    func testDisabledDegradesSilently() {
        XCTAssertNil(AIReceiptEscalation.notice(for: .disabled))
    }

    func testQuotaShowsGentleNotice() {
        XCTAssertNotNil(AIReceiptEscalation.notice(for: .quotaExceeded(task: "receipt_parse")))
    }

    func testOtherErrorsAreSilent() {
        XCTAssertNil(AIReceiptEscalation.notice(for: .upstream(status: 500)))
    }
}
