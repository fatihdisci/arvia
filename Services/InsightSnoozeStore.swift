import Foundation

// MARK: - Insight Snooze Store
// Arvia Rehber "Daha sonra" için kalıcı snooze state'i.
// UserDefaults tabanlı, hafif, ek bağımlılık gerektirmez.
struct InsightSnoozeStore {

    private let store: UserDefaults
    private let key = "arvia_insight_snoozes"

    init(store: UserDefaults = .standard) {
        self.store = store
    }

    // MARK: - Store Entry

    struct Entry: Codable, Equatable {
        let vehicleId: String
        let insightId: String
        let insightType: String
        let snoozedUntil: Date
        let dismissedAt: Date
    }

    // MARK: - Read

    func allEntries() -> [Entry] {
        guard let data = store.data(forKey: key) else { return [] }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    func snoozedInsightIDs(for vehicleId: UUID, now: Date = Date()) -> Set<String> {
        let now = now
        return Set(allEntries().compactMap { entry in
            guard entry.vehicleId == vehicleId.uuidString.lowercased(),
                  entry.snoozedUntil > now
            else { return nil }
            return entry.insightId
        })
    }

    func isSnoozed(vehicleId: UUID, insightId: String, now: Date = Date()) -> Bool {
        allEntries().contains { entry in
            entry.vehicleId == vehicleId.uuidString.lowercased() &&
            entry.insightId == insightId &&
            entry.snoozedUntil > now
        }
    }

    // MARK: - Write

    func snooze(vehicleId: UUID, insight: VehicleInsight, dismissAction: (() -> Void)? = nil) {
        let now = Date()
        let duration = InsightSnoozeStore.snoozeDuration(for: insight)
        let snoozedUntil = Calendar.current.date(byAdding: .day, value: duration, to: now) ?? now

        let entry = Entry(
            vehicleId: vehicleId.uuidString.lowercased(),
            insightId: insight.id,
            insightType: insight.type.rawValue,
            snoozedUntil: snoozedUntil,
            dismissedAt: now
        )

        var entries = allEntries()
        // Remove existing entry for same vehicle + insightId
        entries.removeAll { $0.vehicleId == entry.vehicleId && $0.insightId == entry.insightId }
        entries.append(entry)

        if let data = try? JSONEncoder().encode(entries) {
            store.set(data, forKey: key)
        }

        dismissAction?()
    }

    // MARK: - Cleanup

    func removeExpired(now: Date = Date()) {
        let entries = allEntries().filter { $0.snoozedUntil > now }
        if let data = try? JSONEncoder().encode(entries) {
            store.set(data, forKey: key)
        }
    }

    func removeAll() {
        store.removeObject(forKey: key)
    }

    // MARK: - Snooze Durations (days)

    static func snoozeDuration(for insight: VehicleInsight) -> Int {
        snoozeDuration(for: insight.type, priority: insight.priority)
    }

    static func snoozeDuration(for type: VehicleInsightType, priority: VehicleInsightPriority = .info) -> Int {
        switch type {
        // Critical / urgent
        case .overdueReminder:
            return 1
        // Near-term
        case .upcomingReminder:
            return 1
        case .calendarPeriod:
            return 7
        // Maintenance / records
        case .odometerUpdate:
            return 7
        case .monthlyExpensePrompt:
            return 7
        case .missingDocument:
            return 14
        case .maintenance:
            return 14
        // Contextual / low urgency
        case .seasonalGuidance:
            return 14
        case .fuelTypeGuidance:
            return 30
        case .transmissionGuidance:
            return 30
        case .odometerMilestone:
            return 14
        // Quiet state — does not snooze persistently
        case .quietGoodState:
            return 0
        case .saleFileReadiness:
            return 14
        }
    }

    // MARK: - Critical override
    // Overdue reminders should always reappear after 1 day regardless of insight ID.
    // If an overdueReminder or upcomingReminder exists for same vehicle, we clear old snoozes.

    func clearReminderSnoozes(for vehicleId: UUID, types: Set<VehicleInsightType>) {
        var entries = allEntries()
        let typeRaws = Set(types.map { $0.rawValue })
        entries.removeAll { entry in
            entry.vehicleId == vehicleId.uuidString.lowercased() &&
            typeRaws.contains(entry.insightType)
        }
        if let data = try? JSONEncoder().encode(entries) {
            store.set(data, forKey: key)
        }
    }
}
