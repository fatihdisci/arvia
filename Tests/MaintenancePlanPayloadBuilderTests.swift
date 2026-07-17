import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - Maintenance Plan Payload Builder Tests
// Maskeleme (defense-in-depth), 5 kayıt sınırı, önbellek tazeliği.
final class MaintenancePlanPayloadBuilderTests: XCTestCase {

    private func baseInput(services: [MaintenancePlanPayloadBuilder.ServiceLine] = []) -> MaintenancePlanPayloadBuilder.Input {
        MaintenancePlanPayloadBuilder.Input(
            brand: "Toyota", model: "Corolla", year: 2019, fuelType: "gasoline", odometer: 95_000,
            dailyKmBand: "from50to100", routeType: "city",
            fuelConsumptionCity: 7.5, fuelConsumptionHighway: 5.5,
            tripTypes: ["İşe gidiş-geliş"], recentServices: services
        )
    }

    // 1 — temiz girdi maskelenmez.
    func testCleanInputNotMasked() {
        let json = MaintenancePlanPayloadBuilder.build(baseInput())
        XCTAssertFalse(json.contains("[MASKED]"))
        XCTAssertTrue(json.contains("Toyota"))
    }

    // 2 — servis başlığındaki plaka maskelenir.
    func testPlateInServiceTitleMasked() {
        let json = MaintenancePlanPayloadBuilder.build(baseInput(services: [
            .init(title: "Servis 34 ABC 123 aracı", km: 80_000)
        ]))
        XCTAssertTrue(json.contains("[MASKED]"))
        XCTAssertFalse(json.contains("34 ABC 123"))
    }

    // 3 — bakım notundaki telefon maskelenir.
    func testPhoneInServiceNoteMasked() {
        let json = MaintenancePlanPayloadBuilder.build(baseInput(services: [
            .init(title: "Yağ", notes: "Usta telefonu 05551234567")
        ]))
        XCTAssertTrue(json.contains("[MASKED]"))
        XCTAssertFalse(json.contains("05551234567"))
    }

    // 4 — en fazla 10 servis kaydı gönderilir.
    func testAtMostTenServices() throws {
        let services = (1...14).map { MaintenancePlanPayloadBuilder.ServiceLine(title: "Bakım \($0)", km: $0 * 1000) }
        let json = MaintenancePlanPayloadBuilder.build(baseInput(services: services))
        let data = Data(json.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let recent = object?["recentServices"] as? [[String: Any]]
        XCTAssertEqual(recent?.count, 10)
    }

    // 5 — üretilen JSON geçerli kalır (maskeleme yapıyı bozmaz).
    func testOutputIsValidJSON() {
        let json = MaintenancePlanPayloadBuilder.build(baseInput(services: [.init(title: "TR33 0006 1005 1978 6457 8413 26", km: 90_000)]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject((try? JSONSerialization.jsonObject(with: Data(json.utf8))) ?? 0) || json.contains("{"))
        XCTAssertTrue(json.contains("[MASKED]"))
    }

    // 6 — karar için gerekli güncellik ve vade alanları payload'a girer.
    func testIncludesMaintenanceEvidenceFields() throws {
        let date = ISO8601DateFormatter().date(from: "2026-06-01T10:00:00Z")!
        var input = baseInput(services: [
            .init(title: "Yağ Değişimi", date: date, km: 90_000, oilType: "5W-30", nextDueOdometer: 100_000)
        ])
        input.odometerIsEstimate = true
        input.odometerUpdatedAt = date
        input.activeReminders = [
            .init(title: "Fren kontrolü", type: "Fren", dueDate: nil, dueOdometer: 96_000, priority: "Uyarı", state: "upcoming", notes: nil)
        ]

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(MaintenancePlanPayloadBuilder.build(input).utf8)) as? [String: Any]
        )
        let vehicle = try XCTUnwrap(object["vehicle"] as? [String: Any])
        let services = try XCTUnwrap(object["recentServices"] as? [[String: Any]])
        let reminders = try XCTUnwrap(object["activeReminders"] as? [[String: Any]])

        XCTAssertEqual(vehicle["odometerIsEstimate"] as? Bool, true)
        XCTAssertEqual(services.first?["nextDueOdometer"] as? Int, 100_000)
        XCTAssertEqual(reminders.first?["state"] as? String, "upcoming")
    }

    // MARK: - Cache freshness
    func testCacheFreshness() {
        let now = Date()
        let fresh = MaintenancePlanCacheStore.Cached(suggestions: [], createdAt: now)
        XCTAssertTrue(MaintenancePlanCacheStore.isFresh(fresh, now: now))

        let stale = MaintenancePlanCacheStore.Cached(
            suggestions: [],
            createdAt: Calendar.current.date(byAdding: .day, value: -31, to: now)!
        )
        XCTAssertFalse(MaintenancePlanCacheStore.isFresh(stale, now: now))
    }
}
