import Foundation
import CryptoKit

// MARK: - Maintenance Plan Payload Builder (pure, testable)
// Kompakt JSON payload'u üretir ve savunma amaçlı (defense-in-depth) tümünü
// PIIMaskingService'ten geçirir. Ağ yok — yalnızca string üretimi.
enum MaintenancePlanPayloadBuilder {
    struct ServiceLine: Equatable {
        let title: String
        let date: Date?
        let km: Int?
        let oilType: String?
        let notes: String?
        let nextDueDate: Date?
        let nextDueOdometer: Int?

        init(
            title: String,
            date: Date? = nil,
            km: Int? = nil,
            oilType: String? = nil,
            notes: String? = nil,
            nextDueDate: Date? = nil,
            nextDueOdometer: Int? = nil
        ) {
            self.title = title
            self.date = date
            self.km = km
            self.oilType = oilType
            self.notes = notes
            self.nextDueDate = nextDueDate
            self.nextDueOdometer = nextDueOdometer
        }
    }

    struct ReminderLine: Equatable {
        let title: String
        let type: String
        let dueDate: Date?
        let dueOdometer: Int?
        let priority: String
        let state: String
        let notes: String?
    }

    struct InspectionLine: Equatable {
        let date: Date
        let km: Int?
        let summary: String
        let verificationStatus: String
    }

    struct MaintenanceExpenseLine: Equatable {
        let category: String
        let date: Date
        let km: Int?
        let note: String?
    }

    struct Input: Equatable {
        var brand: String
        var model: String
        var year: Int?
        var vehicleType: String
        var bodyType: String?
        var engineCC: Int?
        var fuelType: String
        var transmissionType: String?
        var usageType: String
        var odometer: Int
        var odometerIsEstimate: Bool
        var odometerUpdatedAt: Date?
        var dailyKmBand: String?
        var routeType: String?
        var fuelConsumptionCity: Double?
        var fuelConsumptionHighway: Double?
        var tripTypes: [String]
        var recentServices: [ServiceLine]
        var activeReminders: [ReminderLine]
        var recentInspections: [InspectionLine]
        var recentMaintenanceExpenses: [MaintenanceExpenseLine]

        init(
            brand: String,
            model: String,
            year: Int?,
            vehicleType: String = "car",
            bodyType: String? = nil,
            engineCC: Int? = nil,
            fuelType: String,
            transmissionType: String? = nil,
            usageType: String = "personal",
            odometer: Int,
            odometerIsEstimate: Bool = false,
            odometerUpdatedAt: Date? = nil,
            dailyKmBand: String?,
            routeType: String?,
            fuelConsumptionCity: Double?,
            fuelConsumptionHighway: Double?,
            tripTypes: [String],
            recentServices: [ServiceLine],
            activeReminders: [ReminderLine] = [],
            recentInspections: [InspectionLine] = [],
            recentMaintenanceExpenses: [MaintenanceExpenseLine] = []
        ) {
            self.brand = brand
            self.model = model
            self.year = year
            self.vehicleType = vehicleType
            self.bodyType = bodyType
            self.engineCC = engineCC
            self.fuelType = fuelType
            self.transmissionType = transmissionType
            self.usageType = usageType
            self.odometer = odometer
            self.odometerIsEstimate = odometerIsEstimate
            self.odometerUpdatedAt = odometerUpdatedAt
            self.dailyKmBand = dailyKmBand
            self.routeType = routeType
            self.fuelConsumptionCity = fuelConsumptionCity
            self.fuelConsumptionHighway = fuelConsumptionHighway
            self.tripTypes = tripTypes
            self.recentServices = recentServices
            self.activeReminders = activeReminders
            self.recentInspections = recentInspections
            self.recentMaintenanceExpenses = recentMaintenanceExpenses
        }
    }

    /// Maskelenmiş, deterministik JSON string döndürür.
    static func build(_ input: Input) -> String {
        let payload = Payload(
            profile: .init(
                dailyKmBand: input.dailyKmBand,
                routeType: input.routeType,
                fuelConsumptionCity: input.fuelConsumptionCity,
                fuelConsumptionHighway: input.fuelConsumptionHighway,
                tripTypes: input.tripTypes.prefix(8).map { clipped($0, limit: 80) }
            ),
            vehicle: .init(
                brand: clipped(input.brand, limit: 80),
                model: clipped(input.model, limit: 80),
                year: input.year,
                vehicleType: input.vehicleType,
                bodyType: input.bodyType.map { clipped($0, limit: 60) },
                engineCC: input.engineCC,
                fuelType: input.fuelType,
                transmissionType: input.transmissionType,
                usageType: input.usageType,
                odometer: input.odometer,
                odometerIsEstimate: input.odometerIsEstimate,
                odometerUpdatedAt: input.odometerUpdatedAt
            ),
            recentServices: input.recentServices.prefix(10).map {
                .init(
                    title: clipped($0.title, limit: 100),
                    date: $0.date,
                    km: $0.km,
                    oilType: $0.oilType.map { clipped($0, limit: 80) },
                    notes: nonEmptyClipped($0.notes, limit: 240),
                    nextDueDate: $0.nextDueDate,
                    nextDueOdometer: $0.nextDueOdometer
                )
            },
            activeReminders: input.activeReminders.prefix(8).map {
                .init(
                    title: clipped($0.title, limit: 100),
                    type: $0.type,
                    dueDate: $0.dueDate,
                    dueOdometer: $0.dueOdometer,
                    priority: $0.priority,
                    state: $0.state,
                    notes: nonEmptyClipped($0.notes, limit: 180)
                )
            },
            recentInspections: input.recentInspections.prefix(3).map {
                .init(
                    date: $0.date,
                    km: $0.km,
                    summary: clipped($0.summary, limit: 400),
                    verificationStatus: $0.verificationStatus
                )
            },
            recentMaintenanceExpenses: input.recentMaintenanceExpenses.prefix(8).map {
                .init(
                    category: $0.category,
                    date: $0.date,
                    km: $0.km,
                    note: nonEmptyClipped($0.note, limit: 180)
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let json = (try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        // Savunma amaçlı maskeleme — JSON string değerleri içindeki olası PII gizlenir.
        return PIIMaskingService.mask(json)
    }

    private struct Payload: Encodable {
        struct Profile: Encodable {
            let dailyKmBand: String?
            let routeType: String?
            let fuelConsumptionCity: Double?
            let fuelConsumptionHighway: Double?
            let tripTypes: [String]
        }
        struct Vehicle: Encodable {
            let brand: String
            let model: String
            let year: Int?
            let vehicleType: String
            let bodyType: String?
            let engineCC: Int?
            let fuelType: String
            let transmissionType: String?
            let usageType: String
            let odometer: Int
            let odometerIsEstimate: Bool
            let odometerUpdatedAt: Date?
        }
        struct Service: Encodable {
            let title: String
            let date: Date?
            let km: Int?
            let oilType: String?
            let notes: String?
            let nextDueDate: Date?
            let nextDueOdometer: Int?
        }
        struct ActiveReminder: Encodable {
            let title: String
            let type: String
            let dueDate: Date?
            let dueOdometer: Int?
            let priority: String
            let state: String
            let notes: String?
        }
        struct Inspection: Encodable {
            let date: Date
            let km: Int?
            let summary: String
            let verificationStatus: String
        }
        struct MaintenanceExpense: Encodable {
            let category: String
            let date: Date
            let km: Int?
            let note: String?
        }
        let profile: Profile
        let vehicle: Vehicle
        let recentServices: [Service]
        let activeReminders: [ActiveReminder]
        let recentInspections: [Inspection]
        let recentMaintenanceExpenses: [MaintenanceExpense]
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    private static func nonEmptyClipped(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let clipped = clipped(value, limit: limit)
        return clipped.isEmpty ? nil : clipped
    }
}

// MARK: - Maintenance Plan Cache (file-based, 30-day freshness)
enum MaintenancePlanCacheStore {
    static let freshnessDays = 30

    struct Cached: Codable, Equatable {
        let suggestions: [MaintenancePlanSuggestion]
        let createdAt: Date
        /// Bu plan üretilirken AI'a gönderilen payload'un parmak izi.
        /// Araç verisi değişmediyse (parmak izi aynıysa) plan yeniden üretilmez —
        /// aynı veriyle AI'ın farklı sonuç verme ihtimaline karşı son cache kullanılır.
        var inputHash: String? = nil
    }

    /// Payload'un deterministik parmak izini üretir (SHA-256).
    static func fingerprint(_ payload: String) -> String {
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MaintenancePlans", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func fileURL(for vehicleId: UUID) -> URL {
        directory.appendingPathComponent("plan_\(vehicleId.uuidString).json")
    }

    static func load(vehicleId: UUID) -> Cached? {
        let url = fileURL(for: vehicleId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Cached.self, from: data)
    }

    static func save(_ suggestions: [MaintenancePlanSuggestion], vehicleId: UUID, inputHash: String? = nil, now: Date = Date()) {
        let cached = Cached(suggestions: suggestions, createdAt: now, inputHash: inputHash)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: fileURL(for: vehicleId))
    }

    static func isFresh(_ cached: Cached, now: Date = Date()) -> Bool {
        guard let expiry = Calendar.current.date(byAdding: .day, value: freshnessDays, to: cached.createdAt) else {
            return false
        }
        return now < expiry
    }

    static func clear(vehicleId: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: vehicleId))
    }

    /// Tüm araçların maintenance plan cache dosyalarını disk'ten siler.
    /// "Tüm Verileri Sil" / "Hesabı Sil" akışlarında çağrılır — yoksa
    /// SwiftData'daki araçlar silindikten sonra bile cache dosyaları
    /// orphan olarak kalır ve yeni eklenen araçlar eski planla karışabilir.
    static func deleteAll() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for url in entries where url.lastPathComponent.hasPrefix("plan_") && url.pathExtension == "json" {
            try? fm.removeItem(at: url)
        }
    }
}
