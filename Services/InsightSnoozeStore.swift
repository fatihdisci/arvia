import Foundation

// MARK: - Insight Snooze Store
// Arvia Rehber "Daha sonra" için kalıcı snooze state'i.
// UserDefaults tabanlı, hafif, ek bağımlılık gerektirmez.
//
// Faz 1.1 (Karar 4.2):
// - Eski `Entry`-tabanlı API (insightId bazlı) korunur — VehicleDetail mevcut çağrıları için.
// - Yeni type-tabanlı API (`snooze(insightType:forVehicle:days:)`) eklenir — VehicleInsightCard için.
//   Anahtar formatı: `com.arvia.snooze.{vehicleId}.{insightType}`.
// İki sistem aynı UserDefaults'ta yan yana yaşar; çakışma yok.
final class InsightSnoozeStore {
    /// Paylaşılan singleton — service ve view'lar için. Test'ler kendi
    /// UserDefaults'larıyla ayrı bir instance oluşturur.
    static let shared = InsightSnoozeStore()

    private let store: UserDefaults
    private let key = "arvia_insight_snoozes"
    private let typeKeyPrefix = "com.arvia.snooze."

    init(store: UserDefaults = .standard) {
        self.store = store
    }

    // MARK: - Entry (eski sistem — geriye uyumluluk)

    struct Entry: Codable, Equatable {
        let vehicleId: String
        let insightId: String
        let insightType: String
        let snoozedUntil: Date
        let dismissedAt: Date
    }

    // MARK: - Eski API — insightId bazlı (korunur)

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
        entries.removeAll { $0.vehicleId == entry.vehicleId && $0.insightId == entry.insightId }
        entries.append(entry)

        if let data = try? JSONEncoder().encode(entries) {
            store.set(data, forKey: key)
        }

        dismissAction?()
    }

    func removeExpired(now: Date = Date()) {
        let entries = allEntries().filter { $0.snoozedUntil > now }
        if let data = try? JSONEncoder().encode(entries) {
            store.set(data, forKey: key)
        }
    }

    func removeAll() {
        store.removeObject(forKey: key)
        for storedKey in store.dictionaryRepresentation().keys
        where storedKey.hasPrefix(typeKeyPrefix) || storedKey.hasPrefix("com.arvia.dismiss.") {
            store.removeObject(forKey: storedKey)
        }
    }

    func clearAll(forVehicle vehicleId: UUID) {
        let normalizedId = vehicleId.uuidString.lowercased()
        let entries = allEntries().filter { $0.vehicleId != normalizedId }
        if entries.isEmpty {
            store.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(entries) {
            store.set(data, forKey: key)
        }

        let typePrefix = "\(typeKeyPrefix)\(vehicleId.uuidString)."
        let dismissPrefix = "com.arvia.dismiss.\(vehicleId.uuidString)."
        for storedKey in store.dictionaryRepresentation().keys
        where storedKey.hasPrefix(typePrefix) || storedKey.hasPrefix(dismissPrefix) {
            store.removeObject(forKey: storedKey)
        }
    }

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

    // MARK: - Yeni API (Faz 1.1) — type bazlı, daha basit

    /// Belirli bir insight tipini belirli bir araç için N gün süreyle snooze eder.
    /// Anahtar formatı: `com.arvia.snooze.{vehicleId}.{insightType}`
    func snooze(insightType: VehicleInsightType, forVehicle vehicleId: UUID, days: Int) {
        guard days > 0 else { return }
        let expireDate = Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
        let key = makeTypeKey(insightType: insightType, vehicleId: vehicleId)
        store.set(expireDate.timeIntervalSince1970, forKey: key)
    }

    /// Belirli bir insight tipinin o araç için snooze'lı olup olmadığını döner.
    /// Süre dolmuşsa UserDefaults'tan kaldırır ve false döner.
    func isSnoozed(insightType: VehicleInsightType, forVehicle vehicleId: UUID) -> Bool {
        let key = makeTypeKey(insightType: insightType, vehicleId: vehicleId)
        guard let savedTime = store.object(forKey: key) as? Double else {
            return false
        }
        let expireDate = Date(timeIntervalSince1970: savedTime)
        if Date() > expireDate {
            store.removeObject(forKey: key)
            return false
        }
        return true
    }

    /// Belirli bir insight tipinin snooze'unu kaldırır.
    func clearSnooze(insightType: VehicleInsightType, forVehicle vehicleId: UUID) {
        let key = makeTypeKey(insightType: insightType, vehicleId: vehicleId)
        store.removeObject(forKey: key)
    }

    private func makeTypeKey(insightType: VehicleInsightType, vehicleId: UUID) -> String {
        "\(typeKeyPrefix)\(vehicleId.uuidString).\(insightType.rawValue)"
    }

    // MARK: - Dismiss (kalıcı, gün bazlı değil)

    /// Kalıcı dismiss — kullanıcı insight'ı X ile kapattığında çağrılır.
    /// Bu insight bir daha gösterilmez (manuel geri alma yok).
    func dismiss(insightType: VehicleInsightType, forVehicle vehicleId: UUID) {
        let key = "com.arvia.dismiss.\(vehicleId.uuidString).\(insightType.rawValue)"
        store.set(Date().timeIntervalSince1970, forKey: key)
    }

    func isDismissed(insightType: VehicleInsightType, forVehicle vehicleId: UUID) -> Bool {
        let key = "com.arvia.dismiss.\(vehicleId.uuidString).\(insightType.rawValue)"
        return store.object(forKey: key) != nil
    }

    func clearDismiss(insightType: VehicleInsightType, forVehicle vehicleId: UUID) {
        let key = "com.arvia.dismiss.\(vehicleId.uuidString).\(insightType.rawValue)"
        store.removeObject(forKey: key)
    }

    /// Tüm dismiss'leri temizle (debug / ayarlar)
    func clearAllDismisses(forVehicle vehicleId: UUID) {
        let prefix = "com.arvia.dismiss.\(vehicleId.uuidString)."
        for key in store.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            store.removeObject(forKey: key)
        }
    }

    // MARK: - Snooze Durations (days) — eski sistem

    static func snoozeDuration(for insight: VehicleInsight) -> Int {
        snoozeDuration(for: insight.type, priority: insight.priority)
    }

    static func snoozeDuration(for type: VehicleInsightType, priority: VehicleInsightPriority = .info) -> Int {
        switch type {
        case .overdueReminder:
            return 1
        case .upcomingReminder:
            return 1
        case .calendarPeriod:
            return 7
        case .odometerUpdate:
            return 7
        case .monthlyExpensePrompt:
            return 7
        case .missingDocument:
            return 14
        case .maintenance:
            return 14
        case .seasonalGuidance:
            return 14
        case .fuelTypeGuidance:
            return 30
        case .transmissionGuidance:
            return 30
        case .odometerMilestone:
            return 14
        case .quietGoodState:
            return 0
        case .saleFileReadiness:
            return 14
        case .predictiveOdometer:
            return 7
        case .predictiveMaintenance:
            return 7
        }
    }
}
