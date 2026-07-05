import Foundation
import CryptoKit

// MARK: - Maintenance Plan Payload Builder (pure, testable)
// Kompakt JSON payload'u üretir ve savunma amaçlı (defense-in-depth) tümünü
// PIIMaskingService'ten geçirir. Ağ yok — yalnızca string üretimi.
enum MaintenancePlanPayloadBuilder {
    struct ServiceLine: Equatable {
        let title: String
        let km: Int?
    }

    struct Input: Equatable {
        var brand: String
        var model: String
        var year: Int?
        var fuelType: String
        var odometer: Int
        var dailyKmBand: String?
        var routeType: String?
        var fuelConsumptionCity: Double?
        var fuelConsumptionHighway: Double?
        var primaryUser: String?
        var tripTypes: [String]
        var recentServices: [ServiceLine] // en fazla 5
    }

    /// Maskelenmiş, deterministik JSON string döndürür.
    static func build(_ input: Input) -> String {
        let payload = Payload(
            profile: .init(
                dailyKmBand: input.dailyKmBand,
                routeType: input.routeType,
                fuelConsumptionCity: input.fuelConsumptionCity,
                fuelConsumptionHighway: input.fuelConsumptionHighway,
                primaryUser: input.primaryUser,
                tripTypes: input.tripTypes
            ),
            vehicle: .init(
                brand: input.brand,
                model: input.model,
                year: input.year,
                fuelType: input.fuelType,
                odometer: input.odometer
            ),
            recentServices: input.recentServices.prefix(5).map { .init(title: $0.title, km: $0.km) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
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
            let primaryUser: String?
            let tripTypes: [String]
        }
        struct Vehicle: Encodable {
            let brand: String
            let model: String
            let year: Int?
            let fuelType: String
            let odometer: Int
        }
        struct Service: Encodable {
            let title: String
            let km: Int?
        }
        let profile: Profile
        let vehicle: Vehicle
        let recentServices: [Service]
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
}
