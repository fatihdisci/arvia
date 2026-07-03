import SwiftUI
import SwiftData
import UIKit

// MARK: - Demo Data Seeder
// Sadece DEBUG build'de derlenir. Release/TestFlight build'de görünmez.
// İdempotent: aynı demo verilerini tekrar tekrar çoğaltmaz.
// Mevcut kullanıcı verilerini silmez.
// 1 otomobil + 1 motosiklet, gerçekçi Türkiye verileri.

#if DEBUG
enum DemoDataSeeder {
    private static let demoNicknames: Set<String> = ["Aile Aracı", "Hafta Sonu Motoru"]

    /// Daha önce demo verisi eklenmiş mi?
    static func isAlreadySeeded(context: ModelContext) -> Bool {
        guard let vehicles = try? context.fetch(FetchDescriptor<Vehicle>()) else { return false }
        let existingNicknames = Set(vehicles.map { $0.nickname })
        return demoNicknames.isSubset(of: existingNicknames)
    }

    /// Demo verilerini oluşturur. İdempotent.
    @discardableResult
    static func seed(context: ModelContext) -> Int {
        guard !isAlreadySeeded(context: context) else {
            return 0
        }

        let calendar = Calendar.current
        let now = Date()

        // MARK: - Araç 1: Otomobil — Toyota Corolla 1.8 Hybrid
        let car = Vehicle(
            nickname: "Aile Aracı",
            plate: "34 RSM 034",
            brand: "Toyota",
            model: "Corolla",
            year: 2022,
            vehicleType: .car,
            fuelType: .hybrid,
            transmissionType: .automatic,
            currentOdometer: 46200,
            purchaseDate: calendar.date(byAdding: .year, value: -2, to: now),
            purchaseOdometer: 0,
            purchasePrice: 850_000,
            usageType: .personal,
            notes: "Sıfır alındı. Düzenli yetkili servis bakımlı. Şehir içi 4.5L/100km."
        )
        context.insert(car)

        // MARK: - Araç 2: Motosiklet — Yamaha MT-07
        let moto = Vehicle(
            nickname: "Hafta Sonu Motoru",
            plate: "35 MTC 007",
            brand: "Yamaha",
            model: "MT-07",
            year: 2024,
            vehicleType: .motorcycle,
            motorcycleType: .naked,
            engineCC: 689,
            fuelType: .gasoline,
            transmissionType: .manual,
            currentOdometer: 5200,
            purchaseDate: calendar.date(byAdding: .month, value: -8, to: now),
            purchaseOdometer: 0,
            purchasePrice: 420_000,
            usageType: .personal,
            notes: "Sıfır alındı. Garanti devam ediyor. İlk bakım 1000 km'de yapıldı."
        )
        context.insert(moto)

        let allVehicles = [car, moto]

        // MARK: - Hatırlatıcılar (her araç için)
        for vehicle in allVehicles {
            // Muayene
            context.insert(Reminder(
                vehicleId: vehicle.id,
                type: .inspection,
                title: "Periyodik Muayene",
                dueDate: calendar.date(byAdding: .day, value: vehicle.vehicleType == .motorcycle ? 180 : 90, to: now),
                priority: .warning
            ))

            // Trafik sigortası
            context.insert(Reminder(
                vehicleId: vehicle.id,
                type: .trafficInsurance,
                title: "Trafik Sigortası Yenileme",
                dueDate: calendar.date(byAdding: .day, value: 45, to: now),
                priority: .critical
            ))

            // MTV
            var mtvComponents = calendar.dateComponents([.year], from: now)
            mtvComponents.month = 1; mtvComponents.day = 15
            if let mtvDate = calendar.date(from: mtvComponents) {
                let next = mtvDate < now ? calendar.date(byAdding: .year, value: 1, to: mtvDate)! : mtvDate
                context.insert(Reminder(
                    vehicleId: vehicle.id, type: .mtvFirst,
                    title: "MTV 1. Taksit", dueDate: next, priority: .info
                ))
            }

            // Periyodik bakım (km bazlı)
            context.insert(Reminder(
                vehicleId: vehicle.id,
                type: .periodicService,
                title: "Periyodik Bakım",
                dueOdometer: vehicle.currentOdometer + (vehicle.vehicleType == .motorcycle ? 5000 : 10000),
                priority: .info
            ))
        }

        // Otomobil özel hatırlatıcılar
        context.insert(Reminder(
            vehicleId: car.id, type: .oilChange,
            title: "Yağ & Filtre Değişimi",
            dueOdometer: 50000, priority: .warning
        ))
        context.insert(Reminder(
            vehicleId: car.id, type: .timingBelt,
            title: "Triger Kayışı Kontrolü",
            dueOdometer: 90000, priority: .info
        ))

        // Motosiklet özel hatırlatıcılar
        context.insert(Reminder(
            vehicleId: moto.id, type: .chainMaintenance,
            title: "Zincir Temizlik & Gerdirme",
            dueOdometer: 6000, priority: .warning
        ))
        context.insert(Reminder(
            vehicleId: moto.id, type: .sparkPlug,
            title: "Buji Değişimi",
            dueOdometer: 12000, priority: .info
        ))

        // Gecikmiş hatırlatıcı (otomobil)
        context.insert(Reminder(
            vehicleId: car.id, type: .tire,
            title: "Lastik Rotasyonu",
            dueDate: calendar.date(byAdding: .day, value: -10, to: now),
            priority: .critical
        ))

        // MARK: - Masraf Kayıtları
        let carExpenses: [(ExpenseCategory, Double, String?, Int)] = [
            (.fuel, 1650, "Shell", 0), (.fuel, 1420, "BP", 1), (.fuel, 1880, "Opet", 2),
            (.fuel, 1340, "Shell", 3), (.fuel, 1560, "Petrol Ofisi", 4),
            (.fuel, 1720, "BP", 5), (.fuel, 1480, "Shell", 6),
            (.insurance, 8500, "Allianz", 2), (.tax, 4350, "Gelir İdaresi", 1),
            (.service, 6800, "Toyota Plaza", 3), (.parking, 180, "İspark", 0),
            (.toll, 350, "HGS", 0), (.wash, 200, nil, 5),
            (.tire, 18500, "Bridgestone", 4), (.part, 1200, "Oto Yedek", 3),
            (.repair, 4500, "Özel Servis", 6),
        ]
        for (cat, amount, vendor, monthsAgo) in carExpenses {
            guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { continue }
            context.insert(Expense(
                vehicleId: car.id, category: cat, amount: amount, date: date,
                odometer: max(0, car.currentOdometer - Int.random(in: 500...4000)),
                vendorName: vendor
            ))
        }

        let motoExpenses: [(ExpenseCategory, Double, String?, Int)] = [
            (.fuel, 280, "Shell", 0), (.fuel, 310, "BP", 1), (.fuel, 260, "Opet", 2),
            (.fuel, 290, "Shell", 3), (.fuel, 340, "BP", 4),
            (.insurance, 3200, "Allianz", 1), (.tax, 780, "Gelir İdaresi", 0),
            (.service, 2500, "Yamaha Yetkili Servis", 2),
            (.chainSprocket, 1800, "Motopark", 3),
            (.equipment, 4500, "Eldiven Dünyası", 4),
            (.accessory, 2200, "Revit Store", 2),
        ]
        for (cat, amount, vendor, monthsAgo) in motoExpenses {
            guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { continue }
            context.insert(Expense(
                vehicleId: moto.id, category: cat, amount: amount, date: date,
                odometer: max(0, moto.currentOdometer - Int.random(in: 100...1000)),
                vendorName: vendor
            ))
        }

        // MARK: - Bakım Kayıtları
        // Otomobil
        let carService1 = ServiceRecord(
            vehicleId: car.id, serviceType: .periodic, date: calendar.date(byAdding: .month, value: -15, to: now) ?? now,
            odometer: 30000, vendorName: "Toyota Plaza", laborCost: 1800, partsCost: 3200, totalCost: 5000
        )
        context.insert(carService1)
        context.insert(PartChange(serviceRecordId: carService1.id, partType: .oil, brand: "Castrol", model: "Edge 0W-20"))
        context.insert(PartChange(serviceRecordId: carService1.id, partType: .oilFilter, brand: "Toyota"))
        context.insert(PartChange(serviceRecordId: carService1.id, partType: .airFilter, brand: "Toyota"))

        let carService2 = ServiceRecord(
            vehicleId: car.id, serviceType: .periodic, date: calendar.date(byAdding: .month, value: -3, to: now) ?? now,
            odometer: 43000, vendorName: "Toyota Plaza", laborCost: 2200, partsCost: 4600, totalCost: 6800
        )
        context.insert(carService2)
        context.insert(PartChange(serviceRecordId: carService2.id, partType: .oil, brand: "Castrol", model: "Edge 0W-20"))
        context.insert(PartChange(serviceRecordId: carService2.id, partType: .oilFilter, brand: "Toyota"))
        context.insert(PartChange(serviceRecordId: carService2.id, partType: .pollenFilter, brand: "Bosch"))

        // Motosiklet
        let motoService1 = ServiceRecord(
            vehicleId: moto.id, serviceType: .oil, date: calendar.date(byAdding: .month, value: -6, to: now) ?? now,
            odometer: 1000, vendorName: "Yamaha Yetkili Servis", laborCost: 400, partsCost: 800, totalCost: 1200
        )
        context.insert(motoService1)
        context.insert(PartChange(serviceRecordId: motoService1.id, partType: .oil, brand: "Yamalube", model: "10W-40"))
        context.insert(PartChange(serviceRecordId: motoService1.id, partType: .oilFilter, brand: "Yamaha"))

        let motoService2 = ServiceRecord(
            vehicleId: moto.id, serviceType: .periodic, date: calendar.date(byAdding: .month, value: -2, to: now) ?? now,
            odometer: 4000, vendorName: "Yamaha Yetkili Servis", laborCost: 600, partsCost: 1900, totalCost: 2500
        )
        context.insert(motoService2)
        context.insert(PartChange(serviceRecordId: motoService2.id, partType: .oil, brand: "Yamalube", model: "10W-40"))
        context.insert(PartChange(serviceRecordId: motoService2.id, partType: .oilFilter, brand: "Yamaha"))

        // MARK: - Belgeler
        for vehicle in allVehicles {
            let doc = VehicleDocument(
                vehicleId: vehicle.id,
                type: .registration,
                title: "Ruhsat",
                localFileName: "demo_ruhsat_\(vehicle.nickname.prefix(4)).txt",
                originalFileName: "ruhsat.txt",
                issueDate: vehicle.purchaseDate,
                includeInSaleFile: true
            )
            doc.fileData = "Demo ruhsat belgesi — \(vehicle.fullName) (\(vehicle.plate))".data(using: .utf8)
            context.insert(doc)
        }

        // Otomobil özel belgeler
        let insuranceDoc1 = VehicleDocument(
            vehicleId: car.id, type: .insurancePolicy, title: "Trafik Sigortası",
            localFileName: "demo_sigorta_car.txt", originalFileName: "sigorta.pdf",
            issueDate: calendar.date(byAdding: .month, value: -10, to: now),
            expiryDate: calendar.date(byAdding: .month, value: 2, to: now),
            vendorName: "Allianz", includeInSaleFile: true
        )
        insuranceDoc1.fileData = "Demo trafik sigortası — Toyota Corolla".data(using: .utf8)
        context.insert(insuranceDoc1)

        let serviceInvDoc = VehicleDocument(
            vehicleId: car.id, type: .serviceInvoice, title: "Periyodik Bakım Faturası",
            localFileName: "demo_servis_car.txt", originalFileName: "fatura.pdf",
            issueDate: calendar.date(byAdding: .month, value: -3, to: now), includeInSaleFile: true
        )
        serviceInvDoc.fileData = "Demo servis faturası — 43.000 km periyodik bakım".data(using: .utf8)
        context.insert(serviceInvDoc)

        // Motosiklet özel belgeler
        let insDoc2 = VehicleDocument(
            vehicleId: moto.id, type: .insurancePolicy, title: "Trafik Sigortası",
            localFileName: "demo_sigorta_moto.txt", originalFileName: "sigorta.pdf",
            issueDate: calendar.date(byAdding: .month, value: -7, to: now),
            expiryDate: calendar.date(byAdding: .month, value: 5, to: now),
            vendorName: "Allianz", includeInSaleFile: true
        )
        insDoc2.fileData = "Demo trafik sigortası — Yamaha MT-07".data(using: .utf8)
        context.insert(insDoc2)

        let helmetDoc = VehicleDocument(
            vehicleId: moto.id, type: .helmetGearWarranty, title: "Kask Garanti Belgesi",
            localFileName: "demo_kask.txt", originalFileName: "garanti.pdf",
            issueDate: moto.purchaseDate, vendorName: "LS2 Helmets", includeInSaleFile: false
        )
        helmetDoc.fileData = "Demo kask garanti — LS2 FF-800".data(using: .utf8)
        context.insert(helmetDoc)

        // MARK: - Ekspertiz Raporu (otomobil)
        let inspection = InspectionReport(
            vehicleId: car.id, providerName: "Oto Ekspertiz Merkezi",
            branchName: "İstanbul Kadıköy",
            reportDate: calendar.date(byAdding: .month, value: -6, to: now) ?? now,
            odometer: 39000,
            summary: "Araç genel durumu iyi. Motor ve şanzıman sorunsuz. Kaportada lokal boya mevcut. Alt takım temiz.",
            verificationStatus: .manual
        )
        context.insert(inspection)

        // MARK: - Satış Dosyası (otomobil)
        context.insert(SaleFile(
            vehicleId: car.id,
            title: "\(car.fullName) — Satış Dosyası",
            includedSections: [.summary, .serviceHistory, .expenses, .inspectionReports, .documents, .disclaimer],
            selectedInspectionReportIds: [inspection.id]
        ))

        // MARK: - Save & haptic
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return 2
    }

    /// Tüm verileri siler.
    static func deleteAll(context: ModelContext) {
        if let sales = try? context.fetch(FetchDescriptor<SaleFile>()) { for s in sales { context.delete(s) } }
        if let inspections = try? context.fetch(FetchDescriptor<InspectionReport>()) { for i in inspections { context.delete(i) } }
        if let parts = try? context.fetch(FetchDescriptor<PartChange>()) { for p in parts { context.delete(p) } }
        if let services = try? context.fetch(FetchDescriptor<ServiceRecord>()) { for s in services { context.delete(s) } }
        if let expenses = try? context.fetch(FetchDescriptor<Expense>()) { for e in expenses { context.delete(e) } }
        if let reminders = try? context.fetch(FetchDescriptor<Reminder>()) { for r in reminders { context.delete(r) } }
        if let docs = try? context.fetch(FetchDescriptor<VehicleDocument>()) { for d in docs { context.delete(d) } }
        if let vehicles = try? context.fetch(FetchDescriptor<Vehicle>()) { for v in vehicles { context.delete(v) } }

        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VehicleDocuments")
        try? FileManager.default.removeItem(at: docDir)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // MARK: - Insight Scenarios (Karar 3.4)
    // Developer Settings'ten seçilebilen 5 test senaryosu.
    // Senaryo seçilince mevcut tüm veri temizlenir, yeni state kurulur.

    enum InsightScenario: String, CaseIterable, Identifiable {
        case empty           // hiç araç yok
        case singleReminder  // tek hatırlatıcı (sakin)
        case overdueState    // gecikmiş hatırlatıcı
        case busyState       // yoğun state (5 hatırlatıcı)
        case quietGood       // sessiz iyi hal (tüm reminders completed)

        // Faz 1.1 — 5 içerik tipi senaryoları (Karar 4.2 test amaçlı)
        case criticalAction    // A. CTA — overdueReminder
        case seasonalInfo      // B. Bilgi — seasonalGuidance (BEV kış)
        case mechanicalWarning // C. Uyarı — transmissionGuidance (DSG 60K)
        case passiveReminder   // D. Hatırlatma — calendarPeriod (MTV)
        case softQuestion      // E. Soru — odometerUpdate

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .empty: return "Boş (hiç araç yok)"
            case .singleReminder: return "Tek hatırlatıcı (sakin)"
            case .overdueState: return "Gecikmiş hatırlatıcı"
            case .busyState: return "Yoğun state (5 hatırlatıcı)"
            case .quietGood: return "Sessiz iyi hal"
            case .criticalAction: return "A. Kritik Eylem (gecikmiş muayene)"
            case .seasonalInfo: return "B. Sezonluk Bilgi (BEV kış)"
            case .mechanicalWarning: return "C. Mekanik Uyarı (otomatik şanzıman)"
            case .passiveReminder: return "D. Pasif Hatırlatma (MTV)"
            case .softQuestion: return "E. Yumuşak Soru (km güncel mi?)"
            }
        }

        var icon: String {
            switch self {
            case .empty: return "tray"
            case .singleReminder: return "bell"
            case .overdueState: return "exclamationmark.triangle.fill"
            case .busyState: return "bell.badge.fill"
            case .quietGood: return "checkmark.seal.fill"
            case .criticalAction: return "exclamationmark.triangle.fill"
            case .seasonalInfo: return "snowflake"
            case .mechanicalWarning: return "exclamationmark.octagon.fill"
            case .passiveReminder: return "calendar"
            case .softQuestion: return "questionmark.bubble.fill"
            }
        }

        var description: String {
            switch self {
            case .empty: return "Empty state, 'ilk aracını ekle' CTA test edilir."
            case .singleReminder: return "Sakin state, 'yaklaşan' tipi insight."
            case .overdueState: return "Kırmızı primary insight üstte."
            case .busyState: return "Çakışan insight'lar, öncelik sıralaması."
            case .quietGood: return "Sessiz iyi hal, 'tamam' mesajı."
            case .criticalAction: return "A. CTA — zorunlu CTA butonu, dismiss yok."
            case .seasonalInfo: return "B. Bilgi — sadece dismiss butonu."
            case .mechanicalWarning: return "C. Uyarı — inline CTA + dismiss."
            case .passiveReminder: return "D. Hatırlatma — MTV, dismiss ile kapanır."
            case .softQuestion: return "E. Soru — çift buton (Ekle + Şimdi Değil)."
            }
        }
    }

    /// Seçilen senaryoyu kurar. Önce mevcut tüm veriyi temizler.
    static func seedInsightScenario(_ scenario: InsightScenario, context: ModelContext) {
        // 1. Mevcut veriyi temizle
        deleteAll(context: context)

        let calendar = Calendar.current
        let now = Date()

        switch scenario {
        case .empty:
            // Hiçbir şey ekleme — sadece temizle
            break

        case .singleReminder:
            let vehicle = makeDemoCar(
                plate: "34 TST 001",
                brand: "Toyota",
                model: "Corolla",
                year: 2022,
                odometer: 35000
            )
            context.insert(vehicle)
            let reminder = Reminder(
                vehicleId: vehicle.id,
                type: .inspection,
                title: "Periyodik Muayene",
                dueDate: calendar.date(byAdding: .month, value: 3, to: now) ?? now,
                priority: .warning
            )
            context.insert(reminder)

        case .overdueState:
            let vehicle = makeDemoCar(
                plate: "34 TST 002",
                brand: "Honda",
                model: "Civic",
                year: 2020,
                odometer: 78000
            )
            context.insert(vehicle)
            let reminder = Reminder(
                vehicleId: vehicle.id,
                type: .trafficInsurance,
                title: "Trafik Sigortası Yenileme",
                dueDate: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
                priority: .critical
            )
            context.insert(reminder)

        case .busyState:
            let vehicle = makeDemoCar(
                plate: "34 TST 003",
                brand: "Volkswagen",
                model: "Passat",
                year: 2019,
                odometer: 110000
            )
            context.insert(vehicle)

            let r1 = Reminder(
                vehicleId: vehicle.id,
                type: .inspection,
                title: "Periyodik Muayene",
                dueDate: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                priority: .critical
            )
            let r2 = Reminder(
                vehicleId: vehicle.id,
                type: .oilChange,
                title: "Yağ Değişimi",
                dueDate: now,
                priority: .warning
            )
            let r3 = Reminder(
                vehicleId: vehicle.id,
                type: .tire,
                title: "Lastik Rotasyonu",
                dueDate: calendar.date(byAdding: .month, value: 1, to: now) ?? now,
                priority: .warning
            )
            let r4 = Reminder(
                vehicleId: vehicle.id,
                type: .brakes,
                title: "Fren Balatası Kontrolü",
                dueDate: calendar.date(byAdding: .month, value: 3, to: now) ?? now,
                priority: .info
            )
            let r5 = Reminder(
                vehicleId: vehicle.id,
                type: .battery,
                title: "Akü Değişimi",
                dueDate: calendar.date(byAdding: .month, value: 6, to: now) ?? now,
                priority: .info
            )
            [r1, r2, r3, r4, r5].forEach { context.insert($0) }

        case .quietGood:
            let vehicle = makeDemoCar(
                plate: "34 TST 004",
                brand: "Hyundai",
                model: "i20",
                year: 2024,
                odometer: 12000
            )
            context.insert(vehicle)
            let reminder = Reminder(
                vehicleId: vehicle.id,
                type: .inspection,
                title: "Periyodik Muayene",
                dueDate: calendar.date(byAdding: .month, value: 2, to: now) ?? now,
                priority: .warning,
                status: .completed,
                completedAt: now
            )
            reminder.addedToHistoryAt = now
            context.insert(reminder)

        // MARK: - Faz 1.1 — 5 içerik tipi senaryoları (Karar 4.2)
        // Her senaryo tek bir insight tipini ön plana çıkarır.

        case .criticalAction:
            // A. CTA — overdueReminder (zorunlu CTA, dismiss yok)
            let vehicle = makeDemoCar(
                plate: "34 ACT 001",
                brand: "Honda",
                model: "Civic",
                year: 2020,
                odometer: 78_000
            )
            context.insert(vehicle)
            // Gecikmiş muayene → overdueReminder üretir
            context.insert(Reminder(
                vehicleId: vehicle.id,
                type: .inspection,
                title: "Periyodik Muayene",
                dueDate: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
                priority: .critical
            ))

        case .seasonalInfo:
            // B. Bilgi — seasonalGuidance (BEV kış, sadece dismiss)
            let vehicle = Vehicle(
                plate: "34 BEV 002",
                brand: "Tesla",
                model: "Model 3",
                year: 2023,
                vehicleType: .car,
                fuelType: .electric,
                transmissionType: .automatic,
                currentOdometer: 22_000
            )
            context.insert(vehicle)
            // fuelTypeGuidance + seasonalGuidance üretir
            // (kış ayındaysa seasonalGuidance da görünür)

        case .mechanicalWarning:
            // C. Uyarı — transmissionGuidance (otomatik şanzıman)
            let vehicle = makeDemoCar(
                plate: "34 MEC 003",
                brand: "Volkswagen",
                model: "Passat",
                year: 2019,
                odometer: 62_000
            )
            context.insert(vehicle)
            // transmissionGuidance + fuelTypeGuidance üretir

        case .passiveReminder:
            // D. Hatırlatma — calendarPeriod (MTV, dismiss ile kapanır)
            let vehicle = makeDemoCar(
                plate: "34 MTV 004",
                brand: "Renault",
                model: "Clio",
                year: 2024,
                odometer: 8_000
            )
            context.insert(vehicle)
            // MTV reminder yoksa → calendarPeriod üretir
            // (Ocak/Temmuz dışındaysa bu senaryo yine de profil rehberi gösterir)

        case .softQuestion:
            // E. Soru — odometerUpdate (çift buton)
            let vehicle = makeDemoCar(
                plate: "34 KMQ 005",
                brand: "Hyundai",
                model: "i20",
                year: 2022,
                odometer: 35_000
            )
            context.insert(vehicle)
            // Masraf + servis kayıtları yoksa odometerUpdate + monthlyExpensePrompt üretir
            // monthlyExpense için mevcut ayda expense olmamalı
        }

        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Senaryo seed'leme için paylaşılan araç factory'si.
    private static func makeDemoCar(
        plate: String,
        brand: String,
        model: String,
        year: Int,
        odometer: Int
    ) -> Vehicle {
        Vehicle(
            plate: plate,
            brand: brand,
            model: model,
            year: year,
            vehicleType: .car,
            fuelType: .gasoline,
            transmissionType: .automatic,
            currentOdometer: odometer
        )
    }
}
#endif
