import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - InsightSnoozeStore Tests

final class InsightSnoozeStoreTests: XCTestCase {

    private var store: InsightSnoozeStore!
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "test.insight.snooze.\(UUID().uuidString)")
        store = InsightSnoozeStore(store: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        testDefaults = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Basic Snooze / Unsnooze

    func testSnoozedInsightIsHiddenBeforeSnoozedUntil() {
        let vehicleId = UUID()
        let insight = makeInsight(type: .overdueReminder, relatedReminderId: UUID())

        store.snooze(vehicleId: vehicleId, insight: insight)

        // Hemen sonra snoozed
        XCTAssertTrue(store.isSnoozed(vehicleId: vehicleId, insightId: insight.id))
        let snoozedIDs = store.snoozedInsightIDs(for: vehicleId)
        XCTAssertTrue(snoozedIDs.contains(insight.id))
    }

    func testSnoozedInsightReappearsAfterSnoozedUntil() {
        let vehicleId = UUID()
        let insight = makeInsight(type: .overdueReminder, relatedReminderId: UUID())

        // Snooze 1 day
        store.snooze(vehicleId: vehicleId, insight: insight)

        // 1 day + 1 second later - should be unsnoozed
        let future = Calendar.current.date(byAdding: .day, value: 1, to: Date())!.addingTimeInterval(1)
        XCTAssertFalse(store.isSnoozed(vehicleId: vehicleId, insightId: insight.id, now: future))
    }

    // MARK: - Different Vehicles

    func testDifferentVehiclesCanSnoozeIndependently() {
        let vehicleA = UUID()
        let vehicleB = UUID()
        let insightA = makeInsight(type: .monthlyExpensePrompt)
        let insightB = makeInsight(type: .monthlyExpensePrompt) // same type, different instance

        store.snooze(vehicleId: vehicleA, insight: insightA)
        store.snooze(vehicleId: vehicleB, insight: insightB)

        XCTAssertTrue(store.isSnoozed(vehicleId: vehicleA, insightId: insightA.id))
        XCTAssertTrue(store.isSnoozed(vehicleId: vehicleB, insightId: insightB.id))

        // Vehicle B snooze doesn't affect vehicle A's insight
        let aSnoozed = store.snoozedInsightIDs(for: vehicleA)
        XCTAssertTrue(aSnoozed.contains(insightA.id))
        XCTAssertFalse(aSnoozed.contains(insightB.id))
    }

    // MARK: - Snooze Durations

    func testOverdueReminderSnoozeDurationIs1Day() {
        let duration = InsightSnoozeStore.snoozeDuration(for: .overdueReminder)
        XCTAssertEqual(duration, 1)
    }

    func testUpcomingReminderSnoozeDurationIs1Day() {
        let duration = InsightSnoozeStore.snoozeDuration(for: .upcomingReminder)
        XCTAssertEqual(duration, 1)
    }

    func testFuelGuidanceSnoozeDurationIs30Days() {
        let duration = InsightSnoozeStore.snoozeDuration(for: .fuelTypeGuidance)
        XCTAssertEqual(duration, 30)
    }

    func testTransmissionGuidanceSnoozeDurationIs30Days() {
        let duration = InsightSnoozeStore.snoozeDuration(for: .transmissionGuidance)
        XCTAssertEqual(duration, 30)
    }

    func testOdometerUpdateSnoozeDurationIs7Days() {
        let duration = InsightSnoozeStore.snoozeDuration(for: .odometerUpdate)
        XCTAssertEqual(duration, 7)
    }

    func testMissingDocumentSnoozeDurationIs14Days() {
        let duration = InsightSnoozeStore.snoozeDuration(for: .missingDocument)
        XCTAssertEqual(duration, 14)
    }

    func testMaintenanceSnoozeDurationIs14Days() {
        let duration = InsightSnoozeStore.snoozeDuration(for: .maintenance)
        XCTAssertEqual(duration, 14)
    }

    func testSeasonalGuidanceSnoozeDurationIs14Days() {
        let duration = InsightSnoozeStore.snoozeDuration(for: .seasonalGuidance)
        XCTAssertEqual(duration, 14)
    }

    func testQuietGoodStateIsNotSnoozedPersistently() {
        let duration = InsightSnoozeStore.snoozeDuration(for: .quietGoodState)
        XCTAssertEqual(duration, 0)

        // Verify it doesn't store anything
        let vehicleId = UUID()
        let insight = makeInsight(type: .quietGoodState)

        store.snooze(vehicleId: vehicleId, insight: insight)
        // With 0 duration, snoozedUntil should be now or past
        let future = Calendar.current.date(byAdding: .second, value: 1, to: Date())!
        XCTAssertFalse(store.isSnoozed(vehicleId: vehicleId, insightId: insight.id, now: future))
    }

    // MARK: - Cleanup

    func testExpiredEntriesAreRemoved() {
        let vehicleId = UUID()
        let insight1 = makeInsight(type: .overdueReminder, relatedReminderId: UUID())
        let insight2 = makeInsight(type: .fuelTypeGuidance)

        store.snooze(vehicleId: vehicleId, insight: insight1) // 1 day
        store.snooze(vehicleId: vehicleId, insight: insight2) // 30 days

        // 2 days later, only fuel should still be snoozed
        let future = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        store.removeExpired(now: future)

        XCTAssertFalse(store.isSnoozed(vehicleId: vehicleId, insightId: insight1.id, now: future))
        XCTAssertTrue(store.isSnoozed(vehicleId: vehicleId, insightId: insight2.id, now: future))
    }

    func testRemoveAllClearsEverything() {
        let vehicleId = UUID()
        let insight = makeInsight(type: .overdueReminder, relatedReminderId: UUID())
        store.snooze(vehicleId: vehicleId, insight: insight)
        XCTAssertFalse(store.allEntries().isEmpty)

        store.removeAll()
        XCTAssertTrue(store.allEntries().isEmpty)
    }

    // MARK: - Critical Override

    func testCriticalOverridesClearReminderSnoozes() {
        let vehicleId = UUID()
        let r1 = UUID()
        let r2 = UUID()
        let insight1 = makeInsight(type: .overdueReminder, relatedReminderId: r1)
        let insight2 = makeInsight(type: .upcomingReminder, relatedReminderId: r2)
        let insight3 = makeInsight(type: .fuelTypeGuidance)

        store.snooze(vehicleId: vehicleId, insight: insight1)
        store.snooze(vehicleId: vehicleId, insight: insight2)
        store.snooze(vehicleId: vehicleId, insight: insight3)

        // Clear reminder snoozes
        store.clearReminderSnoozes(for: vehicleId, types: [.overdueReminder, .upcomingReminder])

        XCTAssertFalse(store.isSnoozed(vehicleId: vehicleId, insightId: insight1.id))
        XCTAssertFalse(store.isSnoozed(vehicleId: vehicleId, insightId: insight2.id))
        XCTAssertTrue(store.isSnoozed(vehicleId: vehicleId, insightId: insight3.id))
    }

    // MARK: - Helpers

    private func makeInsight(type: VehicleInsightType, relatedReminderId: UUID? = nil) -> VehicleInsight {
        VehicleInsight(
            type: type,
            priority: type == .overdueReminder ? .important : .warning,
            source: .ruleBased,
            title: "Test Insight",
            body: "Test body for \(type.rawValue)",
            action: .addReminder,
            relatedReminderId: relatedReminderId
        )
    }
}
