import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - Refactor Logic Tests
// 1.1.0 refactor'ünde eklenen saf/deterministik iş mantığını doğrular:
// OnboardingGoal, ReminderType.mapsToServiceRecord (Faz 7) ve VehicleWizardDraft
// doğrulama gating'i. UI/container gerektirmez.
final class RefactorLogicTests: XCTestCase {

    // MARK: - OnboardingGoal

    // 1 — Her amaç için boş olmayan başlık/ikon; analyticsValue == rawValue (PII yok).
    func testOnboardingGoalMetadata() {
        for goal in OnboardingGoal.allCases {
            XCTAssertFalse(goal.title.isEmpty, "\(goal) başlık boş olmamalı")
            XCTAssertFalse(goal.icon.isEmpty, "\(goal) ikon boş olmamalı")
            XCTAssertEqual(goal.analyticsValue, goal.rawValue)
        }
    }

    // 2 — rawValue'lar stabil (analytics segmentasyonu ve AppStorage bunlara dayanır).
    func testOnboardingGoalRawValuesStable() {
        XCTAssertEqual(OnboardingGoal.maintenance.rawValue, "maintenance")
        XCTAssertEqual(OnboardingGoal.importantDates.rawValue, "importantDates")
        XCTAssertEqual(OnboardingGoal.expenses.rawValue, "expenses")
        XCTAssertEqual(OnboardingGoal.documents.rawValue, "documents")
    }

    // 3 — Geçersiz rawValue nil döner (eski/bozuk AppStorage değeri çökertmez).
    func testOnboardingGoalInvalidRawValue() {
        XCTAssertNil(OnboardingGoal(rawValue: ""))
        XCTAssertNil(OnboardingGoal(rawValue: "community"))
    }

    // MARK: - ReminderType.mapsToServiceRecord

    // 4 — Fiziksel bakım tipleri true; tarih/yasal tipler false.
    func testMapsToServiceRecordClassification() {
        let maintenance: [ReminderType] = [
            .periodicService, .oilChange, .tire, .battery, .brakes, .timingBelt,
            .chainMaintenance, .chainSprocketSet, .sparkPlug, .airFilter,
            .clutchCable, .suspensionCheck, .seasonStartCheck, .winterPrep,
        ]
        for type in maintenance {
            XCTAssertTrue(type.mapsToServiceRecord, "\(type) bir bakım kaydına dönüşebilmeli")
        }

        let nonMaintenance: [ReminderType] = [
            .inspection, .trafficInsurance, .casco, .mtvFirst, .mtvSecond,
            .warranty, .hgs, .custom,
        ]
        for type in nonMaintenance {
            XCTAssertFalse(type.mapsToServiceRecord, "\(type) bakım kaydına dönüşmemeli")
        }
    }

    // 5 — Her ReminderType case'i sınıflandırılmış (exhaustive; yeni case eklenirse
    //     iki listeden birine girmeli, aksi halde bu test toplamı yakalar).
    func testMapsToServiceRecordCoversAllCases() {
        let trueCount = ReminderType.allCases.filter { $0.mapsToServiceRecord }.count
        let falseCount = ReminderType.allCases.filter { !$0.mapsToServiceRecord }.count
        XCTAssertEqual(trueCount + falseCount, ReminderType.allCases.count)
        XCTAssertEqual(trueCount, 14)
        XCTAssertEqual(falseCount, 8)
    }

    // MARK: - VehicleWizardDraft validation

    // 6 — Step 1 gating: plaka ≥6 + marka + model gerekir.
    @MainActor
    func testWizardIdentifyGating() {
        let draft = VehicleWizardDraft()
        XCTAssertFalse(draft.canProceedFromIdentify(), "boş draft ilerlememeli")

        draft.brand = "Toyota"
        draft.model = "Corolla"
        draft.plate = "34 AB"   // 5 karakter (boşluk hariç < 6)
        XCTAssertFalse(draft.canProceedFromIdentify(), "kısa plaka ilerlememeli")

        draft.plate = "34 ABC 12"
        XCTAssertTrue(draft.canProceedFromIdentify())

        draft.brand = "  "
        XCTAssertFalse(draft.canProceedFromIdentify(), "boş marka ilerlememeli")
    }

    // 7 — Step 2 gating: negatif km engellenir, aksi halde serbest.
    @MainActor
    func testWizardStatusGating() {
        let draft = VehicleWizardDraft()
        XCTAssertTrue(draft.canProceedFromStatus(), "km girilmemişse serbest")

        draft.odometerText = "50000"
        XCTAssertTrue(draft.canProceedFromStatus())

        draft.odometerText = "-5"
        XCTAssertFalse(draft.canProceedFromStatus(), "negatif km engellenmeli")
    }

    // 8 — validateForSave: eksik zorunlu alanları ve geçersiz yılı yakalar; tam
    //     geçerli draft'ta hata yok.
    @MainActor
    func testWizardValidateForSave() {
        let empty = VehicleWizardDraft()
        XCTAssertFalse(empty.validateForSave().isEmpty, "boş draft hata üretmeli")

        let valid = VehicleWizardDraft()
        valid.plate = "34 ABC 123"
        valid.brand = "Honda"
        valid.model = "Civic"
        valid.yearText = "2020"
        valid.odometerText = "80000"
        XCTAssertTrue(valid.validateForSave().isEmpty, "geçerli draft hatasız olmalı")

        let badYear = VehicleWizardDraft()
        badYear.plate = "34 ABC 123"
        badYear.brand = "Honda"
        badYear.model = "Civic"
        badYear.yearText = "1850"   // 1900 altı
        XCTAssertFalse(badYear.validateForSave().isEmpty, "geçersiz yıl hata üretmeli")
    }
}
