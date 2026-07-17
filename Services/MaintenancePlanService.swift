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
                tripTypes: input.tripTypes
                    .map { clipped($0, limit: 80) }
                    .filter { !$0.isEmpty }
                    .sorted()
                    .prefix(8)
                    .map { $0 }
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
        let contractVersion = 2
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

// MARK: - Maintenance Plan Payload Factory
// Asistan ana ekranı ve diğer giriş noktaları aynı araç verisini aynı sırada
// üretir. Deterministik sıralama cache parmak izinin gereksiz değişmesini önler.
enum MaintenancePlanPayloadFactory {
    static func build(
        vehicle: Vehicle,
        usageProfiles: [VehicleUsageProfile],
        serviceRecords: [ServiceRecord],
        reminders: [Reminder],
        inspectionReports: [InspectionReport],
        expenses: [Expense],
        now: Date = Date()
    ) -> String {
        let profile = UsageProfileService.resolve(for: vehicle.id, from: usageProfiles)

        let recentServices = serviceRecords
            .filter { $0.vehicleId == vehicle.id }
            .sorted {
                $0.date == $1.date
                    ? $0.id.uuidString < $1.id.uuidString
                    : $0.date > $1.date
            }
            .prefix(10)
            .map {
                MaintenancePlanPayloadBuilder.ServiceLine(
                    title: $0.serviceType.displayName,
                    date: $0.date,
                    km: $0.odometer,
                    oilType: $0.oilType,
                    notes: $0.notes,
                    nextDueDate: $0.nextReminderDueDate,
                    nextDueOdometer: $0.nextReminderDueOdometer
                )
            }

        let activeReminders = reminders
            .filter {
                $0.vehicleId == vehicle.id &&
                $0.statusRaw != ReminderStatus.completed.rawValue &&
                $0.statusRaw != ReminderStatus.archived.rawValue
            }
            .sorted {
                let leftKey = reminderSortKey($0, vehicleOdometer: vehicle.currentOdometer, now: now)
                let rightKey = reminderSortKey($1, vehicleOdometer: vehicle.currentOdometer, now: now)
                if leftKey != rightKey { return leftKey < rightKey }
                let leftDate = $0.dueDate ?? .distantFuture
                let rightDate = $1.dueDate ?? .distantFuture
                if leftDate != rightDate { return leftDate < rightDate }
                let leftKm = $0.dueOdometer ?? .max
                let rightKm = $1.dueOdometer ?? .max
                return leftKm == rightKm
                    ? $0.id.uuidString < $1.id.uuidString
                    : leftKm < rightKm
            }
            .prefix(8)
            .map {
                MaintenancePlanPayloadBuilder.ReminderLine(
                    title: $0.title,
                    type: $0.type.rawValue,
                    dueDate: $0.dueDate,
                    dueOdometer: $0.dueOdometer,
                    priority: $0.priority.rawValue,
                    state: reminderState($0, vehicleOdometer: vehicle.currentOdometer, now: now),
                    notes: $0.notes
                )
            }

        let recentInspections = inspectionReports
            .filter { $0.vehicleId == vehicle.id }
            .sorted {
                $0.reportDate == $1.reportDate
                    ? $0.id.uuidString < $1.id.uuidString
                    : $0.reportDate > $1.reportDate
            }
            .prefix(3)
            .map {
                MaintenancePlanPayloadBuilder.InspectionLine(
                    date: $0.reportDate,
                    km: $0.odometer,
                    summary: $0.summary,
                    verificationStatus: $0.verificationStatus.rawValue
                )
            }

        let maintenanceCategories: Set<ExpenseCategory> = [
            .service, .oil, .tire, .brake, .battery, .repair, .part,
            .inspection, .emission, .chainSprocket
        ]
        let expenseCutoff = Calendar.current.date(byAdding: .year, value: -2, to: now) ?? .distantPast
        let maintenanceExpenses = expenses
            .filter {
                $0.vehicleId == vehicle.id &&
                $0.date >= expenseCutoff &&
                $0.linkedServiceRecordId == nil &&
                maintenanceCategories.contains($0.category)
            }
            .sorted {
                $0.date == $1.date
                    ? $0.id.uuidString < $1.id.uuidString
                    : $0.date > $1.date
            }
            .prefix(8)
            .map {
                MaintenancePlanPayloadBuilder.MaintenanceExpenseLine(
                    category: $0.category.rawValue,
                    date: $0.date,
                    km: $0.odometer,
                    note: $0.note
                )
            }

        return MaintenancePlanPayloadBuilder.build(
            .init(
                brand: vehicle.brand,
                model: vehicle.model,
                year: vehicle.year,
                vehicleType: vehicle.vehicleType.rawValue,
                bodyType: vehicle.bodyType,
                engineCC: vehicle.engineCC,
                fuelType: vehicle.fuelType.rawValue,
                transmissionType: vehicle.transmissionType?.rawValue,
                usageType: vehicle.usageType.rawValue,
                odometer: vehicle.currentOdometer,
                odometerIsEstimate: vehicle.odometerIsEstimate,
                odometerUpdatedAt: vehicle.lastOdometerUpdate,
                dailyKmBand: profile?.dailyKmBand.rawValue,
                routeType: profile?.routeType.rawValue,
                fuelConsumptionCity: profile?.fuelConsumptionCity,
                fuelConsumptionHighway: profile?.fuelConsumptionHighway,
                tripTypes: profile?.tripTypes ?? [],
                recentServices: Array(recentServices),
                activeReminders: Array(activeReminders),
                recentInspections: Array(recentInspections),
                recentMaintenanceExpenses: Array(maintenanceExpenses)
            )
        )
    }

    private static func reminderState(_ reminder: Reminder, vehicleOdometer: Int, now: Date) -> String {
        let dateOverdue = reminder.dueDate.map { $0 < now } ?? false
        let kmOverdue = reminder.dueOdometer.map { vehicleOdometer >= $0 } ?? false
        if dateOverdue || kmOverdue { return "overdue" }

        let upcomingDate = reminder.dueDate.map {
            let days = Calendar.current.dateComponents([.day], from: now, to: $0).day ?? .max
            return days >= 0 && days <= 30
        } ?? false
        let upcomingKm = reminder.dueOdometer.map {
            let remaining = $0 - vehicleOdometer
            return remaining > 0 && remaining <= 2_000
        } ?? false
        return upcomingDate || upcomingKm ? "upcoming" : "active"
    }

    private static func reminderSortKey(_ reminder: Reminder, vehicleOdometer: Int, now: Date) -> Int {
        switch reminderState(reminder, vehicleOdometer: vehicleOdometer, now: now) {
        case "overdue": return 0
        case "upcoming": return 1
        default: return 2
        }
    }
}

// MARK: - Maintenance Plan Cache (file-based, input-hash identity)
enum MaintenancePlanCacheStore {
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

    /// Sonuçlar geçici Caches altında tutulmaz; sistem bu klasörü silebilir ve aynı
    /// girdinin yeniden AI'a gidip farklı sonuç üretmesine neden olabilir. Application
    /// Support, kullanıcı verisi değişene kadar plan kimliğini kalıcı tutar.
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Arvia", isDirectory: true)
            .appendingPathComponent("MaintenancePlans", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static var legacyDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MaintenancePlans", isDirectory: true)
    }

    private static func fileURL(for vehicleId: UUID, in directory: URL = directory) -> URL {
        directory.appendingPathComponent("plan_\(vehicleId.uuidString).json")
    }

    static func load(vehicleId: UUID) -> Cached? {
        let url = fileURL(for: vehicleId)
        if let data = try? Data(contentsOf: url),
           let cached = try? JSONDecoder().decode(Cached.self, from: data) {
            return cached
        }

        // 1.1 geliştirme öncesindeki geçici cache'i tek seferde kalıcı alana taşı.
        let legacyURL = fileURL(for: vehicleId, in: legacyDirectory)
        guard let data = try? Data(contentsOf: legacyURL),
              let cached = try? JSONDecoder().decode(Cached.self, from: data) else {
            return nil
        }
        do {
            try data.write(to: url, options: .atomic)
            try? FileManager.default.removeItem(at: legacyURL)
        } catch {
            // Taşıma başarısız olsa bile okunabilen mevcut planı bu oturumda kullan.
        }
        return cached
    }

    static func save(_ suggestions: [MaintenancePlanSuggestion], vehicleId: UUID, inputHash: String? = nil, now: Date = Date()) {
        let cached = Cached(suggestions: suggestions, createdAt: now, inputHash: inputHash)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: fileURL(for: vehicleId), options: .atomic)
    }

    /// Tarihten bağımsız tek yeniden-üretim kuralı: yalnızca payload parmak izi
    /// değiştiyse AI çağrılabilir. Aynı hash her zaman aynı kayıtlı planı döndürür.
    static func canReuse(_ cached: Cached, inputHash: String) -> Bool {
        cached.inputHash == inputHash
    }

    static func clear(vehicleId: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: vehicleId))
        try? FileManager.default.removeItem(at: fileURL(for: vehicleId, in: legacyDirectory))
    }

    /// Tüm araçların maintenance plan cache dosyalarını disk'ten siler.
    /// "Tüm Verileri Sil" / "Hesabı Sil" akışlarında çağrılır — yoksa
    /// SwiftData'daki araçlar silindikten sonra bile cache dosyaları
    /// orphan olarak kalır ve yeni eklenen araçlar eski planla karışabilir.
    static func deleteAll() {
        let fm = FileManager.default
        for targetDirectory in [directory, legacyDirectory] {
            guard let entries = try? fm.contentsOfDirectory(
                at: targetDirectory,
                includingPropertiesForKeys: nil
            ) else { continue }
            for url in entries where url.lastPathComponent.hasPrefix("plan_") && url.pathExtension == "json" {
                try? fm.removeItem(at: url)
            }
        }
    }
}
