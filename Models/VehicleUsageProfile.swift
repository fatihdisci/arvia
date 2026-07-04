import Foundation
import SwiftData

// MARK: - Vehicle Usage Profile (Akıllı Sürüş Asistanı — Layer A)
// Kullanıcının sürüş alışkanlıkları. Tahmin motoru (Layer B) ve kişiselleştirilmiş
// bakım önerileri bu profili kullanır. Tamamen yerel, rule-based. Additive migration.
@Model
final class VehicleUsageProfile {
    // CloudKit uyumu için tüm non-optional alanlara property seviyesinde default verildi.
    var id: UUID = UUID()
    var vehicleId: UUID = UUID()
    var dailyKmBandRaw: String = DailyKmBand.from20to50.rawValue
    var routeTypeRaw: String = RouteType.mixed.rawValue
    var fuelConsumptionCity: Double?
    var fuelConsumptionHighway: Double?
    var primaryUser: String?
    var tripTypes: [String] = []
    /// true ise bu profil tüm araçlar için geçerlidir (araç bazlı profil yoksa devreye girer).
    var appliesToAllVehicles: Bool = false
    var updatedAt: Date = Date()

    // MARK: - Computed enum köprüleri
    var dailyKmBand: DailyKmBand {
        get { DailyKmBand(rawValue: dailyKmBandRaw) ?? .from20to50 }
        set { dailyKmBandRaw = newValue.rawValue }
    }

    var routeType: RouteType {
        get { RouteType(rawValue: routeTypeRaw) ?? .mixed }
        set { routeTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        dailyKmBand: DailyKmBand = .from20to50,
        routeType: RouteType = .mixed,
        fuelConsumptionCity: Double? = nil,
        fuelConsumptionHighway: Double? = nil,
        primaryUser: String? = nil,
        tripTypes: [String] = [],
        appliesToAllVehicles: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.dailyKmBandRaw = dailyKmBand.rawValue
        self.routeTypeRaw = routeType.rawValue
        self.fuelConsumptionCity = fuelConsumptionCity
        self.fuelConsumptionHighway = fuelConsumptionHighway
        self.primaryUser = primaryUser
        self.tripTypes = tripTypes
        self.appliesToAllVehicles = appliesToAllVehicles
        self.updatedAt = updatedAt
    }
}

// MARK: - Daily KM Band
enum DailyKmBand: String, Codable, CaseIterable, Identifiable {
    case under20
    case from20to50
    case from50to100
    case over100

    var id: String { rawValue }

    /// Tahmin motoru için günlük km orta noktası.
    var midpointKm: Int {
        switch self {
        case .under20: return 10
        case .from20to50: return 35
        case .from50to100: return 75
        case .over100: return 120
        }
    }

    var displayName: String {
        switch self {
        case .under20: return "Günde 20 km'den az"
        case .from20to50: return "Günde 20–50 km"
        case .from50to100: return "Günde 50–100 km"
        case .over100: return "Günde 100 km'den fazla"
        }
    }

    var shortLabel: String {
        switch self {
        case .under20: return "<20"
        case .from20to50: return "20–50"
        case .from50to100: return "50–100"
        case .over100: return "100+"
        }
    }
}

// MARK: - Route Type
enum RouteType: String, Codable, CaseIterable, Identifiable {
    case city
    case highway
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .city: return "Çoğunlukla şehir içi"
        case .highway: return "Çoğunlukla şehir dışı / otoyol"
        case .mixed: return "Karışık"
        }
    }

    var shortLabel: String {
        switch self {
        case .city: return "Şehir"
        case .highway: return "Otoyol"
        case .mixed: return "Karışık"
        }
    }
}
