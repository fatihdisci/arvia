import Foundation
import SwiftData

// MARK: - Mock Data Provider
// Preview-only seed data. Production runtime does not call this provider.
enum MockDataProvider {
    static let selectedVehicleId = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!
    static let secondaryVehicleId = UUID(uuidString: "A2000000-0000-0000-0000-000000000002")!
    static let tertiaryVehicleId = UUID(uuidString: "A3000000-0000-0000-0000-000000000003")!

    // MARK: Container
    @MainActor
    static var previewContainer: ModelContainer {
        makePreviewContainer()
    }

    @MainActor
    static func makePreviewContainer(populated: Bool = true) -> ModelContainer {
        let schema = Schema([
            Vehicle.self,
            Reminder.self,
            Expense.self,
            ServiceRecord.self,
            PartChange.self,
            VehicleDocument.self,
            InspectionReport.self,
            SaleFile.self,
            Receipt.self,
            VehicleUsageProfile.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            if populated {
                insertMockData(into: container)
            }
            return container
        } catch {
            fatalError("Mock ModelContainer başlatılamadı: \(error)")
        }
    }

    @MainActor
    static var emptyPreviewContainer: ModelContainer {
        makePreviewContainer(populated: false)
    }

    @MainActor
    static func insertMockData(into container: ModelContainer) {
        let context = container.mainContext

        // ---- Araç 1 ----
        let vehicle1 = Vehicle(
            id: selectedVehicleId,
            nickname: "Beyaz Şahin",
            plate: "34 ABC 123",
            brand: "Toyota",
            model: "Corolla",
            year: 2020,
            fuelType: .gasoline,
            transmissionType: .automatic,
            currentOdometer: 78500,
            purchaseDate: DateComponents(calendar: .current, year: 2020, month: 3, day: 15).date,
            purchaseOdometer: 0,
            purchasePrice: 285_000,
            usageType: .personal
        )
        context.insert(vehicle1)

        // ---- Araç 2 ----
        let vehicle2 = Vehicle(
            id: secondaryVehicleId,
            nickname: "Mavi",
            plate: "06 CD 456",
            brand: "Renault",
            model: "Clio",
            year: 2018,
            fuelType: .diesel,
            transmissionType: .manual,
            currentOdometer: 142000,
            purchaseDate: DateComponents(calendar: .current, year: 2018, month: 8, day: 1).date,
            purchaseOdometer: 85000,
            purchasePrice: 165_000,
            usageType: .personal
        )
        context.insert(vehicle2)

        // ---- Araç 3 ----
        let vehicle3 = Vehicle(
            id: tertiaryVehicleId,
            nickname: "Hafta Sonu",
            plate: "35 EFG 789",
            brand: "BMW",
            model: "320i",
            year: 2016,
            fuelType: .gasoline,
            transmissionType: .automatic,
            currentOdometer: 96500,
            purchaseDate: DateComponents(calendar: .current, year: 2023, month: 5, day: 20).date,
            purchaseOdometer: 84200,
            purchasePrice: 1_125_000,
            usageType: .personal
        )
        context.insert(vehicle3)

        let calendar = Calendar.current
        let today = Date()

        // ---- Reminder'lar (Araç 1) ----
        let reminder1 = Reminder(
            id: UUID(uuidString: "B1000000-0000-0000-0000-000000000001")!,
            vehicleId: vehicle1.id,
            type: .inspection,
            title: "Muayene",
            dueDate: calendar.date(byAdding: .day, value: 45, to: today),
            priority: .warning
        )
        context.insert(reminder1)

        let reminder2 = Reminder(
            id: UUID(uuidString: "B2000000-0000-0000-0000-000000000002")!,
            vehicleId: vehicle1.id,
            type: .trafficInsurance,
            title: "Trafik Sigortası",
            dueDate: calendar.date(byAdding: .day, value: -5, to: today), // gecikmiş!
            priority: .critical
        )
        context.insert(reminder2)

        let reminder3 = Reminder(
            id: UUID(uuidString: "B3000000-0000-0000-0000-000000000003")!,
            vehicleId: vehicle1.id,
            type: .oilChange,
            title: "Yağ Değişimi",
            dueOdometer: 80000,
            priority: .warning
        )
        context.insert(reminder3)

        let reminder4 = Reminder(
            id: UUID(uuidString: "B4000000-0000-0000-0000-000000000004")!,
            vehicleId: vehicle1.id,
            type: .mtvFirst,
            title: "MTV 1. Taksit",
            dueDate: calendar.date(byAdding: .day, value: 120, to: today),
            priority: .info
        )
        context.insert(reminder4)

        // ---- Reminder'lar (Araç 2) ----
        let reminder5 = Reminder(
            id: UUID(uuidString: "B5000000-0000-0000-0000-000000000005")!,
            vehicleId: vehicle2.id,
            type: .timingBelt,
            title: "Triger Değişimi",
            dueDate: calendar.date(byAdding: .day, value: -2, to: today), // gecikmiş!
            dueOdometer: 140000,
            priority: .critical
        )
        context.insert(reminder5)

        let reminder6 = Reminder(
            id: UUID(uuidString: "B6000000-0000-0000-0000-000000000006")!,
            vehicleId: vehicle3.id,
            type: .custom,
            title: "Lastik basınç kontrolü",
            dueDate: calendar.date(byAdding: .day, value: 18, to: today),
            priority: .info
        )
        context.insert(reminder6)

        // ---- Masraflar (Araç 1) ----
        let expense1 = Expense(
            id: UUID(uuidString: "E1000000-0000-0000-0000-000000000001")!,
            vehicleId: vehicle1.id,
            category: .fuel,
            amount: 1250.50,
            date: calendar.date(byAdding: .day, value: -3, to: today)!,
            odometer: 78100,
            vendorName: "Shell"
        )
        context.insert(expense1)

        let expense2 = Expense(
            id: UUID(uuidString: "E2000000-0000-0000-0000-000000000002")!,
            vehicleId: vehicle1.id,
            category: .insurance,
            amount: 6850.00,
            date: calendar.date(byAdding: .day, value: -60, to: today)!,
            odometer: 72000,
            vendorName: "Allianz Sigorta"
        )
        context.insert(expense2)

        let expense3 = Expense(
            id: UUID(uuidString: "E3000000-0000-0000-0000-000000000003")!,
            vehicleId: vehicle1.id,
            category: .service,
            amount: 4200.00,
            date: calendar.date(byAdding: .day, value: -90, to: today)!,
            odometer: 68000,
            vendorName: "Toyota Plaza"
        )
        context.insert(expense3)

        let expense4 = Expense(
            id: UUID(uuidString: "E4000000-0000-0000-0000-000000000004")!,
            vehicleId: vehicle1.id,
            category: .tax,
            amount: 2456.00,
            date: calendar.date(byAdding: .day, value: -180, to: today)!,
            odometer: 60000,
            note: "MTV 2. taksit"
        )
        context.insert(expense4)

        // ---- Masraflar (Araç 2) ----
        let expense5 = Expense(
            id: UUID(uuidString: "E5000000-0000-0000-0000-000000000005")!,
            vehicleId: vehicle2.id,
            category: .fuel,
            amount: 980.75,
            date: calendar.date(byAdding: .day, value: -1, to: today)!,
            odometer: 141900,
            vendorName: "BP"
        )
        context.insert(expense5)

        let expense6 = Expense(
            id: UUID(uuidString: "E6000000-0000-0000-0000-000000000006")!,
            vehicleId: vehicle2.id,
            category: .part,
            amount: 3200.00,
            date: calendar.date(byAdding: .day, value: -30, to: today)!,
            odometer: 138000,
            vendorName: "Yedek Parça Dünyası",
            note: "Fren balatası + işçilik"
        )
        context.insert(expense6)

        // ---- Servis Kayıtları (Araç 1) ----
        let service1 = ServiceRecord(
            id: UUID(uuidString: "C1000000-0000-0000-0000-000000000001")!,
            vehicleId: vehicle1.id,
            serviceType: .periodic,
            date: calendar.date(byAdding: .day, value: -365, to: today)!,
            odometer: 52000,
            vendorName: "Toyota Plaza Bakırköy",
            laborCost: 1800,
            partsCost: 2400,
            totalCost: 4200,
            oilType: "Castrol Edge 5W-30",
            notes: "60.000 km periyodik bakım",
            nextReminderType: .periodicService,
            nextReminderDueDate: calendar.date(byAdding: .month, value: 12, to: calendar.date(byAdding: .day, value: -365, to: today)!),
            nextReminderDueOdometer: 70000
        )
        context.insert(service1)

        let service2 = ServiceRecord(
            id: UUID(uuidString: "C2000000-0000-0000-0000-000000000002")!,
            vehicleId: vehicle1.id,
            serviceType: .brake,
            date: calendar.date(byAdding: .day, value: -120, to: today)!,
            odometer: 64000,
            vendorName: "Özel Servis — Usta Ali",
            laborCost: 800,
            partsCost: 1500,
            totalCost: 2300,
            notes: "Ön fren disk + balata"
        )
        context.insert(service2)

        // ---- Değişen Parçalar ----
        let part1 = PartChange(
            id: UUID(uuidString: "C3000000-0000-0000-0000-000000000003")!,
            serviceRecordId: service1.id,
            partType: .oil,
            brand: "Castrol",
            model: "Edge 5W-30"
        )
        context.insert(part1)

        let part2 = PartChange(
            id: UUID(uuidString: "C4000000-0000-0000-0000-000000000004")!,
            serviceRecordId: service1.id,
            partType: .oilFilter,
            brand: "Mann",
            model: "W 712/80"
        )
        context.insert(part2)

        let part3 = PartChange(
            id: UUID(uuidString: "C5000000-0000-0000-0000-000000000005")!,
            serviceRecordId: service2.id,
            partType: .brakePad,
            brand: "Bosch",
            model: "BP 1250"
        )
        context.insert(part3)

        let part4 = PartChange(
            id: UUID(uuidString: "C6000000-0000-0000-0000-000000000006")!,
            serviceRecordId: service2.id,
            partType: .brakeDisc,
            brand: "Bosch",
            model: "BD 280"
        )
        context.insert(part4)

        // ---- Belgeler (Araç 1) ----
        let doc1 = VehicleDocument(
            id: UUID(uuidString: "D1000000-0000-0000-0000-000000000001")!,
            vehicleId: vehicle1.id,
            type: .registration,
            title: "Ruhsat",
            localFileName: "d1-ruhsat.pdf",
            includeInSaleFile: true
        )
        context.insert(doc1)

        let doc2 = VehicleDocument(
            id: UUID(uuidString: "D2000000-0000-0000-0000-000000000002")!,
            vehicleId: vehicle1.id,
            type: .insurancePolicy,
            title: "Trafik Sigortası 2026",
            localFileName: "d2-sigorta.pdf",
            expiryDate: calendar.date(byAdding: .day, value: -5, to: today), // süresi geçmiş
            vendorName: "Allianz Sigorta",
            includeInSaleFile: true
        )
        context.insert(doc2)

        let doc3 = VehicleDocument(
            id: UUID(uuidString: "D3000000-0000-0000-0000-000000000003")!,
            vehicleId: vehicle1.id,
            type: .serviceInvoice,
            title: "60.000 km Bakım Faturası",
            localFileName: "d3-bakim.pdf",
            issueDate: calendar.date(byAdding: .day, value: -365, to: today),
            vendorName: "Toyota Plaza",
            linkedRecordId: service1.id
        )
        context.insert(doc3)

        // ---- Ekspertiz Raporu ----
        let inspection1 = InspectionReport(
            id: UUID(uuidString: "A4000000-0000-0000-0000-000000000004")!,
            vehicleId: vehicle1.id,
            providerName: "EksperPlus",
            branchName: "Kadıköy",
            reportDate: calendar.date(byAdding: .day, value: -400, to: today)!,
            odometer: 48000,
            summary: "Araç genel durumu iyi. Kaporta ve motor bölümünde hasar tespit edilmemiştir. Boya kalınlığı standart değerlerde. Yürüyen aksamda aşınma yok.",
            documentId: nil,
            verificationStatus: .manual
        )
        context.insert(inspection1)

        // ---- Satış Dosyası (taslak) ----
        let saleFile1 = SaleFile(
            id: UUID(uuidString: "F1000000-0000-0000-0000-000000000001")!,
            vehicleId: vehicle1.id,
            title: "Toyota Corolla 2020 — Satış Dosyası",
            includedSections: [.summary, .serviceHistory, .expenses, .inspectionReports, .documents, .disclaimer],
            selectedDocumentIds: [doc1.id, doc2.id],
            selectedInspectionReportIds: [inspection1.id],
            includePhotos: false
        )
        context.insert(saleFile1)

        try? context.save()
    }

    @MainActor
    static func previewVehicle() -> Vehicle {
        Vehicle(
            id: selectedVehicleId,
            nickname: "Beyaz Şahin",
            plate: "34 ABC 123",
            brand: "Toyota",
            model: "Corolla",
            year: 2020,
            fuelType: .gasoline,
            transmissionType: .automatic,
            currentOdometer: 78500,
            purchaseDate: DateComponents(calendar: .current, year: 2020, month: 3, day: 15).date,
            purchaseOdometer: 0,
            purchasePrice: 285_000,
            usageType: .personal
        )
    }

    @MainActor
    static func previewVehicle2() -> Vehicle {
        Vehicle(
            id: secondaryVehicleId,
            nickname: "Mavi",
            plate: "06 CD 456",
            brand: "Renault",
            model: "Clio",
            year: 2018,
            fuelType: .diesel,
            transmissionType: .manual,
            currentOdometer: 142000,
            purchaseDate: DateComponents(calendar: .current, year: 2018, month: 8, day: 1).date,
            purchaseOdometer: 85000,
            purchasePrice: 165_000,
            usageType: .personal
        )
    }

    @MainActor
    static func previewVehicle3() -> Vehicle {
        Vehicle(
            id: tertiaryVehicleId,
            nickname: "Hafta Sonu",
            plate: "35 EFG 789",
            brand: "BMW",
            model: "320i",
            year: 2016,
            fuelType: .gasoline,
            transmissionType: .automatic,
            currentOdometer: 96500,
            purchaseDate: DateComponents(calendar: .current, year: 2023, month: 5, day: 20).date,
            purchaseOdometer: 84200,
            purchasePrice: 1_125_000,
            usageType: .personal
        )
    }
}
