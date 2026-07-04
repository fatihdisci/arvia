import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - Maintenance Advisor Service Tests
// Kural eşleşmesi ve ciddiyet sıralaması.
final class MaintenanceAdvisorServiceTests: XCTestCase {

    private let advisor = MaintenanceAdvisorService()
    private let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 4))!

    private func input(
        fuel: FuelType = .gasoline,
        year: Int? = 2022,
        odometer: Int = 30_000,
        dailyKm: Double = 40,
        route: RouteType? = .mixed,
        band: DailyKmBand? = .from20to50
    ) -> MaintenanceAdvisorService.Input {
        MaintenanceAdvisorService.Input(
            fuelType: fuel, vehicleYear: year, currentOdometer: odometer,
            dailyKm: dailyKm, routeType: route, dailyKmBand: band, now: now
        )
    }

    private func matches(_ input: MaintenanceAdvisorService.Input, _ ruleId: String) -> Bool {
        advisor.suggestions(for: input).contains { $0.ruleId == ruleId }
    }

    // 1) Triger 100k — kişiselleştirilmiş ETA içerir.
    func testTimingBelt100kWithETA() {
        let sugg = advisor.topSuggestion(for: input(year: 2018, odometer: 95_000, dailyKm: 50, route: .mixed, band: .from50to100))
        XCTAssertEqual(sugg?.ruleId, "timingBelt100k")
        XCTAssertEqual(sugg?.severity, .important)
        XCTAssertEqual(sugg?.suggestedReminderType, .timingBelt)
        XCTAssertTrue(sugg?.message.contains("~3 ay") == true, "ETA metni bekleniyordu: \(sugg?.message ?? "")")
    }

    // 2) Çok yüksek günlük km.
    func testVeryHighDailyKm() {
        XCTAssertTrue(matches(input(odometer: 40_000, dailyKm: 120, route: .mixed, band: .over100), "veryHighDailyKm"))
    }

    // 3) Yüksek şehir içi → kısa yağ aralığı.
    func testHighCityOilInterval() {
        XCTAssertTrue(matches(input(odometer: 30_000, dailyKm: 60, route: .city, band: .from50to100), "highCityOilInterval"))
    }

    // 4) Otoyol → lastik aşınma.
    func testHighwayTireWear() {
        XCTAssertTrue(matches(input(route: .highway), "highwayTireWear"))
    }

    // 5) LPG → subap ayarı.
    func testLPGValveClearance() {
        XCTAssertTrue(matches(input(fuel: .lpg), "lpgValveClearance"))
    }

    // 6) Dizel + şehir → DPF.
    func testDieselCityDPF() {
        XCTAssertTrue(matches(input(fuel: .diesel, dailyKm: 40, route: .city), "dieselCityDPF"))
    }

    // 7) Elektrikli → batarya.
    func testElectricBatterySeasonal() {
        XCTAssertTrue(matches(input(fuel: .electric), "electricBatterySeasonal"))
    }

    // 8) Hibrit → sistem kontrol.
    func testHybridSystemCheck() {
        XCTAssertTrue(matches(input(fuel: .hybrid), "hybridSystemCheck"))
    }

    // 9) Düşük km + yaşlı araç → yağ yaşlanması.
    func testLowKmOilAging() {
        XCTAssertTrue(matches(input(year: 2018, odometer: 40_000, dailyKm: 12, route: .mixed, band: .under20), "lowKmOilAging"))
    }

    // 10) Benzin + yüksek km → buji.
    func testGasolineSparkPlug() {
        XCTAssertTrue(matches(input(fuel: .gasoline, odometer: 80_000), "gasolineSparkPlug"))
    }

    // Ciddiyet sıralaması: important > info.
    func testTopSuggestionPrefersHigherSeverity() {
        // Triger (important) + benzin buji (info) aynı anda eşleşir.
        let sugg = advisor.topSuggestion(for: input(fuel: .gasoline, year: 2017, odometer: 95_000, dailyKm: 50, route: .mixed, band: .from50to100))
        XCTAssertEqual(sugg?.severity, .important)
        XCTAssertEqual(sugg?.ruleId, "timingBelt100k")
    }

    // Hiç eşleşme yoksa nil (nötr profil, yeni araç, düşük km).
    func testNoMatchReturnsNil() {
        let sugg = advisor.topSuggestion(for: input(fuel: .gasoline, year: 2025, odometer: 5_000, dailyKm: 40, route: .mixed, band: .from20to50))
        XCTAssertNil(sugg)
    }

    // ETA yardımcı fonksiyonu.
    func testMonthsETA() {
        XCTAssertEqual(MaintenanceAdvisorService.monthsETA(remainingKm: 5_000, dailyKm: 50), 3)
        XCTAssertNil(MaintenanceAdvisorService.monthsETA(remainingKm: 0, dailyKm: 50))
        XCTAssertNil(MaintenanceAdvisorService.monthsETA(remainingKm: 5_000, dailyKm: 0))
    }
}
