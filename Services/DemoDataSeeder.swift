import SwiftUI
import SwiftData
import UIKit

// MARK: - Demo Data Seeder
// Sadece DEBUG build'de derlenir. Release/TestFlight build'de görünmez.
// İdempotent: aynı demo verilerini tekrar tekrar çoğaltmaz.
// Mevcut kullanıcı verilerini silmez.

#if DEBUG
enum DemoDataSeeder {
    /// Demo araçların nickname'leri üzerinden daha önce seed edilip edilmediğini kontrol eder.
    private static let demoNicknames: Set<String> = ["Aile Aracı", "Şehir İçi", "Şirket Aracı"]

    /// Daha önce demo verisi eklenmiş mi?
    static func isAlreadySeeded(context: ModelContext) -> Bool {
        guard let vehicles = try? context.fetch(FetchDescriptor<Vehicle>()) else { return false }
        let existingNicknames = Set(vehicles.map { $0.nickname })
        return demoNicknames.isSubset(of: existingNicknames)
    }

    /// Tüm demo verilerini oluşturur. İdempotent.
    /// - Parameter context: SwiftData ModelContext
    /// - Returns: Eklenen araç sayısı (zaten seed edilmişse 0)
    @discardableResult
    static func seed(context: ModelContext) -> Int {
        guard !isAlreadySeeded(context: context) else {
            return 0
        }

        let calendar = Calendar.current
        let now = Date()

        // MARK: - Araç 1: Aile Aracı (VW Golf)
        let vehicle1 = Vehicle(
            nickname: "Aile Aracı",
            plate: "35 RHT 035",
            brand: "Volkswagen",
            model: "Golf",
            year: 2018,
            fuelType: .diesel,
            transmissionType: .automatic,
            currentOdometer: 84200,
            purchaseDate: calendar.date(byAdding: .year, value: -4, to: now),
            purchaseOdometer: 0,
            purchasePrice: 195_000,
            usageType: .personal,
            notes: "Düzenli bakımlı, aile kullanımı."
        )
        context.insert(vehicle1)

        // MARK: - Araç 2: Şehir İçi (Toyota Corolla)
        let vehicle2 = Vehicle(
            nickname: "Şehir İçi",
            plate: "34 RSM 034",
            brand: "Toyota",
            model: "Corolla",
            year: 2021,
            fuelType: .hybrid,
            transmissionType: .automatic,
            currentOdometer: 46200,
            purchaseDate: calendar.date(byAdding: .year, value: -3, to: now),
            purchaseOdometer: 0,
            purchasePrice: 580_000,
            usageType: .personal,
            notes: ""
        )
        context.insert(vehicle2)

        // MARK: - Araç 3: Şirket Aracı (Ford Transit Courier)
        let vehicle3 = Vehicle(
            nickname: "Şirket Aracı",
            plate: "06 RSR 006",
            brand: "Ford",
            model: "Transit Courier",
            year: 2020,
            fuelType: .diesel,
            transmissionType: .manual,
            currentOdometer: 123500,
            purchaseDate: calendar.date(byAdding: .year, value: -5, to: now),
            purchaseOdometer: 15000,
            purchasePrice: 320_000,
            usageType: .company,
            notes: "Filo aracı, düzenli bakım kaydı tutuluyor."
        )
        context.insert(vehicle3)

        let allVehicles = [vehicle1, vehicle2, vehicle3]

        // MARK: - Hatırlatıcılar
        for vehicle in allVehicles {
            // Muayene: 25 gün sonra
            context.insert(Reminder(
                vehicleId: vehicle.id,
                type: .inspection,
                title: "Periyodik Muayene",
                dueDate: calendar.date(byAdding: .day, value: 25, to: now),
                priority: .warning
            ))

            // Trafik sigortası: 12 gün sonra
            context.insert(Reminder(
                vehicleId: vehicle.id,
                type: .trafficInsurance,
                title: "Trafik Sigortası Yenileme",
                dueDate: calendar.date(byAdding: .day, value: 12, to: now),
                priority: .critical
            ))

            // Kasko: 3 ay sonra
            context.insert(Reminder(
                vehicleId: vehicle.id,
                type: .casco,
                title: "Kasko Yenileme",
                dueDate: calendar.date(byAdding: .month, value: 3, to: now),
                priority: .warning
            ))

            // MTV 1. taksit
            var mtvComponents = calendar.dateComponents([.year], from: now)
            mtvComponents.month = 1
            mtvComponents.day = 15
            if let mtvDate = calendar.date(from: mtvComponents) {
                let nextMTV = mtvDate < now
                    ? calendar.date(byAdding: .year, value: 1, to: mtvDate)!
                    : mtvDate
                context.insert(Reminder(
                    vehicleId: vehicle.id,
                    type: .mtvFirst,
                    title: "MTV 1. Taksit",
                    dueDate: nextMTV,
                    priority: .info
                ))
            }

            // Periyodik bakım
            context.insert(Reminder(
                vehicleId: vehicle.id,
                type: .periodicService,
                title: "Periyodik Bakım",
                dueOdometer: vehicle.currentOdometer + 1500,
                priority: .info
            ))
        }

        // Gecikmiş hatırlatıcı (sadece araç 1 için)
        context.insert(Reminder(
            vehicleId: vehicle1.id,
            type: .oilChange,
            title: "Yağ Değişimi",
            dueDate: calendar.date(byAdding: .day, value: -10, to: now),
            priority: .critical,
            status: .active
        ))

        // Lastik değişimi (araç 2 için, Kasım ayında)
        var tireComponents = calendar.dateComponents([.year], from: now)
        tireComponents.month = 11
        tireComponents.day = 1
        if let tireDate = calendar.date(from: tireComponents) {
            context.insert(Reminder(
                vehicleId: vehicle2.id,
                type: .tire,
                title: "Kış Lastiği Takılması",
                dueDate: tireDate,
                priority: .warning
            ))
        }

        // MARK: - Masraf Kayıtları
        let expenseTemplates: [(category: ExpenseCategory, amounts: ClosedRange<Double>, vendors: [String], monthsAgo: ClosedRange<Int>)] = [
            (.fuel, 900...2500, ["Shell", "BP", "Petrol Ofisi", "Opet"], 0...11),
            (.service, 3500...9000, ["Yetkili Servis", "Bosch Car Service", "Özel Servis"], 1...11),
            (.insurance, 8000...18000, ["Allianz", "Aksigorta", "Anadolu Sigorta"], 2...11),
            (.casco, 12000...30000, ["Allianz", "Aksigorta"], 5...10),
            (.tax, 1500...8000, ["Gelir İdaresi"], 0...11),
            (.tire, 12000...25000, ["Lastik Dünyası", "Bridgestone", "Michelin"], 3...10),
            (.battery, 2500...5500, ["İnci Akü", "Mutlu Akü"], 4...9),
            (.parking, 50...300, ["İspark", "Otopark"], 0...11),
            (.toll, 100...800, ["HGS/OGS"], 0...11),
            (.wash, 100...350, ["Oto Yıkama"], 0...11),
            (.repair, 1500...8000, ["Özel Servis", "Sanayi"], 2...10),
            (.part, 500...4000, ["Parçacı", "Oto Yedek"], 3...9),
        ]

        for vehicle in allVehicles {
            // Her araç için 15-25 arası masraf
            let expenseCount = 18 + Int.random(in: 0...7)
            var expenseDates: Set<String> = []

            for _ in 0..<expenseCount {
                guard let template = expenseTemplates.randomElement() else { continue }

                let monthsAgo = Int.random(in: template.monthsAgo)
                guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { continue }
                // Aynı ayda aynı kategoriden en fazla 3 masraf
                let dateKey = "\(monthsAgo)-\(template.category.rawValue)"
                let count = expenseDates.filter { $0 == dateKey }.count
                if count >= 3 { continue }
                expenseDates.insert(dateKey)

                // Günü ay içinde rastgele dağıt
                let dayOffset = Int.random(in: 1...25)
                let expenseDate = calendar.date(byAdding: .day, value: -dayOffset, to: date) ?? date

                let amount = Double.random(in: Double(template.amounts.lowerBound)...Double(template.amounts.upperBound))
                let vendor = template.vendors.randomElement()

                context.insert(Expense(
                    vehicleId: vehicle.id,
                    category: template.category,
                    amount: amount,
                    date: expenseDate,
                    odometer: max(0, vehicle.currentOdometer - Int.random(in: 100...5000)),
                    vendorName: vendor,
                    note: ""
                ))
            }
        }

        // MARK: - Bakım Kayıtları
        let serviceTemplates: [(type: ServiceType, vendors: [String], monthsAgo: Int, laborRange: ClosedRange<Double>, partsRange: ClosedRange<Double>)] = [
            (.periodic, ["Yetkili Servis", "Bosch Car Service"], 2, 1500...3000, 2000...5000),
            (.oil, ["Özel Servis", "Yetkili Servis"], 1, 500...1000, 800...2000),
            (.brake, ["Fren Servisi", "Yetkili Servis"], 5, 1200...2500, 1500...4000),
            (.tire, ["Lastik Dünyası", "Bridgestone"], 8, 400...800, 8000...20000),
            (.battery, ["İnci Akü"], 10, 200...500, 2000...4500),
            (.airConditioning, ["Klima Servisi", "Yetkili Servis"], 6, 800...1800, 500...1500),
        ]

        let partTemplates: [(type: PartType, brands: [String])] = [
            (.oil, ["Castrol", "Shell", "Mobil"]),
            (.oilFilter, ["Bosch", "Mann", "Mahle"]),
            (.airFilter, ["Bosch", "Mann"]),
            (.pollenFilter, ["Bosch", "Mann"]),
            (.brakePad, ["Bosch", "TRW", "Textar"]),
            (.battery, ["İnci", "Mutlu", "Varta"]),
            (.tire, ["Bridgestone", "Michelin", "Goodyear", "Pirelli"]),
        ]

        // Her araç için farklı bakım kayıtları
        for vehicle in allVehicles {
            let serviceCount = 4 + Int.random(in: 0...3)
            let selectedTemplates = serviceTemplates.shuffled().prefix(serviceCount)

            for template in selectedTemplates {
                guard let serviceDate = calendar.date(byAdding: .month, value: -template.monthsAgo, to: now) else { continue }
                let dayOffset = Int.random(in: 1...20)
                let finalDate = calendar.date(byAdding: .day, value: -dayOffset, to: serviceDate) ?? serviceDate

                let laborCost = Double.random(in: template.laborRange)
                let partsCost = Double.random(in: template.partsRange)
                let totalCost = laborCost + partsCost

                let service = ServiceRecord(
                    vehicleId: vehicle.id,
                    serviceType: template.type,
                    date: finalDate,
                    odometer: max(0, vehicle.currentOdometer - Int.random(in: 1000...15000)),
                    vendorName: template.vendors.randomElement(),
                    laborCost: laborCost,
                    partsCost: partsCost,
                    totalCost: totalCost,
                    notes: ""
                )
                context.insert(service)

                // Değişen parçalar
                let partCount = 1 + Int.random(in: 0...2)
                let selectedParts = partTemplates.shuffled().prefix(partCount)
                for partTemplate in selectedParts {
                    context.insert(PartChange(
                        serviceRecordId: service.id,
                        partType: partTemplate.type,
                        brand: partTemplate.brands.randomElement(),
                        model: nil
                    ))
                }
            }
        }

        // MARK: - Belgeler (placeholder)
        let documentTemplates: [(type: DocumentType, title: String, includeInSale: Bool)] = [
            (.registration, "Ruhsat", true),
            (.insurancePolicy, "Trafik Sigortası Poliçesi", true),
            (.cascoPolicy, "Kasko Poliçesi", true),
            (.inspectionReport, "Muayene Raporu", false),
            (.expertReport, "Ekspertiz Raporu", true),
            (.serviceInvoice, "Servis Faturası", false),
            (.partInvoice, "Parça Faturası", false),
            (.vehiclePhoto, "Araç Fotoğrafı", false),
        ]

        for vehicle in allVehicles {
            for template in documentTemplates {
                let issueDate = calendar.date(byAdding: .month, value: -Int.random(in: 1...12), to: now)
                let expiryDate: Date? = {
                    switch template.type {
                    case .insurancePolicy, .cascoPolicy:
                        return calendar.date(byAdding: .year, value: 1, to: issueDate ?? now)
                    case .inspectionReport:
                        return calendar.date(byAdding: .year, value: 2, to: issueDate ?? now)
                    default: return nil
                    }
                }()

                let doc = VehicleDocument(
                    vehicleId: vehicle.id,
                    type: template.type,
                    title: template.title,
                    localFileName: "demo_\(vehicle.id.uuidString.prefix(6))_\(template.type.rawValue).txt",
                    originalFileName: "\(template.title).txt",
                    issueDate: issueDate,
                    expiryDate: expiryDate,
                    vendorName: template.type == .expertReport ? "Örnek Ekspertiz Merkezi" : nil,
                    includeInSaleFile: template.includeInSale
                )

                // Küçük placeholder text dosyası
                let placeholderText = "Bu bir demo \(template.title.lowercased()) belgesidir.\nAraç: \(vehicle.plate) — \(vehicle.fullName)\nOluşturulma: \(Date().formatted())"
                doc.fileData = placeholderText.data(using: .utf8)
                doc.fileSizeBytes = doc.fileData?.count

                context.insert(doc)
            }
        }

        // MARK: - Ekspertiz Raporu (araç 1)
        let inspectionDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        let inspection = InspectionReport(
            vehicleId: vehicle1.id,
            providerName: "Örnek Ekspertiz Merkezi",
            branchName: "İzmir Bornova",
            reportDate: inspectionDate,
            odometer: 79000,
            summary: "Kullanıcı tarafından eklenen örnek ekspertiz raporu. Rapor içeriği uygulama tarafından doğrulanmaz.",
            verificationStatus: .manual
        )
        context.insert(inspection)

        // MARK: - Ekspertiz Raporu (araç 2)
        let inspection2Date = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        let inspection2 = InspectionReport(
            vehicleId: vehicle2.id,
            providerName: "Oto Ekspertiz Merkezi",
            branchName: "İstanbul Kadıköy",
            reportDate: inspection2Date,
            odometer: 44000,
            summary: "Araç genel durumu iyi. Motor ve şanzıman sorunsuz. Kaportada lokal boya mevcut.",
            verificationStatus: .manual
        )
        context.insert(inspection2)

        // MARK: - Satış Dosyası (araç 1)
        let saleFile = SaleFile(
            vehicleId: vehicle1.id,
            title: "\(vehicle1.fullName) — Satış Dosyası",
            includedSections: [.summary, .serviceHistory, .expenses, .inspectionReports, .documents, .disclaimer],
            selectedDocumentIds: [],
            selectedInspectionReportIds: [inspection.id]
        )
        context.insert(saleFile)

        // MARK: - Save
        try? context.save()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        return 3
    }

    /// Tüm verileri siler. Sadece DEBUG.
    static func deleteAll(context: ModelContext) {
        if let sales = try? context.fetch(FetchDescriptor<SaleFile>()) {
            for s in sales { context.delete(s) }
        }
        if let inspections = try? context.fetch(FetchDescriptor<InspectionReport>()) {
            for i in inspections { context.delete(i) }
        }
        if let parts = try? context.fetch(FetchDescriptor<PartChange>()) {
            for p in parts { context.delete(p) }
        }
        if let services = try? context.fetch(FetchDescriptor<ServiceRecord>()) {
            for s in services { context.delete(s) }
        }
        if let expenses = try? context.fetch(FetchDescriptor<Expense>()) {
            for e in expenses { context.delete(e) }
        }
        if let reminders = try? context.fetch(FetchDescriptor<Reminder>()) {
            for r in reminders { context.delete(r) }
        }
        if let docs = try? context.fetch(FetchDescriptor<VehicleDocument>()) {
            for d in docs { context.delete(d) }
        }
        if let vehicles = try? context.fetch(FetchDescriptor<Vehicle>()) {
            for v in vehicles { context.delete(v) }
        }

        // Belgeleri diskten temizle
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VehicleDocuments")
        try? FileManager.default.removeItem(at: docDir)

        try? context.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}
#endif
