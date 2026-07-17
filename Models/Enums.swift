import Foundation

// MARK: - Vehicle Type
enum VehicleType: String, Codable, CaseIterable {
    case car = "Otomobil"
    case motorcycle = "Motosiklet"

    var displayName: String { rawValue }

    /// VehicleDetail / Garage hero için SF Symbol.
    var heroSymbol: String {
        switch self {
        case .car: return "car.fill"
        case .motorcycle: return "gauge.with.needle" // Motosiklet için hız göstergesi — SF Symbol'de motosiklet simgesi yok
        }
    }

    /// Kullanıcıya gösterilen genel ad (örn: "araç" / "motosiklet").
    var vehicleNoun: String {
        switch self {
        case .car: return "araç"
        case .motorcycle: return "motosiklet"
        }
    }

    /// "Araç fotoğrafı" / "Motosiklet fotoğrafı" gibi metinler için.
    func localizedNoun(display: String) -> String {
        switch self {
        case .car: return display
        case .motorcycle: return display.replacingOccurrences(of: "Araç", with: "Motosiklet")
        }
    }
}

// MARK: - Motorcycle Type
enum MotorcycleType: String, Codable, CaseIterable {
    case scooter = "Scooter"
    case naked = "Naked"
    case touring = "Touring"
    case enduro = "Enduro"
    case cruiser = "Cruiser"
    case sport = "Sport"
    case commuter = "Commuter"
    case other = "Diğer"

    var displayName: String { rawValue }
}

// MARK: - Fuel Type
enum FuelType: String, Codable, CaseIterable {
    case gasoline = "Benzin"
    case diesel = "Dizel"
    case lpg = "LPG"
    case hybrid = "Hibrit"
    case electric = "Elektrik"

    var displayName: String { rawValue }
}

// MARK: - Transmission Type
enum TransmissionType: String, Codable, CaseIterable {
    case manual = "Manuel"
    case automatic = "Otomatik"
    case semiAutomatic = "Yarı Otomatik"

    var displayName: String { rawValue }
}

// MARK: - Vehicle Usage Type
enum VehicleUsageType: String, Codable, CaseIterable {
    case personal = "Bireysel"
    case company = "Şirket"
    case commercial = "Ticari"

    var displayName: String { rawValue }
}

// MARK: - Reminder Type
enum ReminderType: String, Codable, CaseIterable {
    // Ortak
    case inspection = "Muayene"
    case trafficInsurance = "Trafik Sigortası"
    case casco = "Kasko"
    case mtvFirst = "MTV 1. Taksit"
    case mtvSecond = "MTV 2. Taksit"
    case periodicService = "Periyodik Bakım"
    case oilChange = "Yağ Değişimi"
    case tire = "Lastik"
    case battery = "Akü"
    case brakes = "Fren"
    case warranty = "Garanti"
    // Otomobil özel
    case timingBelt = "Triger"
    case hgs = "HGS"
    // Motosiklet özel
    case chainMaintenance = "Zincir Bakımı"
    case chainSprocketSet = "Zincir/Dişli Seti"
    case sparkPlug = "Buji"
    case airFilter = "Hava Filtresi"
    case clutchCable = "Debriyaj Teli"
    case suspensionCheck = "Amortisör/Keçe Kontrolü"
    case seasonStartCheck = "Sezon Başlangıç Kontrolü"
    case winterPrep = "Kışlama Hazırlığı"
    // Genel
    case custom = "Diğer"

    var displayName: String { rawValue }

    var defaultIcon: String {
        switch self {
        case .inspection: return "checkmark.seal"
        case .trafficInsurance, .casco: return "shield"
        case .mtvFirst, .mtvSecond: return "doc.text"
        case .periodicService, .oilChange: return "wrench.and.screwdriver"
        case .tire: return "circle.hexagonpath"
        case .battery: return "battery.75"
        case .timingBelt: return "gear"
        case .brakes: return "circle.dotted.circle"
        case .warranty: return "checkmark.shield"
        case .hgs: return "road.lanes"
        case .chainMaintenance, .chainSprocketSet: return "circle.dotted.circle"
        case .sparkPlug: return "flame"
        case .airFilter: return "wind"
        case .clutchCable: return "circle.hexagonpath"
        case .suspensionCheck: return "circle.bottomhalf.filled"
        case .seasonStartCheck: return "sun.max"
        case .winterPrep: return "snowflake"
        case .custom: return "bell"
        }
    }

    /// Belirtilen vehicleType için uygun şablonları döndürür.
    /// Otomobil: Triger, HGS gösterilir; motosiklet özel şablonlar gizlenir.
    /// Motosiklet: Zincir, Buji, Hava filtresi vb. gösterilir; Triger, HGS gizlenir.
    static func templates(for vehicleType: VehicleType?) -> [ReminderType] {
        let all = allCases.filter { $0 != .custom }
        guard let vt = vehicleType else { return all }
        switch vt {
        case .car:
            return all.filter { !motorcycleOnlyTypes.contains($0) }
        case .motorcycle:
            return all.filter { !carOnlyTypes.contains($0) }
        }
    }

    /// Sadece otomobile özgü şablonlar
    static let carOnlyTypes: Set<ReminderType> = [.timingBelt, .hgs]

    /// Sadece motosiklete özgü şablonlar
    static let motorcycleOnlyTypes: Set<ReminderType> = [
        .chainMaintenance, .chainSprocketSet, .sparkPlug, .airFilter,
        .clutchCable, .suspensionCheck, .seasonStartCheck, .winterPrep
    ]
}

// MARK: - Reminder Priority
enum ReminderPriority: String, Codable, CaseIterable {
    case info = "Bilgi"
    case warning = "Önemli"
    case critical = "Kritik"

    var displayName: String { rawValue }
}

// MARK: - Reminder Status
enum ReminderStatus: String, Codable, CaseIterable {
    case active = "Aktif"
    case completed = "Tamamlandı"
    case overdue = "Gecikmiş"
    case archived = "Arşivlendi"

    var displayName: String { rawValue }

    /// overdue hesaplaması Reminder modelindeki computed property ile yapılır,
    /// bu enum yalnızca manuel olarak set edilen statü durumları içindir.
    static func calculateStatus(dueDate: Date?, isCompleted: Bool) -> ReminderStatus {
        if isCompleted { return .completed }
        guard let dueDate else { return .active }
        if dueDate < Date() { return .overdue }
        return .active
    }
}

// MARK: - Expense Category
enum ExpenseCategory: String, Codable, CaseIterable {
    // Ortak
    case service = "Bakım"
    case oil = "Yağ"
    case tire = "Lastik"
    case brake = "Fren"
    case battery = "Akü"
    case insurance = "Sigorta"
    case casco = "Kasko"
    case tax = "MTV"
    case inspection = "Muayene"
    case fuel = "Yakıt"
    case repair = "Tamir"
    case part = "Parça"
    case accessory = "Aksesuar"
    // Otomobil özel
    case emission = "Egzoz Emisyon"
    case parking = "Otopark"
    case toll = "HGS/OGS"
    case fine = "Ceza"
    case wash = "Yıkama"
    // Motosiklet özel
    case chainSprocket = "Zincir/Dişli"
    case equipment = "Ekipman"
    // Genel
    case other = "Diğer"

    var displayName: String { rawValue }

    var defaultIcon: String {
        switch self {
        case .fuel: return "fuelpump"
        case .service, .repair: return "wrench.and.screwdriver"
        case .part: return "gearshape"
        case .oil: return "oilcan"
        case .tire: return "circle.hexagonpath"
        case .battery: return "battery.75"
        case .insurance: return "shield"
        case .casco: return "shield.checkered"
        case .tax: return "doc.text"
        case .inspection: return "checkmark.seal"
        case .emission: return "leaf"
        case .parking: return "parkingsign"
        case .toll: return "road.lanes"
        case .fine: return "exclamationmark.triangle"
        case .wash: return "drop"
        case .accessory: return "sparkles"
        case .brake: return "circle.dotted.circle"
        case .chainSprocket: return "circle.dotted.circle"
        case .equipment: return "jacket"
        case .other: return "ellipsis.rectangle"
        }
    }

    /// Belirtilen vehicleType için uygun kategorileri döndürür.
    static func categories(for vehicleType: VehicleType?) -> [ExpenseCategory] {
        let all = allCases.filter { $0 != .other }
        guard let vt = vehicleType else { return all }
        switch vt {
        case .car:
            return all.filter { !motorcycleOnlyCategories.contains($0) }
        case .motorcycle:
            return all.filter { !carOnlyCategories.contains($0) }
        }
    }

    /// Sadece otomobile özgü kategoriler
    static let carOnlyCategories: Set<ExpenseCategory> = [.emission, .parking, .toll, .fine, .wash]

    /// Sadece motosiklete özgü kategoriler
    static let motorcycleOnlyCategories: Set<ExpenseCategory> = [.chainSprocket, .equipment]
}

// MARK: - Document Type
enum DocumentType: String, Codable, CaseIterable {
    case registration = "Ruhsat"
    case insurancePolicy = "Trafik Sigortası"
    case cascoPolicy = "Kasko"
    case inspectionReport = "Muayene Raporu"
    case emissionReport = "Egzoz Emisyon"
    case expertReport = "Ekspertiz Raporu"
    case serviceInvoice = "Servis Faturası"
    case partInvoice = "Parça Faturası"
    case warrantyDocument = "Garanti Belgesi"
    case repairDocument = "Hasar/Onarım"
    case vehiclePhoto = "Araç Fotoğrafı"
    // Motosiklet özel
    case equipmentInvoice = "Ekipman Faturası"
    case helmetGearWarranty = "Kask/Ekipman Garanti Belgesi"
    case accessoryMounting = "Aksesuar/Montaj Belgesi"
    // Genel
    case other = "Diğer"

    var displayName: String { rawValue }

    var defaultIcon: String {
        switch self {
        case .registration: return "doc.text"
        case .insurancePolicy: return "shield"
        case .cascoPolicy: return "shield.checkered"
        case .inspectionReport: return "checkmark.seal"
        case .emissionReport: return "leaf"
        case .expertReport: return "magnifyingglass"
        case .serviceInvoice, .partInvoice: return "doc.plaintext"
        case .warrantyDocument: return "checkmark.shield"
        case .repairDocument: return "wrench.and.screwdriver"
        case .vehiclePhoto: return "photo"
        case .equipmentInvoice: return "bag"
        case .helmetGearWarranty: return "checkmark.shield"
        case .accessoryMounting: return "gearshape"
        case .other: return "folder"
        }
    }

    /// Belirtilen vehicleType için uygun belge türlerini döndürür.
    static func availableTypes(for vehicleType: VehicleType?) -> [DocumentType] {
        let all = allCases.filter { $0 != .other }
        guard let vt = vehicleType else { return all }
        let mcTypes: Set<DocumentType> = [.equipmentInvoice, .helmetGearWarranty, .accessoryMounting]
        switch vt {
        case .car:
            return all.filter { !mcTypes.contains($0) }
        case .motorcycle:
            return all
        }
    }

    /// Belge bitiş tarihinden otomatik üretilecek hatırlatıcı şablonu.
    var expiryReminderType: ReminderType {
        switch self {
        case .insurancePolicy: return .trafficInsurance
        case .cascoPolicy: return .casco
        case .inspectionReport: return .inspection
        case .warrantyDocument, .helmetGearWarranty: return .warranty
        default: return .custom
        }
    }

    var expiryReminderTitle: String {
        switch self {
        case .inspectionReport: return "Muayene süresi"
        case .insurancePolicy: return "Trafik sigortası yenileme"
        case .cascoPolicy: return "Kasko yenileme"
        case .warrantyDocument, .helmetGearWarranty: return "Garanti bitişi"
        default: return "\(displayName) bitişi"
        }
    }
}

// MARK: - Service Type
enum ServiceType: String, Codable, CaseIterable {
    case periodic = "Periyodik Bakım"
    case oil = "Yağ Değişimi"
    case tire = "Lastik"
    case battery = "Akü"
    case brake = "Fren"
    case engine = "Motor"
    case transmission = "Şanzıman"
    case body = "Kaporta"
    case electric = "Elektrik"
    case airConditioning = "Klima"
    case custom = "Diğer"

    var displayName: String { rawValue }
}

// MARK: - Verification Status
enum VerificationStatus: String, Codable, CaseIterable {
    case manual = "Manuel"
    case pending = "Doğrulama Bekliyor"
    case verified = "Doğrulandı"
    case rejected = "Doğrulanamadı"

    var displayName: String { rawValue }
}

// MARK: - Sale File Section
enum SaleFileSection: String, Codable, CaseIterable {
    case summary = "Araç Özeti"
    case serviceHistory = "Bakım Geçmişi"
    case expenses = "Masraf Özeti"
    case inspectionReports = "Ekspertiz Raporu"
    case documents = "Belgeler"
    case photos = "Araç Fotoğrafları"
    case notes = "Notlar"
    case disclaimer = "Hukuki Uyarı"

    var displayName: String { rawValue }
}

// MARK: - Part Type
enum PartType: String, Codable, CaseIterable {
    case oil = "Motor Yağı"
    case oilFilter = "Yağ Filtresi"
    case airFilter = "Hava Filtresi"
    case pollenFilter = "Polen Filtresi"
    case fuelFilter = "Yakıt Filtresi"
    case sparkPlug = "Buji"
    case brakePad = "Fren Balatası"
    case brakeDisc = "Fren Diski"
    case timingBelt = "Triger Kayışı"
    case vBelt = "V Kayışı"
    case battery = "Akü"
    case tire = "Lastik"
    case shockAbsorber = "Amortisör"
    case clutch = "Debriyaj"
    case exhaust = "Egzoz"
    case windshield = "Ön Cam"
    case custom = "Diğer"

    var displayName: String { rawValue }
}
