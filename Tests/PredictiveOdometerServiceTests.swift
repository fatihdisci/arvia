import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - Predictive Odometer Service Tests
// Veri odaklı (yüksek güven) ve profil-yedek (düşük güven) yollar.
final class PredictiveOdometerServiceTests: XCTestCase {

    private let service = PredictiveOdometerService()
    private var cal: Calendar { Calendar(identifier: .gregorian) }
    private let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 4))!

    private func daysAgo(_ n: Int) -> Date {
        cal.date(byAdding: .day, value: -n, to: now)!
    }

    // 1) Veri odaklı: 50 gün arayla 2500 km → 50 km/gün, son okumadan 10 gün ekstrapolasyon.
    func testDataDrivenHighConfidence() {
        let readings = [
            PredictiveOdometerService.Reading(date: daysAgo(60), odometer: 10_000),
            PredictiveOdometerService.Reading(date: daysAgo(10), odometer: 12_500),
        ]
        let est = service.estimate(lastKnownOdometer: 12_500, lastKnownDate: daysAgo(10), readings: readings, profileBand: nil, now: now)
        XCTAssertNotNil(est)
        XCTAssertEqual(est?.confidence, .high)
        XCTAssertTrue(est?.isDataDriven == true)
        XCTAssertEqual(est?.dailyKmAverage ?? 0, 50, accuracy: 0.01)
        XCTAssertEqual(est?.daysSinceLastReading, 10)
        XCTAssertEqual(est?.estimatedOdometer, 13_000) // 12500 + 50*10
    }

    // 2) Profil-yedek: veri yok, 40 gün önce bilinen km, band 20–50 (orta 35).
    func testProfileFallbackLowConfidence() {
        let est = service.estimate(lastKnownOdometer: 20_000, lastKnownDate: daysAgo(40), readings: [], profileBand: .from20to50, now: now)
        XCTAssertEqual(est?.confidence, .low)
        XCTAssertFalse(est?.isDataDriven ?? true)
        XCTAssertEqual(est?.daysSinceLastReading, 40)
        XCTAssertEqual(est?.estimatedOdometer, 21_400) // 20000 + 35*40
    }

    // 3) Veri de profil de yoksa nil.
    func testNoDataNoProfileReturnsNil() {
        let est = service.estimate(lastKnownOdometer: 20_000, lastKnownDate: nil, readings: [], profileBand: nil, now: now)
        XCTAssertNil(est)
    }

    // 4) Pencere dışı okumalar veri odaklı hesaba girmez → yedek yola düşer.
    func testReadingsOutsideWindowFallBackToProfile() {
        let readings = [
            PredictiveOdometerService.Reading(date: daysAgo(200), odometer: 5_000),
            PredictiveOdometerService.Reading(date: daysAgo(120), odometer: 6_000),
            PredictiveOdometerService.Reading(date: daysAgo(20), odometer: 9_000),
        ]
        let est = service.estimate(lastKnownOdometer: 9_000, lastKnownDate: nil, readings: readings, profileBand: .from50to100, now: now)
        XCTAssertEqual(est?.confidence, .low)
        XCTAssertFalse(est?.isDataDriven ?? true)
        XCTAssertEqual(est?.daysSinceLastReading, 20)
        XCTAssertEqual(est?.estimatedOdometer, 10_500) // 9000 + 75*20
    }

    // 5) Aynı gün son okuma → günSince 0 → tahmin son okumaya eşit.
    func testDataDrivenZeroDaysSince() {
        let readings = [
            PredictiveOdometerService.Reading(date: daysAgo(30), odometer: 40_000),
            PredictiveOdometerService.Reading(date: now, odometer: 41_500),
        ]
        let est = service.estimate(lastKnownOdometer: 41_500, lastKnownDate: now, readings: readings, profileBand: nil, now: now)
        XCTAssertEqual(est?.confidence, .high)
        XCTAssertEqual(est?.daysSinceLastReading, 0)
        XCTAssertEqual(est?.estimatedOdometer, 41_500)
    }

    // 6) Tahmin asla son bilinen km'nin altına inmez.
    func testEstimateNeverBelowLastKnown() {
        let est = service.estimate(lastKnownOdometer: 50_000, lastKnownDate: daysAgo(5), readings: [], profileBand: .under20, now: now)
        XCTAssertGreaterThanOrEqual(est?.estimatedOdometer ?? 0, 50_000)
        XCTAssertEqual(est?.estimatedOdometer, 50_050) // 50000 + 10*5
    }

    // 7) Büyük 90+ gün boşluk → predictiveOdometer insight eşiğini (30 gün) aşar.
    func testStaleReadingExceedsThirtyDayThreshold() {
        let est = service.estimate(lastKnownOdometer: 30_000, lastKnownDate: daysAgo(45), readings: [], profileBand: .from20to50, now: now)
        XCTAssertNotNil(est)
        XCTAssertGreaterThan(est?.daysSinceLastReading ?? 0, 30)
    }
}
