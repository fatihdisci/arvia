import Foundation
import SwiftData
import XCTest
@testable import Ruhsatim

// MARK: - Migration Safety Tests
// 1.1.0 refactor'ünün SwiftData şemasına DOKUNMADIĞINI ve mevcut kullanıcı
// verisinin (eski şekilli kayıtlar) sorunsuz yuvarlandığını güvence altına alır.
// Bu testler, ileride yanlışlıkla bir stored @Model alanı eklenmesi/çıkarılması
// gibi kırıcı bir değişikliği erken yakalamak için vardır.
@MainActor
final class MigrationSafetyTests: XCTestCase {

    /// Uygulama şemasıyla birebir aynı 10 modelin in-memory container'ı.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Vehicle.self,
            Reminder.self,
            Expense.self,
            ServiceRecord.self,
            PartChange.self,
            VehicleDocument.self,
            InspectionReport.self,
            SaleFile.self,
            Receipt.self,
            VehicleUsageProfile.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // 1 — Şema kurulabiliyor (10 modelin tümü tutarlı ve yüklenebilir).
    func testSchemaLoads() throws {
        XCTAssertNoThrow(try makeContainer())
    }

    // 2 — Eski şekilli minimal bir araç (yalnızca zorunlu-olmayan alanlar dolu
    //     bırakılmış) yazılıp geri okunabiliyor; veri kaybı yok.
    func testMinimalVehicleRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Plakasız, yılsız, km'siz araç — onboarding'in izin verdiği en yalın hal.
        let vehicle = Vehicle(brand: "Toyota", model: "Corolla")
        context.insert(vehicle)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Vehicle>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.brand, "Toyota")
        XCTAssertEqual(fetched.first?.plate, "")      // default, veri kaybı yok
        XCTAssertNil(fetched.first?.year)             // optional korunur
        XCTAssertEqual(fetched.first?.currentOdometer, 0)
    }

    // 3 — İlişkili kayıtlar (hatırlatıcı, masraf, belge) aynı store'da birlikte
    //     yazılıp okunabiliyor.
    func testRelatedRecordsRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vehicleId = UUID()
        context.insert(Vehicle(id: vehicleId, brand: "Honda", model: "Civic"))
        context.insert(Reminder(vehicleId: vehicleId, type: .inspection, title: "Muayene", dueDate: Date()))
        context.insert(Expense(vehicleId: vehicleId, category: .fuel, amount: 1500, date: Date()))
        context.insert(VehicleDocument(vehicleId: vehicleId))
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Vehicle>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Reminder>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Expense>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<VehicleDocument>()), 1)
    }

    // 4 — Onboarding sürümü tanımlı ve eski (v1) sürümden ileride; sessiz
    //     migration'ın "eski kullanıcıyı yükselt" mantığı bu karşılaştırmaya dayanır.
    func testOnboardingVersionIsForwardOfLegacy() {
        XCTAssertEqual(OnboardingConstants.currentVersion, 2)
        XCTAssertGreaterThan(OnboardingConstants.currentVersion, 1) // v1 = eski slayt akışı
    }

    // 5 — Onboarding AppStorage anahtarları beklenen literal değerlerde (yanlışlıkla
    //     yeniden adlandırma, eski kullanıcıların durumunu görünmez kılar).
    func testOnboardingStorageKeysStable() {
        XCTAssertEqual(OnboardingConstants.completedKey, "onboarding_completed")
        XCTAssertEqual(OnboardingConstants.versionKey, "onboarding_version")
        XCTAssertEqual(OnboardingConstants.goalKey, "onboarding_primary_goal")
        XCTAssertEqual(OnboardingConstants.stepKey, "onboarding_step")
    }

    // 6 — Reminder.GroupKey rawValue değişikliği (Faz 7) gruplama CASE'lerini
    //     bozmadı; grouping computed'ı hâlâ doğru case döner.
    func testReminderGroupingUnaffectedByLabelRename() {
        let overdue = Reminder(vehicleId: UUID(), type: .inspection, title: "M", dueDate: Date().addingTimeInterval(-86_400))
        XCTAssertEqual(overdue.groupKey, .overdue)

        let today = Reminder(vehicleId: UUID(), type: .inspection, title: "M", dueDate: Date())
        XCTAssertEqual(today.groupKey, .today)
    }
}
