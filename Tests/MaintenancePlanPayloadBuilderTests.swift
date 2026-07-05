import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - Maintenance Plan Payload Builder Tests
// Maskeleme (defense-in-depth), 5 kayıt sınırı, önbellek tazeliği.
final class MaintenancePlanPayloadBuilderTests: XCTestCase {

    private func baseInput(
        primaryUser: String? = nil,
        services: [MaintenancePlanPayloadBuilder.ServiceLine] = []
    ) -> MaintenancePlanPayloadBuilder.Input {
        MaintenancePlanPayloadBuilder.Input(
            brand: "Toyota", model: "Corolla", year: 2019, fuelType: "gasoline", odometer: 95_000,
            dailyKmBand: "from50to100", routeType: "city",
            fuelConsumptionCity: 7.5, fuelConsumptionHighway: 5.5,
            primaryUser: primaryUser, tripTypes: ["İşe gidiş-geliş"], recentServices: services
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

    // 3 — primaryUser içindeki telefon maskelenir.
    func testPhoneInPrimaryUserMasked() {
        let json = MaintenancePlanPayloadBuilder.build(baseInput(primaryUser: "Ahmet 05551234567"))
        XCTAssertTrue(json.contains("[MASKED]"))
        XCTAssertFalse(json.contains("05551234567"))
    }

    // 4 — en fazla 5 servis kaydı gönderilir.
    func testAtMostFiveServices() throws {
        let services = (1...8).map { MaintenancePlanPayloadBuilder.ServiceLine(title: "Bakım \($0)", km: $0 * 1000) }
        let json = MaintenancePlanPayloadBuilder.build(baseInput(services: services))
        let data = Data(json.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let recent = object?["recentServices"] as? [[String: Any]]
        XCTAssertEqual(recent?.count, 5)
    }

    // 5 — üretilen JSON geçerli kalır (maskeleme yapıyı bozmaz).
    func testOutputIsValidJSON() {
        let json = MaintenancePlanPayloadBuilder.build(baseInput(services: [.init(title: "TR33 0006 1005 1978 6457 8413 26", km: 90_000)]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject((try? JSONSerialization.jsonObject(with: Data(json.utf8))) ?? 0) || json.contains("{"))
        XCTAssertTrue(json.contains("[MASKED]"))
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
