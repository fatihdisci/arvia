import Foundation
import SwiftData

// MARK: - Vehicle Model
@Model
final class Vehicle {
    // NOT: CloudKit (NSPersistentCloudKitContainer) tüm zorunlu alanların ya optional
    // ya da bir varsayılan değere sahip olmasını ister. Bu yüzden tüm non-optional
    // alanlara property seviyesinde default verildi. init imzaları değişmedi; mevcut
    // veri korunur (default eklemek lightweight/migrationsız bir değişikliktir).
    var id: UUID = UUID()
    var nickname: String = ""
    var plate: String = ""
    var brand: String = ""
    var model: String = ""
    var year: Int?
    var vehicleTypeRaw: String = VehicleType.car.rawValue
    var bodyType: String?
    var motorcycleTypeRaw: String?
    var engineCC: Int?
    var fuelTypeRaw: String = FuelType.gasoline.rawValue
    var transmissionTypeRaw: String?
    var currentOdometer: Int = 0
    /// Mevcut km değeri Akıllı Asistan tahmini mi (kullanıcı "Doğru, kaydet" dedi). Additive.
    var odometerIsEstimate: Bool = false
    /// currentOdometer'ın en son güncellendiği tarih (tahmin/staleness hesabı için). Additive.
    var lastOdometerUpdate: Date?
    var purchaseDate: Date?
    var purchaseOdometer: Int?
    var purchasePrice: Double?
    var usageTypeRaw: String = VehicleUsageType.personal.rawValue
    var notes: String = ""
    var photoFileName: String?
    var createdAt: Date = Date()
    var archivedAt: Date?

    // MARK: Computed — Enum dönüşümleri
    var vehicleType: VehicleType {
        get { VehicleType(rawValue: vehicleTypeRaw) ?? .car }
        set { vehicleTypeRaw = newValue.rawValue }
    }

    var motorcycleType: MotorcycleType? {
        get {
            guard let raw = motorcycleTypeRaw else { return nil }
            return MotorcycleType(rawValue: raw)
        }
        set { motorcycleTypeRaw = newValue?.rawValue }
    }

    var fuelType: FuelType {
        get { FuelType(rawValue: fuelTypeRaw) ?? .gasoline }
        set { fuelTypeRaw = newValue.rawValue }
    }

    var transmissionType: TransmissionType? {
        get {
            guard let raw = transmissionTypeRaw else { return nil }
            return TransmissionType(rawValue: raw)
        }
        set { transmissionTypeRaw = newValue?.rawValue }
    }

    var usageType: VehicleUsageType {
        get { VehicleUsageType(rawValue: usageTypeRaw) ?? .personal }
        set { usageTypeRaw = newValue.rawValue }
    }

    // MARK: Formatting helpers
    var yearDisplay: String {
        year.map { String($0) } ?? "—"
    }

    var odometerDisplay: String {
        // Tahmini okumalar "~" ile gösterilir (Akıllı Asistan).
        "\(odometerIsEstimate ? "~" : "")\(currentOdometer.formatted()) km"
    }

    var fullName: String {
        [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var purchasePriceDisplay: String? {
        purchasePrice.map { "₺\(String(format: "%.0f", $0))" }
    }

    init(
        id: UUID = UUID(),
        nickname: String = "",
        plate: String = "",
        brand: String = "",
        model: String = "",
        year: Int? = nil,
        vehicleType: VehicleType = .car,
        bodyType: String? = nil,
        motorcycleType: MotorcycleType? = nil,
        engineCC: Int? = nil,
        fuelType: FuelType = .gasoline,
        transmissionType: TransmissionType? = nil,
        currentOdometer: Int = 0,
        purchaseDate: Date? = nil,
        purchaseOdometer: Int? = nil,
        purchasePrice: Double? = nil,
        usageType: VehicleUsageType = .personal,
        notes: String = "",
        photoFileName: String? = nil,
        createdAt: Date = Date(),
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.plate = plate
        self.brand = brand
        self.model = model
        self.year = year
        self.vehicleTypeRaw = vehicleType.rawValue
        self.bodyType = bodyType
        self.motorcycleTypeRaw = motorcycleType?.rawValue
        self.engineCC = engineCC
        self.fuelTypeRaw = fuelType.rawValue
        self.transmissionTypeRaw = transmissionType?.rawValue
        self.currentOdometer = currentOdometer
        self.purchaseDate = purchaseDate
        self.purchaseOdometer = purchaseOdometer
        self.purchasePrice = purchasePrice
        self.usageTypeRaw = usageType.rawValue
        self.notes = notes
        self.photoFileName = photoFileName
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }
}
