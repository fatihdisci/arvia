import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - Usage Profile Service Tests
// Çözümleme (resolution) mantığı: araç bazlı > global > nil.
final class UsageProfileServiceTests: XCTestCase {

    private let vehicleA = UUID()
    private let vehicleB = UUID()

    private func profile(vehicle: UUID, all: Bool, band: DailyKmBand = .from20to50, updated: Date = Date()) -> VehicleUsageProfile {
        VehicleUsageProfile(vehicleId: vehicle, dailyKmBand: band, appliesToAllVehicles: all, updatedAt: updated)
    }

    // 1) Araç bazlı profil, global profile göre önceliklidir.
    func testVehicleSpecificWinsOverGlobal() {
        let specific = profile(vehicle: vehicleA, all: false, band: .over100)
        let global = profile(vehicle: UUID(), all: true, band: .under20)
        let resolved = UsageProfileService.resolve(for: vehicleA, from: [global, specific])
        XCTAssertEqual(resolved?.dailyKmBand, .over100)
        XCTAssertFalse(resolved?.appliesToAllVehicles ?? true)
    }

    // 2) Araç bazlı yoksa global devreye girer.
    func testGlobalFallback() {
        let global = profile(vehicle: UUID(), all: true, band: .from50to100)
        let resolved = UsageProfileService.resolve(for: vehicleA, from: [global])
        XCTAssertEqual(resolved?.dailyKmBand, .from50to100)
        XCTAssertTrue(resolved?.appliesToAllVehicles ?? false)
    }

    // 3) Ne araç bazlı ne global varsa nil.
    func testNilWhenNoMatch() {
        let otherSpecific = profile(vehicle: vehicleB, all: false)
        XCTAssertNil(UsageProfileService.resolve(for: vehicleA, from: [otherSpecific]))
    }

    // 4) Boş liste → nil.
    func testEmptyReturnsNil() {
        XCTAssertNil(UsageProfileService.resolve(for: vehicleA, from: []))
    }

    // 5) Birden çok global → en güncel updatedAt kazanır.
    func testMostRecentGlobalWins() {
        let older = profile(vehicle: UUID(), all: true, band: .under20, updated: Date(timeIntervalSince1970: 1_000))
        let newer = profile(vehicle: UUID(), all: true, band: .over100, updated: Date(timeIntervalSince1970: 2_000))
        let resolved = UsageProfileService.resolve(for: vehicleA, from: [older, newer])
        XCTAssertEqual(resolved?.dailyKmBand, .over100)
    }
}
