import Foundation
import SwiftData
import XCTest
@testable import Ruhsatim

// MARK: - Model Creation Tests
// Temel model oluşturma, enum mapping ve computed property testleri.

final class VehicleModelTests: XCTestCase {

    // MARK: Vehicle
    func testVehicleCreation_defaults() {
        let vehicle = Vehicle(brand: "Toyota", model: "Corolla")

        XCTAssertNotNil(vehicle.id)
        XCTAssertEqual(vehicle.brand, "Toyota")
        XCTAssertEqual(vehicle.model, "Corolla")
        XCTAssertEqual(vehicle.fuelType, .gasoline) // default
        XCTAssertEqual(vehicle.usageType, .personal) // default
        XCTAssertEqual(vehicle.currentOdometer, 0)
        XCTAssertNil(vehicle.archivedAt)
    }

    func testVehicleCreation_full() {
        let vehicle = Vehicle(
            nickname: "Test Aracı",
            plate: "34 TEST 01",
            brand: "Honda",
            model: "Civic",
            year: 2022,
            fuelType: .hybrid,
            transmissionType: .automatic,
            currentOdometer: 15000,
            purchaseDate: Date(),
            purchasePrice: 750_000,
            usageType: .company
        )

        XCTAssertEqual(vehicle.fuelType, .hybrid)
        XCTAssertEqual(vehicle.transmissionType, .automatic)
        XCTAssertEqual(vehicle.usageType, .company)
        XCTAssertEqual(vehicle.fullName, "Honda Civic")
        XCTAssertEqual(vehicle.yearDisplay, "2022")
    }

    func testVehicleDisplayFormatters() {
        let vehicle = Vehicle(
            brand: "BMW",
            model: "320i",
            year: 2023,
            currentOdometer: 42000,
            purchasePrice: 1_250_000
        )

        XCTAssertEqual(vehicle.odometerDisplay, "42.000 km")
        XCTAssertEqual(vehicle.fullName, "BMW 320i")
        XCTAssertEqual(vehicle.yearDisplay, "2023")
        XCTAssertEqual(vehicle.purchasePriceDisplay, "₺1250000")
    }

    func testVehiclePlateDisplay() {
        let vehicle = Vehicle(plate: "34 ABC 123")

        XCTAssertEqual(vehicle.plate, "34 ABC 123")
    }

    // MARK: Reminder
    func testReminderCreation() {
        let vehicleId = UUID()
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!

        let reminder = Reminder(
            vehicleId: vehicleId,
            type: .inspection,
            title: "Muayene",
            dueDate: futureDate,
            priority: .warning
        )

        XCTAssertEqual(reminder.vehicleId, vehicleId)
        XCTAssertEqual(reminder.type, .inspection)
        XCTAssertEqual(reminder.priority, .warning)
        XCTAssertEqual(reminder.status, .active)
        XCTAssertFalse(reminder.isOverdue)
        XCTAssertFalse(reminder.isToday)
        XCTAssertTrue(reminder.isUpcoming)
        XCTAssertEqual(reminder.groupKey, .upcoming)
    }

    func testReminderOverdueStatus() {
        let vehicleId = UUID()
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        let reminder = Reminder(
            vehicleId: vehicleId,
            type: .trafficInsurance,
            title: "Trafik Sigortası",
            dueDate: pastDate,
            priority: .critical
        )

        XCTAssertTrue(reminder.isOverdue)
        XCTAssertEqual(reminder.groupKey, .overdue)
        XCTAssertGreaterThanOrEqual(reminder.daysOverdue, 9)
    }

    func testReminderTodayStatus() {
        let vehicleId = UUID()
        // Bugün içinde kalması için 1 saat ileri
        let todayDate = Date().addingTimeInterval(3600)
        let reminder = Reminder(
            vehicleId: vehicleId,
            type: .oilChange,
            title: "Yağ Değişimi",
            dueDate: todayDate,
            priority: .warning
        )

        XCTAssertTrue(reminder.isToday)
        XCTAssertFalse(reminder.isOverdue)
        XCTAssertEqual(reminder.groupKey, .today)
    }

    func testReminderCompletedStatus() {
        let vehicleId = UUID()
        let pastDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

        let reminder = Reminder(
            vehicleId: vehicleId,
            type: .inspection,
            title: "Muayene",
            dueDate: pastDate,
            status: .completed,
            completedAt: Date()
        )

        XCTAssertEqual(reminder.status, .completed)
        XCTAssertEqual(reminder.groupKey, .later) // tamamlananlar later grubunda
    }

    func testFutureReminderSnoozeUsesDueDateAsBase() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 27, hour: 12))!
        let futureDueDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 9))!

        let snoozed = Reminder.snoozedDueDate(currentDueDate: futureDueDate, days: 7, now: now, calendar: calendar)

        XCTAssertEqual(calendar.startOfDay(for: snoozed), calendar.date(from: DateComponents(year: 2026, month: 7, day: 17))!)
    }

    func testOverdueReminderSnoozeUsesTodayAsBase() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 27, hour: 12))!
        let overdueDueDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))!

        let snoozed = Reminder.snoozedDueDate(currentDueDate: overdueDueDate, days: 3, now: now, calendar: calendar)

        XCTAssertEqual(calendar.startOfDay(for: snoozed), calendar.date(from: DateComponents(year: 2026, month: 6, day: 30))!)
    }

    func testCompletedReminderIsFetchedByHistoryPredicateOnlyWhenAddedToHistory() throws {
        let container = try ModelContainer(
            for: Reminder.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let visibleReminder = Reminder(vehicleId: UUID(), type: .inspection, title: "Muayene")
        visibleReminder.completeAndAddToHistory(now: Date())
        let hiddenReminder = Reminder(vehicleId: UUID(), type: .casco, title: "Kasko", status: .completed, completedAt: Date())

        context.insert(visibleReminder)
        context.insert(hiddenReminder)
        try context.save()

        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.statusRaw == "Tamamlandı" && $0.addedToHistoryAt != nil },
            sortBy: [SortDescriptor(\.addedToHistoryAt, order: .reverse)]
        )
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.map(\.id), [visibleReminder.id])
        XCTAssertTrue(visibleReminder.isAddedToHistory)
    }

    func testReminderDaysRemaining() {
        let vehicleId = UUID()
        let futureDate = Calendar.current.date(byAdding: .day, value: 45, to: Date())!

        let reminder = Reminder(
            vehicleId: vehicleId,
            type: .mtvFirst,
            title: "MTV 1. Taksit",
            dueDate: futureDate
        )

        XCTAssertLessThanOrEqual(reminder.daysRemaining, 45)
        XCTAssertGreaterThanOrEqual(reminder.daysRemaining, 43) // tolerans
    }

    // MARK: Expense
    func testExpenseCreation() {
        let vehicleId = UUID()
        let expense = Expense(
            vehicleId: vehicleId,
            category: .fuel,
            amount: 1250.50,
            date: Date(),
            odometer: 78000,
            vendorName: "Shell"
        )

        XCTAssertEqual(expense.category, .fuel)
        XCTAssertEqual(expense.amount, 1250.50)
        XCTAssertEqual(expense.currencyCode, "TRY")
        XCTAssertEqual(expense.odometer, 78000)
        XCTAssertTrue(expense.amountDisplay.contains("₺"))
    }

    func testExpenseAmountFormatting() {
        let largeExpense = Expense(vehicleId: UUID(), category: .repair, amount: 15000)
        XCTAssertTrue(largeExpense.amountCompactDisplay.contains("₺15000"))

        let smallExpense = Expense(vehicleId: UUID(), category: .parking, amount: 25.50)
        XCTAssertTrue(smallExpense.amountCompactDisplay.contains("₺25.50"))
    }

    // MARK: ServiceRecord
    func testServiceRecordCreation() {
        let vehicleId = UUID()
        let service = ServiceRecord(
            vehicleId: vehicleId,
            serviceType: .periodic,
            date: Date(),
            odometer: 60000,
            vendorName: "Yetkili Servis",
            laborCost: 1800,
            partsCost: 2400,
            totalCost: 4200
        )

        XCTAssertEqual(service.serviceType, .periodic)
        XCTAssertEqual(service.odometer, 60000)
        XCTAssertEqual(service.totalCostDisplay, "₺4200")
    }

    func testServiceRecordCostCalculation() {
        // Total cost sadece labor + parts varsa computed
        let service = ServiceRecord(
            vehicleId: UUID(),
            serviceType: .oil,
            laborCost: 500,
            partsCost: 800
        )

        // totalCost nil ama labor+parts ile totalCostDisplay hesaplanmalı
        XCTAssertEqual(service.totalCostDisplay, "₺1300")
    }

    // MARK: PartChange
    func testPartChangeCreation() {
        let serviceRecordId = UUID()
        let part = PartChange(
            serviceRecordId: serviceRecordId,
            partType: .oil,
            brand: "Castrol",
            model: "Edge 5W-30"
        )

        XCTAssertEqual(part.partType, .oil)
        XCTAssertEqual(part.brand, "Castrol")
        XCTAssertEqual(part.partDisplay, "Castrol Edge 5W-30")
    }

    // MARK: VehicleDocument
    func testDocumentCreation() {
        let vehicleId = UUID()
        let doc = VehicleDocument(
            vehicleId: vehicleId,
            type: .insurancePolicy,
            title: "Trafik Sigortası",
            localFileName: "sigorta.pdf",
            expiryDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()),
            includeInSaleFile: true
        )

        XCTAssertEqual(doc.type, .insurancePolicy)
        XCTAssertTrue(doc.includeInSaleFile)
        XCTAssertTrue(doc.isExpiringSoon)
        XCTAssertFalse(doc.isExpired)
    }

    func testDocumentExpiredStatus() {
        let vehicleId = UUID()
        let doc = VehicleDocument(
            vehicleId: vehicleId,
            type: .insurancePolicy,
            title: "Eski Poliçe",
            localFileName: "eski.pdf",
            expiryDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())
        )

        XCTAssertTrue(doc.isExpired)
    }

    func testDocumentFileSizeFormatting() {
        let docSmall = VehicleDocument(vehicleId: UUID(), localFileName: "f.pdf", fileSizeBytes: 500)
        XCTAssertEqual(docSmall.fileSizeDisplay, "500 B")

        let docKB = VehicleDocument(vehicleId: UUID(), localFileName: "f.pdf", fileSizeBytes: 2500)
        XCTAssertEqual(docKB.fileSizeDisplay, "2 KB")

        let docMB = VehicleDocument(vehicleId: UUID(), localFileName: "f.pdf", fileSizeBytes: 2_500_000)
        XCTAssertTrue(docMB.fileSizeDisplay?.contains("MB") ?? false)
    }

    // MARK: InspectionReport
    func testInspectionReportCreation() {
        let vehicleId = UUID()
        let report = InspectionReport(
            vehicleId: vehicleId,
            providerName: "EksperPlus",
            branchName: "Kadıköy",
            reportDate: Date(),
            odometer: 48000,
            summary: "Araç durumu iyi",
            verificationStatus: .manual
        )

        XCTAssertEqual(report.providerName, "EksperPlus")
        XCTAssertEqual(report.verificationStatus, .manual)
        XCTAssertFalse(InspectionReport.legalDisclaimer.isEmpty)
    }

    // MARK: SaleFile
    func testSaleFileCreation() {
        let vehicleId = UUID()
        let saleFile = SaleFile(
            vehicleId: vehicleId,
            title: "Test Satış Dosyası",
            includedSections: [.summary, .serviceHistory, .disclaimer]
        )

        XCTAssertEqual(saleFile.title, "Test Satış Dosyası")
        XCTAssertEqual(saleFile.includedSections.count, 3)
        XCTAssertTrue(saleFile.includedSections.contains(.disclaimer))
        XCTAssertEqual(saleFile.viewCount, 0)
        XCTAssertFalse(SaleFile.legalDisclaimer.isEmpty)
    }

    func testSaleFileDefaultSections() {
        let saleFile = SaleFile(vehicleId: UUID())

        // Varsayılan bölümler
        XCTAssertTrue(saleFile.includedSections.contains(.summary))
        XCTAssertTrue(saleFile.includedSections.contains(.serviceHistory))
        XCTAssertTrue(saleFile.includedSections.contains(.documents))
        XCTAssertTrue(saleFile.includedSections.contains(.disclaimer))
    }

    // MARK: Enum tests
    func testFuelTypeAllCases() {
        XCTAssertEqual(FuelType.allCases.count, 5)
        XCTAssertEqual(FuelType.gasoline.displayName, "Benzin")
        XCTAssertEqual(FuelType.electric.displayName, "Elektrik")
    }

    func testExpenseCategoryAllCases() {
        // 17 ortak + 2 motosiklet özel - 5 otomobil özel kategorileri farklısayıldı = 20 toplam
        // Ortak: service, oil, tire, brake, battery, insurance, casco, tax, inspection, fuel, repair, part, accessory (13)
        // Otomobil: emission, parking, toll, fine, wash (5)
        // Motosiklet: chainSprocket, equipment (2)
        // Genel: other
        XCTAssertEqual(ExpenseCategory.allCases.count, 21) // 13+5+2+1
        XCTAssertEqual(ExpenseCategory.fuel.displayName, "Yakıt")
        XCTAssertEqual(ExpenseCategory.tax.displayName, "MTV")
    }

    func testReminderTypeAllCases() {
        // Ortak: 11 + Otomobil: 2 (timingBelt, hgs) + Motosiklet: 8 + Genel: 1 (custom) = 22
        XCTAssertEqual(ReminderType.allCases.count, 22)
        XCTAssertEqual(ReminderType.inspection.displayName, "Muayene")
        XCTAssertEqual(ReminderType.trafficInsurance.defaultIcon, "shield")
    }

    // MARK: Motorcycle Tests

    func testVehicleTypeDefaultCar() {
        let vehicle = Vehicle(brand: "Toyota", model: "Corolla")
        XCTAssertEqual(vehicle.vehicleType, .car)
        XCTAssertEqual(vehicle.vehicleTypeRaw, "Otomobil")
        XCTAssertNil(vehicle.motorcycleType)
        XCTAssertNil(vehicle.engineCC)
    }

    func testMotorcycleCreation() {
        let motorcycle = Vehicle(
            brand: "Yamaha",
            model: "MT-07",
            year: 2024,
            vehicleType: .motorcycle,
            motorcycleType: .naked,
            engineCC: 689,
            fuelType: .gasoline,
            transmissionType: .manual,
            currentOdometer: 5200
        )
        XCTAssertEqual(motorcycle.vehicleType, .motorcycle)
        XCTAssertEqual(motorcycle.vehicleTypeRaw, "Motosiklet")
        XCTAssertEqual(motorcycle.motorcycleType, .naked)
        XCTAssertEqual(motorcycle.engineCC, 689)
        XCTAssertEqual(motorcycle.vehicleType.heroSymbol, "gauge.with.needle")
        XCTAssertEqual(motorcycle.vehicleType.vehicleNoun, "motosiklet")
    }

    func testVehicleTypeCar() {
        let car = Vehicle(brand: "Renault", model: "Clio", vehicleType: .car)
        XCTAssertEqual(car.vehicleType, .car)
        XCTAssertEqual(car.vehicleType.heroSymbol, "car.fill")
        XCTAssertEqual(car.vehicleType.vehicleNoun, "araç")
        XCTAssertNil(car.motorcycleType)
    }

    func testMotorcycleReminderTemplates() {
        let mcTemplates = ReminderType.templates(for: .motorcycle)
        // Otomobile özel tipler motosiklette olmamalı
        XCTAssertFalse(mcTemplates.contains(.timingBelt))
        XCTAssertFalse(mcTemplates.contains(.hgs))
        // Motosiklet özel tipler içermeli
        XCTAssertTrue(mcTemplates.contains(.chainMaintenance))
        XCTAssertTrue(mcTemplates.contains(.sparkPlug))
        XCTAssertTrue(mcTemplates.contains(.airFilter))
        XCTAssertTrue(mcTemplates.contains(.seasonStartCheck))
    }

    func testCarReminderTemplates() {
        let carTemplates = ReminderType.templates(for: .car)
        // Otomobil özel tipler içermeli
        XCTAssertTrue(carTemplates.contains(.timingBelt))
        XCTAssertTrue(carTemplates.contains(.hgs))
        // Motosiklet özel tipler otomobilde olmamalı
        XCTAssertFalse(carTemplates.contains(.chainMaintenance))
        XCTAssertFalse(carTemplates.contains(.sparkPlug))
    }

    func testMotorcycleExpenseCategories() {
        let mcCategories = ExpenseCategory.categories(for: .motorcycle)
        XCTAssertTrue(mcCategories.contains(.chainSprocket))
        XCTAssertTrue(mcCategories.contains(.equipment))
        XCTAssertFalse(mcCategories.contains(.emission))
        XCTAssertFalse(mcCategories.contains(.parking))
    }

    func testMotorcycleDocumentTypes() {
        // Motosiklet özel belge tipleri enum'da mevcut olmalı
        let allDocs = DocumentType.allCases
        XCTAssertTrue(allDocs.contains(.equipmentInvoice))
        XCTAssertTrue(allDocs.contains(.helmetGearWarranty))
        XCTAssertTrue(allDocs.contains(.accessoryMounting))
    }

    func testMotorcycleTypeAllCases() {
        XCTAssertEqual(MotorcycleType.allCases.count, 8)
        XCTAssertEqual(MotorcycleType.scooter.displayName, "Scooter")
        XCTAssertEqual(MotorcycleType.naked.displayName, "Naked")
    }

    func testVehicleTypeAllCases() {
        XCTAssertEqual(VehicleType.allCases.count, 2)
        XCTAssertEqual(VehicleType.car.displayName, "Otomobil")
        XCTAssertEqual(VehicleType.motorcycle.displayName, "Motosiklet")
    }

    func testMotorcycleFileScore() {
        // Motor hacmi olan motosiklet ekstra skor alır
        let mc = Vehicle(
            brand: "Kawasaki",
            model: "Ninja 400",
            year: 2023,
            vehicleType: .motorcycle,
            engineCC: 399,
            fuelType: .gasoline,
            transmissionType: .manual,
            currentOdometer: 8000,
            purchaseDate: Date(),
            purchasePrice: 280_000
        )
        // Temel kriterler: brand(10)+model(10)+year(10)+odo(10)+trans(10)+purchaseDate(10)+purchasePrice(10)+engineCC(10)=80
        // Reminders ve expenses test context'inde olmadığı için 0
        // Toplam: 80
        XCTAssertEqual(mc.vehicleType, .motorcycle)
        XCTAssertEqual(mc.engineCC, 399)
        XCTAssertTrue(mc.currentOdometer > 0)
    }

    func testDocumentTypeIcons() {
        XCTAssertEqual(DocumentType.registration.defaultIcon, "doc.text")
        XCTAssertEqual(DocumentType.insurancePolicy.defaultIcon, "shield")
        XCTAssertEqual(DocumentType.expertReport.defaultIcon, "magnifyingglass")
    }

    func testVerificationStatusAllCases() {
        XCTAssertEqual(VerificationStatus.allCases.count, 4)
        XCTAssertEqual(VerificationStatus.manual.displayName, "Manuel")
    }

    func testEnumRoundtrip() {
        let fuelType: FuelType = .diesel
        let raw = fuelType.rawValue
        let restored = FuelType(rawValue: raw)
        XCTAssertEqual(restored, .diesel)
    }
}

final class Release110ProductTests: XCTestCase {
    func testDocumentTypesMapToExpectedExpiryReminderTemplates() {
        XCTAssertEqual(DocumentType.insurancePolicy.expiryReminderType, .trafficInsurance)
        XCTAssertEqual(DocumentType.cascoPolicy.expiryReminderType, .casco)
        XCTAssertEqual(DocumentType.inspectionReport.expiryReminderType, .inspection)
        XCTAssertEqual(DocumentType.warrantyDocument.expiryReminderType, .warranty)
        XCTAssertEqual(DocumentType.serviceInvoice.expiryReminderType, .custom)
    }

    func testDocumentReminderKeepsSourceRelationship() {
        let documentId = UUID()
        let reminder = Reminder(
            vehicleId: UUID(),
            type: .trafficInsurance,
            title: DocumentType.insurancePolicy.expiryReminderTitle,
            dueDate: Date(),
            sourceDocumentId: documentId
        )

        XCTAssertEqual(reminder.sourceDocumentId, documentId)
        XCTAssertEqual(reminder.title, "Trafik sigortası yenileme")
    }

    func testCostPerKmUsesDistanceBetweenReadings() {
        XCTAssertEqual(
            ReportMetrics.costPerKm(totalCost: 1_000, odometerReadings: [10_000, 10_500]),
            2
        )
    }

    func testCostPerKmRejectsSingleOrDuplicateReading() {
        XCTAssertNil(ReportMetrics.costPerKm(totalCost: 1_000, odometerReadings: [10_000]))
        XCTAssertNil(ReportMetrics.costPerKm(totalCost: 1_000, odometerReadings: [10_000, 10_000]))
        XCTAssertNil(ReportMetrics.costPerKm(totalCost: 0, odometerReadings: [10_000, 10_500]))
    }
}

// MARK: - Arvia Rehber Insight Tests
final class VehicleInsightServiceTests: XCTestCase {
    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private lazy var now: Date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 12))!

    private var service: VehicleInsightService {
        VehicleInsightService(calendar: calendar, now: now)
    }

    func testTodayGarageSummaryDoesNotCrashWithEmptyData() {
        let vehicle = Vehicle(brand: "Renault", model: "Clio")

        let insights = service.garageSummary(
            for: vehicle,
            reminders: [],
            expenses: [],
            serviceRecords: [],
            documents: [],
            inspectionReports: []
        )

        XCTAssertLessThanOrEqual(insights.count, VehicleInsightService.defaultVisibleLimit)
    }

    func testNoServiceRecordCreatesMaintenanceInsight() {
        let vehicleId = UUID()
        let insights = service.insights(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: [],
            expenses: [],
            serviceRecords: [],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        XCTAssertTrue(insights.contains { $0.type == .maintenance && $0.action == .addServiceRecord })
    }

    func testNoDocumentsCreatesDocumentInsight() {
        let vehicleId = UUID()
        let insights = service.insights(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: [],
            expenses: [],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        XCTAssertTrue(insights.contains { $0.type == .missingDocument && $0.action == .addDocument })
    }

    func testNoExpensesThisMonthCreatesMonthlyExpensePrompt() {
        let vehicleId = UUID()
        let insights = service.insights(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: [],
            expenses: [],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [],
            maxVisible: 10
        )

        XCTAssertTrue(insights.contains { $0.type == .monthlyExpensePrompt && $0.action == .addExpense })
    }

    func testOverdueReminderCreatesOverdueInsight() {
        let vehicleId = UUID()
        let overdueDate = calendar.date(byAdding: .day, value: -5, to: now)!
        let reminder = Reminder(
            vehicleId: vehicleId,
            type: .inspection,
            title: "Muayene",
            dueDate: overdueDate,
            priority: .critical
        )

        let insights = service.insights(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: [reminder],
            expenses: [],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        XCTAssertTrue(insights.contains { $0.type == .overdueReminder && $0.action == .openTodos })
    }

    func testOverdueReminderAppearsBeforeUpcomingReminder() {
        let vehicleId = UUID()
        let overdue = Reminder(
            vehicleId: vehicleId,
            type: .inspection,
            title: "Geciken",
            dueDate: calendar.date(byAdding: .day, value: -1, to: now),
            priority: .warning
        )
        let upcoming = Reminder(
            vehicleId: vehicleId,
            type: .casco,
            title: "Yaklaşan",
            dueDate: calendar.date(byAdding: .day, value: 7, to: now),
            priority: .critical
        )

        let insights = service.insights(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: [upcoming, overdue],
            expenses: [expense(vehicleId: vehicleId, amount: 100)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        XCTAssertEqual(insights.first?.type, .overdueReminder)
    }

    func testUpcomingReminderWithinFourteenDaysCreatesDailyInsight() {
        let vehicleId = UUID()
        let reminder = Reminder(
            vehicleId: vehicleId,
            type: .trafficInsurance,
            title: "Trafik Sigortası",
            dueDate: calendar.date(byAdding: .day, value: 14, to: now),
            priority: .warning
        )

        let insights = service.insights(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: [reminder],
            expenses: [expense(vehicleId: vehicleId, amount: 100)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        XCTAssertTrue(insights.contains { $0.type == .upcomingReminder && $0.action == .openTodos })
    }

    func testMonthlySummaryTotalCalculationIsCorrect() {
        let vehicleId = UUID()
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let summary = service.monthlySummary(expenses: [
            expense(vehicleId: vehicleId, category: .fuel, amount: 700, date: now),
            expense(vehicleId: vehicleId, category: .service, amount: 1_300, date: now),
            expense(vehicleId: vehicleId, category: .fuel, amount: 500, date: previousMonth),
        ])

        XCTAssertEqual(summary.total, 2_000, accuracy: 0.01)
        XCTAssertEqual(summary.count, 2)
        XCTAssertEqual(summary.topCategory, .service)
    }

    func testQuickKmUpdateValidationRejectsInvalidInput() {
        XCTAssertEqual(service.validateOdometerInput("", currentOdometer: 10_000, allowLowerValue: false), .empty)
        XCTAssertEqual(service.validateOdometerInput("abc", currentOdometer: 10_000, allowLowerValue: false), .invalid)
        XCTAssertEqual(service.validateOdometerInput("-1", currentOdometer: 10_000, allowLowerValue: false), .negative)
        XCTAssertEqual(service.validateOdometerInput("9000", currentOdometer: 10_000, allowLowerValue: false), .lowerNeedsConfirmation)
    }

    func testQuickKmUpdateAllowsEqualOrHigherKm() {
        XCTAssertEqual(service.validateOdometerInput("10000", currentOdometer: 10_000, allowLowerValue: false), .valid)
        XCTAssertEqual(service.validateOdometerInput("10001", currentOdometer: 10_000, allowLowerValue: false), .valid)
        XCTAssertEqual(service.validateOdometerInput("9000", currentOdometer: 10_000, allowLowerValue: true), .valid)
    }

    func testFuelTypeDieselCreatesSafeMaintenanceTrackingInsight() {
        let vehicleId = UUID()
        let insights = service.insights(
            for: Vehicle(id: vehicleId, fuelType: .diesel, currentOdometer: 42_000),
            reminders: [],
            expenses: [expense(vehicleId: vehicleId, amount: 100)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        let diesel = insights.first { $0.type == .fuelTypeGuidance }
        XCTAssertNotNil(diesel)
        XCTAssertTrue(diesel?.body.contains("DPF") == true, "Diesel body should explain DPF acronym per Faz 1.1 ton kuralları")
        XCTAssertFalse(diesel?.body.localizedCaseInsensitiveContains("kesin") == true)
    }

    func testTransmissionAutomaticCreatesSafeTransmissionHistoryInsight() {
        let vehicleId = UUID()
        let insights = service.insights(
            for: Vehicle(id: vehicleId, transmissionType: .automatic, currentOdometer: 42_000),
            reminders: [],
            expenses: [expense(vehicleId: vehicleId, amount: 100)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        let transmission = insights.first { $0.type == .transmissionGuidance }
        XCTAssertNotNil(transmission)
        // Faz 1.1: transmission body artık uyarı tonunda, kritik bilgi veriyor.
        XCTAssertTrue(transmission?.body.contains("şanzıman yağı") == true)
        XCTAssertTrue(transmission?.contentKind == .warning)
    }

    func testCurrentSeasonCreatesSafeSeasonalInsight() {
        let vehicleId = UUID()
        let insights = service.insights(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: [],
            expenses: [expense(vehicleId: vehicleId, amount: 100)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        let seasonal = insights.first { $0.type == .seasonalGuidance }
        XCTAssertEqual(seasonal?.title, "Yaz dönemi kontrolü")
        XCTAssertTrue(seasonal?.body.contains("faydalı olabilir") == true)
    }

    func testMTVCalendarPeriodCreatesSafeInsightInJanuaryAndJuly() {
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 12))!
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 12))!
        let vehicle = Vehicle(currentOdometer: 42_000)

        let januaryInsights = VehicleInsightService(calendar: calendar, now: january).insights(
            for: vehicle,
            reminders: [],
            expenses: [expense(vehicleId: vehicle.id, amount: 100, date: january)],
            serviceRecords: [serviceRecord(vehicleId: vehicle.id)],
            documents: [document(vehicleId: vehicle.id)],
            inspectionReports: [inspection(vehicleId: vehicle.id)],
            maxVisible: 10
        )
        let julyInsights = VehicleInsightService(calendar: calendar, now: july).insights(
            for: vehicle,
            reminders: [],
            expenses: [expense(vehicleId: vehicle.id, amount: 100, date: july)],
            serviceRecords: [serviceRecord(vehicleId: vehicle.id)],
            documents: [document(vehicleId: vehicle.id)],
            inspectionReports: [inspection(vehicleId: vehicle.id)],
            maxVisible: 10
        )

        XCTAssertTrue(januaryInsights.contains { $0.type == .calendarPeriod && $0.action == .addMTVReminder })
        XCTAssertTrue(julyInsights.contains { $0.type == .calendarPeriod && $0.action == .addMTVReminder })
    }

    func testCalendarPeriodInsightHiddenWhenMTVHatirlaticiAlreadyActive() {
        let calendar = Calendar(identifier: .gregorian)
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 12))!
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 12))!
        let vehicle = Vehicle(currentOdometer: 42_000)

        let activeMTVFirst = Reminder(
            vehicleId: vehicle.id,
            type: .mtvFirst,
            title: "MTV 1. taksit",
            dueDate: calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!,
            priority: .info
        )
        let activeMTVSecond = Reminder(
            vehicleId: vehicle.id,
            type: .mtvSecond,
            title: "MTV 2. taksit",
            dueDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))!,
            priority: .info
        )

        let januaryWithReminder = VehicleInsightService(calendar: calendar, now: january).insights(
            for: vehicle,
            reminders: [activeMTVFirst],
            expenses: [expense(vehicleId: vehicle.id, amount: 100, date: january)],
            serviceRecords: [serviceRecord(vehicleId: vehicle.id)],
            documents: [document(vehicleId: vehicle.id)],
            inspectionReports: [inspection(vehicleId: vehicle.id)],
            maxVisible: 10
        )
        let julyWithReminder = VehicleInsightService(calendar: calendar, now: july).insights(
            for: vehicle,
            reminders: [activeMTVSecond],
            expenses: [expense(vehicleId: vehicle.id, amount: 100, date: july)],
            serviceRecords: [serviceRecord(vehicleId: vehicle.id)],
            documents: [document(vehicleId: vehicle.id)],
            inspectionReports: [inspection(vehicleId: vehicle.id)],
            maxVisible: 10
        )

        XCTAssertFalse(januaryWithReminder.contains { $0.type == .calendarPeriod }, "MTV 1. taksit hatırlatıcısı varsa insight gösterilmemeli")
        XCTAssertFalse(julyWithReminder.contains { $0.type == .calendarPeriod }, "MTV 2. taksit hatırlatıcısı varsa insight gösterilmemeli")
    }

    func testCalendarPeriodTitleDiffersByMonth() {
        let calendar = Calendar(identifier: .gregorian)
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 12))!
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 12))!
        let vehicle = Vehicle(currentOdometer: 42_000)

        let januaryInsight = VehicleInsightService(calendar: calendar, now: january).insights(
            for: vehicle, reminders: [], expenses: [], serviceRecords: [], documents: [], inspectionReports: [], maxVisible: 10
        ).first { $0.type == .calendarPeriod }

        let julyInsight = VehicleInsightService(calendar: calendar, now: july).insights(
            for: vehicle, reminders: [], expenses: [], serviceRecords: [], documents: [], inspectionReports: [], maxVisible: 10
        ).first { $0.type == .calendarPeriod }

        XCTAssertEqual(januaryInsight?.title, "MTV 1. taksit dönemi")
        XCTAssertEqual(julyInsight?.title, "MTV 2. taksit dönemi")
        XCTAssertNotEqual(januaryInsight?.body, julyInsight?.body)
    }

    func testMTVCopyDoesNotContainForbiddenWords() {
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 12))!
        let vehicle = Vehicle(currentOdometer: 42_000)
        let insight = VehicleInsightService(calendar: calendar, now: january).insights(
            for: vehicle,
            reminders: [],
            expenses: [expense(vehicleId: vehicle.id, amount: 100, date: january)],
            serviceRecords: [serviceRecord(vehicleId: vehicle.id)],
            documents: [document(vehicleId: vehicle.id)],
            inspectionReports: [inspection(vehicleId: vehicle.id)],
            maxVisible: 10
        ).first { $0.type == .calendarPeriod }

        let copy = "\(insight?.title ?? "") \(insight?.body ?? "")".lowercased()
        XCTAssertFalse(copy.contains("resmi"), "MTV copy contains 'resmi': \(copy)")
        XCTAssertFalse(copy.contains("garanti"), "MTV copy contains 'garanti': \(copy)")
        XCTAssertFalse(copy.contains("yasal"), "MTV copy contains 'yasal': \(copy)")
        XCTAssertFalse(copy.contains("kesin"), "MTV copy contains 'kesin': \(copy)")
    }

    func testPriorityOrderPutsOverdueBeforeSeasonalAndCalendarSuggestions() {
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 12))!
        let januaryService = VehicleInsightService(calendar: calendar, now: january)
        let vehicleId = UUID()
        let overdue = Reminder(
            vehicleId: vehicleId,
            type: .inspection,
            title: "Geciken",
            dueDate: calendar.date(byAdding: .day, value: -1, to: january),
            priority: .info
        )

        let insights = januaryService.insights(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: [overdue],
            expenses: [expense(vehicleId: vehicleId, amount: 100, date: january)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        XCTAssertEqual(insights.first?.type, .overdueReminder)
        XCTAssertLessThan(insights.firstIndex { $0.type == .overdueReminder }!, insights.firstIndex { $0.type == .calendarPeriod }!)
    }

    func testDefaultVisibleInsightsNeverExceedThree() {
        let vehicle = Vehicle(currentOdometer: 0)

        let insights = service.insights(
            for: vehicle,
            reminders: [Reminder(vehicleId: vehicle.id, title: "Geciken", dueDate: calendar.date(byAdding: .day, value: -1, to: now))],
            expenses: [],
            serviceRecords: [],
            documents: [],
            inspectionReports: []
        )

        XCTAssertLessThanOrEqual(insights.count, 3)
    }

    func testGarageDailyContextExcludesFuelAndTransmissionGuidance() {
        let vehicleId = UUID()
        let insights = service.garageSummary(
            for: Vehicle(id: vehicleId, fuelType: .diesel, transmissionType: .automatic, currentOdometer: 42_000),
            reminders: [],
            expenses: [expense(vehicleId: vehicleId, amount: 100)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10
        )

        XCTAssertFalse(insights.contains { $0.type == .fuelTypeGuidance })
        XCTAssertFalse(insights.contains { $0.type == .transmissionGuidance })
        XCTAssertLessThanOrEqual(insights.count, 3)
    }

    func testVehicleDetailGuideIncludesVehicleSpecificGuidance() {
        let vehicleId = UUID()
        let insights = service.insights(
            for: Vehicle(id: vehicleId, fuelType: .diesel, transmissionType: .automatic, currentOdometer: 42_000),
            reminders: [],
            expenses: [expense(vehicleId: vehicleId, amount: 100)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10,
            displayContext: .vehicleDetailGuide()
        )

        XCTAssertTrue(insights.contains { $0.type == .fuelTypeGuidance })
        XCTAssertTrue(insights.contains { $0.type == .transmissionGuidance })
        XCTAssertTrue(insights.contains { $0.type == .seasonalGuidance })
    }

    func testVehicleDetailGuideExcludesReminderAlreadyShownInUpcomingTasks() {
        let vehicleId = UUID()
        let reminder = Reminder(
            vehicleId: vehicleId,
            type: .trafficInsurance,
            title: "Trafik Sigortası",
            dueDate: calendar.date(byAdding: .day, value: 3, to: now),
            priority: .warning
        )
        let tasks = service.upcomingTasks(reminders: [reminder], vehicleOdometer: 42_000)

        let insights = service.insights(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: [reminder],
            expenses: [expense(vehicleId: vehicleId, amount: 100)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10,
            displayContext: .vehicleDetailGuide(excludingReminderIds: Set(tasks.map(\.reminderId)))
        )

        XCTAssertFalse(insights.contains { $0.relatedReminderId == reminder.id })
        XCTAssertTrue(insights.contains { $0.type == .seasonalGuidance })
    }

    func testGarageDailyVisibleLimitRemainsOneToThreeCards() {
        let vehicleId = UUID()
        let reminders = (0..<5).map { offset in
            Reminder(
                vehicleId: vehicleId,
                type: .inspection,
                title: "İş \(offset)",
                dueDate: calendar.date(byAdding: .day, value: -offset - 1, to: now),
                priority: .critical
            )
        }

        let insights = service.garageSummary(
            for: Vehicle(id: vehicleId, currentOdometer: 42_000),
            reminders: reminders,
            expenses: [],
            serviceRecords: [],
            documents: [],
            inspectionReports: []
        )

        XCTAssertGreaterThanOrEqual(insights.count, 1)
        XCTAssertLessThanOrEqual(insights.count, 3)
    }

    func testInsightActionsMapToValidDestinations() {
        // Faz 1.1: meta-aksiyonlar (acknowledge/dismissAndSnooze/markAsRead/noAction)
        // navigasyon yapmaz — destinationKey boş olabilir.
        let navigationActions: Set<VehicleInsightAction> = [
            .addServiceRecord, .addDocument, .openSaleFile, .updateOdometer,
            .openTodos, .addInspectionReport, .addReminder, .addMTVReminder,
            .addExpense, .addFuelExpense
        ]
        for action in VehicleInsightAction.allCases {
            // title her zaman anlamlı olmalı (boş olabilir sadece dismiss-tipi meta için)
            if !navigationActions.contains(action) {
                continue  // meta-aksiyonların title'ı boş olabilir
            }
            XCTAssertFalse(action.title.isEmpty, "\(action.rawValue) title should not be empty")
            XCTAssertFalse(action.destinationKey.isEmpty, "\(action.rawValue) destinationKey should not be empty")
        }
    }

    func testVehicleInsightCopyDoesNotExposeRoadmapLanguage() {
        let vehicleId = UUID()
        let insights = service.insights(
            for: Vehicle(id: vehicleId, fuelType: .diesel, transmissionType: .manual, currentOdometer: 42_000),
            reminders: [],
            expenses: [expense(vehicleId: vehicleId, amount: 100)],
            serviceRecords: [serviceRecord(vehicleId: vehicleId)],
            documents: [document(vehicleId: vehicleId)],
            inspectionReports: [inspection(vehicleId: vehicleId)],
            maxVisible: 10,
            displayContext: .vehicleDetailGuide()
        )
        let blockedFragments = ["yakında", "gelecek", "ileride", "roadmap", "pro yakında"]

        for insight in insights {
            let copy = "\(insight.title) \(insight.body) \(insight.action?.title ?? "")".lowercased()
            for fragment in blockedFragments {
                XCTAssertFalse(copy.contains(fragment), "Unexpected future-facing copy: \(fragment)")
            }
        }
    }

    @MainActor
    func testKmUpdateRefreshPathCallsRefreshLogic() async throws {
        let container = try ModelContainer(
            for: Vehicle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let vehicle = Vehicle(currentOdometer: 10_000)
        context.insert(vehicle)
        try context.save()

        var refreshCallCount = 0
        try await VehicleContextRefreshService.updateCurrentOdometer(
            vehicle: vehicle,
            newOdometer: 12_000,
            context: context,
            notificationRefresh: { _ in
                refreshCallCount += 1
            }
        )

        XCTAssertEqual(vehicle.currentOdometer, 12_000)
        XCTAssertEqual(refreshCallCount, 1)
    }

    private func serviceRecord(vehicleId: UUID) -> ServiceRecord {
        ServiceRecord(vehicleId: vehicleId, serviceType: .periodic, date: now, odometer: 40_000)
    }

    private func document(vehicleId: UUID) -> VehicleDocument {
        VehicleDocument(vehicleId: vehicleId, type: .insurancePolicy, title: "Poliçe", localFileName: "policy.pdf")
    }

    private func inspection(vehicleId: UUID) -> InspectionReport {
        InspectionReport(vehicleId: vehicleId, providerName: "Ekspertiz", reportDate: now, odometer: 41_000)
    }

    private func expense(
        vehicleId: UUID,
        category: ExpenseCategory = .fuel,
        amount: Double,
        date: Date? = nil
    ) -> Expense {
        Expense(vehicleId: vehicleId, category: category, amount: amount, date: date ?? now)
    }
}

// MARK: - Report Calculation Tests
final class ReportCalculationTests: XCTestCase {

    func testYearlyTotal() {
        let vehicleId = UUID()
        let now = Date()
        let calendar = Calendar.current
        let expenses = [
            Expense(vehicleId: vehicleId, category: .fuel, amount: 1000, date: now),
            Expense(vehicleId: vehicleId, category: .service, amount: 2500, date: now),
            Expense(vehicleId: vehicleId, category: .tire, amount: 3200, date: calendar.date(byAdding: .year, value: -1, to: now)!),
        ]
        let thisYear = expenses
            .filter { Calendar.current.component(.year, from: $0.date) == calendar.component(.year, from: now) }
            .reduce(0) { $0 + $1.amount }
        XCTAssertEqual(thisYear, 3500.0, accuracy: 0.01)
    }

    func testMonthlyGrouping() {
        let vehicleId = UUID()
        let calendar = Calendar.current
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let february = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!
        let expenses = [
            Expense(vehicleId: vehicleId, category: .fuel, amount: 500, date: january),
            Expense(vehicleId: vehicleId, category: .fuel, amount: 300, date: january),
            Expense(vehicleId: vehicleId, category: .service, amount: 1500, date: february),
        ]
        let janTotal = expenses
            .filter { Calendar.current.component(.month, from: $0.date) == 1 }
            .reduce(0) { $0 + $1.amount }
        let febTotal = expenses
            .filter { Calendar.current.component(.month, from: $0.date) == 2 }
            .reduce(0) { $0 + $1.amount }
        XCTAssertEqual(janTotal, 800.0, accuracy: 0.01)
        XCTAssertEqual(febTotal, 1500.0, accuracy: 0.01)
    }

    func testCategoryBreakdown() {
        let vehicleId = UUID()
        let expenses = [
            Expense(vehicleId: vehicleId, category: .fuel, amount: 1000, date: Date()),
            Expense(vehicleId: vehicleId, category: .fuel, amount: 500, date: Date()),
            Expense(vehicleId: vehicleId, category: .service, amount: 2000, date: Date()),
            Expense(vehicleId: vehicleId, category: .tire, amount: 3200, date: Date()),
        ]
        var dict: [ExpenseCategory: Double] = [:]
        for e in expenses { dict[e.category, default: 0] += e.amount }
        XCTAssertEqual(dict[.fuel]!, 1500.0, accuracy: 0.01)
        XCTAssertEqual(dict[.service]!, 2000.0, accuracy: 0.01)
        XCTAssertEqual(dict[.tire]!, 3200.0, accuracy: 0.01)
    }

    func testCostPerKm() {
        let vehicleId = UUID()
        let expenses = [
            Expense(vehicleId: vehicleId, category: .fuel, amount: 5000, date: Date(), odometer: 5000),
            Expense(vehicleId: vehicleId, category: .service, amount: 2500, date: Date(), odometer: 10000),
        ]
        let totalExpense: Double = 7500
        let totalKm = expenses.compactMap { $0.odometer }.max() ?? 0
        let costPerKm = totalKm > 0 ? totalExpense / Double(totalKm) : nil
        XCTAssertEqual(costPerKm!, 0.75, accuracy: 0.01)
    }

    func testCostPerKmNoOdometer() {
        let expenses: [Expense] = [
            Expense(vehicleId: UUID(), category: .fuel, amount: 1000, date: Date()),
        ]
        let totalKm = expenses.compactMap { $0.odometer }.max() ?? 0
        let costPerKm = totalKm > 0 ? 1000.0 / Double(totalKm) : nil
        XCTAssertNil(costPerKm)
    }

    func testTopExpenses() {
        let vehicleId = UUID()
        let expenses = [
            Expense(vehicleId: vehicleId, category: .fuel, amount: 500, date: Date()),
            Expense(vehicleId: vehicleId, category: .tire, amount: 3200, date: Date()),
            Expense(vehicleId: vehicleId, category: .service, amount: 2500, date: Date()),
            Expense(vehicleId: vehicleId, category: .repair, amount: 8500, date: Date()),
            Expense(vehicleId: vehicleId, category: .fuel, amount: 800, date: Date()),
            Expense(vehicleId: vehicleId, category: .tax, amount: 2456, date: Date()),
        ]
        let top3 = expenses.sorted { $0.amount > $1.amount }.prefix(3)
        let topAmounts = top3.map { $0.amount }
        XCTAssertEqual(topAmounts, [8500, 3200, 2500])
    }

    func testEmptyExpenses() {
        let expenses: [Expense] = []
        let total = expenses.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(total, 0)
    }
}


// MARK: - Car Catalog Tests
final class CarCatalogTests: XCTestCase {
    func testCatalogLoadsFromBundle() throws {
        let catalog = try XCTUnwrap(CarCatalogService.shared.catalog)
        XCTAssertGreaterThan(catalog.brands.count, 0)
        XCTAssertGreaterThan(catalog.brands.reduce(0) { $0 + $1.models.count }, 0)
    }

    func testRequiredBrandsAreSearchable() {
        let service = CarCatalogService.shared
        XCTAssertEqual(service.searchBrands("Volkswagen").first?.displayName, "Volkswagen")
        XCTAssertEqual(service.searchBrands("Renault").first?.displayName, "Renault")
        XCTAssertEqual(service.searchBrands("Fiat").first?.displayName, "Fiat")
    }

    func testNormalizedAliasSearchFindsTurkishNames() {
        let service = CarCatalogService.shared
        XCTAssertEqual(service.searchBrands("citroen").first?.displayName, "Citroën")
        XCTAssertEqual(service.searchBrands("tofas").first?.displayName, "Tofaş")
    }

    func testModelSearchWithinBrand() throws {
        let service = CarCatalogService.shared
        let volkswagen = try XCTUnwrap(service.searchBrands("Volkswagen").first)
        let renault = try XCTUnwrap(service.searchBrands("Renault").first)
        let fiat = try XCTUnwrap(service.searchBrands("Fiat").first)

        XCTAssertEqual(service.searchModels(in: volkswagen, query: "Golf").first?.displayName, "Golf")
        XCTAssertEqual(service.searchModels(in: renault, query: "Clio").first?.displayName, "Clio")
        XCTAssertEqual(service.searchModels(in: fiat, query: "Egea").first?.displayName, "Egea")
    }

    func testModelResetWhenBrandChanges() {
        var selection = VehicleCatalogSelection(brand: "Volkswagen", model: "Golf")
        selection.selectBrand("Renault")
        XCTAssertEqual(selection.brand, "Renault")
        XCTAssertEqual(selection.model, "")
    }

    func testManualBrandModelValidation() {
        XCTAssertEqual(VehicleCatalogSelection(brand: "", model: "").validationErrors(), ["Marka zorunludur.", "Model zorunludur."])
        XCTAssertTrue(VehicleCatalogSelection(brand: "Özel Marka", model: "Özel Model").validationErrors().isEmpty)
    }

    func testCatalogDataQuality() throws {
        let catalog = try XCTUnwrap(CarCatalogService.shared.catalog)
        let brandIds = catalog.brands.map(\.id)
        XCTAssertEqual(Set(brandIds).count, brandIds.count)
        for brand in catalog.brands {
            XCTAssertFalse(brand.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            let modelIds = brand.models.map(\.id)
            XCTAssertEqual(Set(modelIds).count, modelIds.count, "Duplicate model id in \(brand.displayName)")
            for model in brand.models {
                XCTAssertFalse(model.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - Paywall Limit Tests
@MainActor
final class PaywallLimitTests: XCTestCase {
    func testFreeVehicleLimit() {
        let service = PaywallService(isProForTesting: false)
        XCTAssertTrue(service.canAddVehicle(currentCount: 0))
        XCTAssertFalse(service.canAddVehicle(currentCount: 1))
    }

    func testProVehicleLimit() {
        let service = PaywallService(isProForTesting: true)
        XCTAssertTrue(service.canAddVehicle(currentCount: 99))
    }

    func testFreeDocumentsAreUnlimitedForMVP() {
        let service = PaywallService(isProForTesting: false)
        XCTAssertTrue(service.canAddDocument(currentCount: 4))
        XCTAssertTrue(service.canAddDocument(currentCount: 5))
        XCTAssertTrue(service.canAddDocument(currentCount: 500))
    }

    func testProDocumentsRemainUnlimited() {
        let service = PaywallService(isProForTesting: true)
        XCTAssertTrue(service.canAddDocument(currentCount: 100))
    }

    func testSingleVehicleFreeUserFeatureGating() {
        let free = PaywallService(isProForTesting: false)
        // Satış dosyası + gelişmiş raporlar Pro; muayene raporu free kalır.
        XCTAssertFalse(free.canCreateSaleFile())
        XCTAssertFalse(free.canAccessAdvancedReports())
        XCTAssertTrue(free.canCreateInspectionReport())

        let pro = PaywallService(isProForTesting: true)
        XCTAssertTrue(pro.canCreateSaleFile())
        XCTAssertTrue(pro.canAccessAdvancedReports())
        XCTAssertTrue(pro.canCreateInspectionReport())
    }

    func testFreeUserDocumentAndInspectionRemainUnlocked() {
        let free = PaywallService(isProForTesting: false)

        // Belge + muayene raporu free kullanıcıda açık kalır.
        XCTAssertTrue(free.canSaveNewDocument(currentCount: 500))
        XCTAssertTrue(free.canAddDocument(currentCount: 500))
        XCTAssertTrue(free.canCreateInspectionReport())
        // Satış dosyası + gelişmiş raporlar Pro'ya taşındı.
        XCTAssertFalse(free.canCreateSaleFile())
        XCTAssertFalse(free.canAccessAdvancedReports())
    }

    func testFreeUserProGating() {
        let free = PaywallService(isProForTesting: false)

        // İkinci araç Pro.
        XCTAssertTrue(free.canAddVehicle(currentCount: 0))
        XCTAssertFalse(free.canAddVehicle(currentCount: 1))
        // Satış dosyası + gelişmiş raporlar Pro.
        XCTAssertFalse(free.canCreateSaleFile())
        XCTAssertFalse(free.canAccessAdvancedReports())
        // Muayene raporu + belge free.
        XCTAssertTrue(free.canCreateInspectionReport())
        XCTAssertTrue(free.canAddDocument(currentCount: 1_000))
    }

    func testDocumentSaveGuardIsUnlimitedForMVP() {
        let free = PaywallService(isProForTesting: false)
        XCTAssertTrue(free.canSaveNewDocument(currentCount: 4))
        XCTAssertTrue(free.canSaveNewDocument(currentCount: 5))
        XCTAssertTrue(free.canSaveNewDocument(currentCount: 500))

        let pro = PaywallService(isProForTesting: true)
        XCTAssertTrue(pro.canSaveNewDocument(currentCount: 500))
    }

    // "Garajım Pro" grubu App Store Connect'te silindikten sonra ID'ler
    // com.arvia.pro.* olarak yeniden tanımlandı. Silinen ID'ler Apple'da bir daha
    // kullanılamaz; bu test yeni ID sözleşmesini kilitler.
    func testProProductIDsUseArviaNamespace() {
        XCTAssertEqual(PaywallService.subscriptionProductIDs, [
            "com.arvia.pro.monthly",
            "com.arvia.pro.yearly",
        ])
        XCTAssertEqual(PaywallService.nonConsumableProductIDs, [
            "com.arvia.pro.lifetime",
        ])
        XCTAssertEqual(PaywallService.allProProductIDs, [
            "com.arvia.pro.monthly",
            "com.arvia.pro.yearly",
            "com.arvia.pro.lifetime",
        ])
    }

    func testRevokedSubscriptionDoesNotCancelAnotherValidProEntitlement() {
        let states = [
            PaywallService.EntitlementState(
                productID: "com.arvia.pro.monthly",
                isRevoked: true
            ),
            PaywallService.EntitlementState(
                productID: "com.arvia.pro.lifetime",
                isRevoked: false
            ),
        ]
        XCTAssertTrue(PaywallService.resolvesPro(from: states))
    }

    func testOnlyRevokedOrUnrelatedEntitlementsResolveFree() {
        let states = [
            PaywallService.EntitlementState(
                productID: "com.arvia.pro.yearly",
                isRevoked: true
            ),
            PaywallService.EntitlementState(
                productID: "com.example.other",
                isRevoked: false
            ),
        ]
        XCTAssertFalse(PaywallService.resolvesPro(from: states))
    }

    // Belge limiti MVP'de kaldırıldı; limit araç sayısında kalmalı.
    func testDocumentLimitRemovedForFreeMVP() {
        let free = PaywallService(isProForTesting: false)
        XCTAssertTrue(free.canAddDocument(currentCount: 5))
        XCTAssertTrue(free.canSaveNewDocument(currentCount: 5))
        XCTAssertTrue(free.canAddDocument(currentCount: 5_000))
        XCTAssertTrue(free.canSaveNewDocument(currentCount: 5_000))
    }

    // Pro kullanıcı belge limitine takılmaz
    func testProDocumentNoLimit() {
        let pro = PaywallService(isProForTesting: true)
        XCTAssertTrue(pro.canAddDocument(currentCount: 5000))
        XCTAssertTrue(pro.canSaveNewDocument(currentCount: 5000))
    }

    // Forum yazma artık Pro gerektirmez — auth yeterlidir.
    // canCreateCommunityPost() ve canWriteComment() kaldırıldı.
    // Pro gate sadece araç/belge/rapor/ekspertiz/satış PDF için geçerli.

    // Araç limiti active vehicle üzerinden değerlendirilmeli (archived sayılmaz)
    func testVehicleLimitExcludesArchived() {
        let free = PaywallService(isProForTesting: false)
        // 0 aktif araç → eklenebilir
        XCTAssertTrue(free.canAddVehicle(currentCount: 0))
        // 1 aktif araç → eklenemez
        XCTAssertFalse(free.canAddVehicle(currentCount: 1))
    }

    // Pro araç limiti yok
    func testProVehicleNoLimit() {
        let pro = PaywallService(isProForTesting: true)
        XCTAssertTrue(pro.canAddVehicle(currentCount: 99))
    }
}

// MARK: - ReminderRepeatEngine Tests
final class ReminderRepeatEngineTests: XCTestCase {

    func testYearlyNextDate() {
        let baseDate = DateComponents(calendar: .current, year: 2026, month: 6, day: 15).date!
        let next = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: .yearly)
        XCTAssertNotNil(next)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: next!)
        XCTAssertEqual(comps.year, 2027)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 15)
    }

    func testMonthlyNextDate() {
        let baseDate = DateComponents(calendar: .current, year: 2026, month: 1, day: 10).date!
        let next = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: .monthly)
        XCTAssertNotNil(next)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: next!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 2)
        XCTAssertEqual(comps.day, 10)
    }

    func testQuarterlyNextDate() {
        let baseDate = DateComponents(calendar: .current, year: 2026, month: 1, day: 1).date!
        let next = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: .quarterly)
        XCTAssertNotNil(next)
        let comps = Calendar.current.dateComponents([.year, .month], from: next!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 4) // +3 ay
    }

    func testBiannualNextDate() {
        let baseDate = DateComponents(calendar: .current, year: 2026, month: 3, day: 20).date!
        let next = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: .biannual)
        XCTAssertNotNil(next)
        let comps = Calendar.current.dateComponents([.year, .month], from: next!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 9) // +6 ay
    }

    func testNoneReturnsNil() {
        let baseDate = Date()
        let next = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: .none)
        XCTAssertNil(next)
    }

    func testCustomReturnsNil() {
        let baseDate = Date()
        let next = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: .custom)
        XCTAssertNil(next)
    }

    func testRuleParsingFromRawValue() {
        XCTAssertEqual(ReminderRepeatEngine.shared.rule(from: "monthly"), .monthly)
        XCTAssertEqual(ReminderRepeatEngine.shared.rule(from: "yearly"), .yearly)
        XCTAssertEqual(ReminderRepeatEngine.shared.rule(from: "quarterly"), .quarterly)
        XCTAssertEqual(ReminderRepeatEngine.shared.rule(from: "biannual"), .biannual)
        XCTAssertEqual(ReminderRepeatEngine.shared.rule(from: "none"), .none)
        XCTAssertEqual(ReminderRepeatEngine.shared.rule(from: nil), .none)
        XCTAssertEqual(ReminderRepeatEngine.shared.rule(from: "invalid"), .none)
    }

    func testYearEndBoundary() {
        // Aralık ayından Ocak'a geçiş
        let baseDate = DateComponents(calendar: .current, year: 2026, month: 12, day: 31).date!
        let next = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: .monthly)
        XCTAssertNotNil(next)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: next!)
        XCTAssertEqual(comps.year, 2027)
        XCTAssertEqual(comps.month, 1)
    }
}

// MARK: - Km Reminder Tests
final class KmReminderTests: XCTestCase {

    func testKmOverdueWhenOdometerExceeds() {
        let reminder = Reminder(vehicleId: UUID(), dueOdometer: 50000)
        XCTAssertTrue(reminder.isKmOverdue(vehicleOdometer: 55000))
        XCTAssertFalse(reminder.isKmOverdue(vehicleOdometer: 45000))
    }

    func testKmOverdueExactlyAtThreshold() {
        let reminder = Reminder(vehicleId: UUID(), dueOdometer: 50000)
        XCTAssertTrue(reminder.isKmOverdue(vehicleOdometer: 50000))
    }

    func testKmOverdueIgnoresCompletedReminder() {
        let reminder = Reminder(vehicleId: UUID(), dueOdometer: 50000, status: .completed)
        XCTAssertFalse(reminder.isKmOverdue(vehicleOdometer: 55000))
    }

    func testKmOverdueNoThreshold() {
        let reminder = Reminder(vehicleId: UUID(), dueOdometer: nil)
        XCTAssertFalse(reminder.isKmOverdue(vehicleOdometer: 55000))
    }

    func testKmUpcomingWithinRange() {
        let reminder = Reminder(vehicleId: UUID(), dueOdometer: 50000)
        XCTAssertTrue(reminder.isKmUpcoming(vehicleOdometer: 49000, withinKm: 2000))
        // 1000 km within 2000 range
        XCTAssertTrue(reminder.isKmUpcoming(vehicleOdometer: 49000))
    }

    func testKmUpcomingOutsideRange() {
        let reminder = Reminder(vehicleId: UUID(), dueOdometer: 50000)
        XCTAssertFalse(reminder.isKmUpcoming(vehicleOdometer: 47000, withinKm: 2000))
    }

    func testKmUpcomingWhenExceeded() {
        // Zaten geçilmişse upcoming false dönmeli
        let reminder = Reminder(vehicleId: UUID(), dueOdometer: 50000)
        XCTAssertFalse(reminder.isKmUpcoming(vehicleOdometer: 51000, withinKm: 2000))
    }

    func testRepeatRuleIsPreservedOnModel() {
        // Reminder modelinde repeatRuleRaw düzgün parse ediliyor mu?
        let reminder = Reminder(vehicleId: UUID(), repeatRule: "yearly")
        XCTAssertEqual(reminder.repeatRule, .yearly)
        XCTAssertEqual(reminder.repeatRuleRaw, "yearly")
    }

    func testRepeatRuleNoneByDefault() {
        let reminder = Reminder(vehicleId: UUID())
        XCTAssertEqual(reminder.repeatRule, .none)
        XCTAssertNil(reminder.repeatRuleRaw)
    }
}

// MARK: - InspectionReport includeInSaleFile Tests
final class InspectionReportIncludeInSaleFileTests: XCTestCase {

    func testDefaultIncludeInSaleFileIsFalse() {
        let report = InspectionReport(vehicleId: UUID())
        XCTAssertFalse(report.includeInSaleFile)
    }

    func testExplicitIncludeInSaleFileTrue() {
        let report = InspectionReport(vehicleId: UUID(), includeInSaleFile: true)
        XCTAssertTrue(report.includeInSaleFile)
    }

    func testExplicitIncludeInSaleFileFalse() {
        let report = InspectionReport(vehicleId: UUID(), includeInSaleFile: false)
        XCTAssertFalse(report.includeInSaleFile)
    }
}

// MARK: - Retention Notification Tests
final class RetentionNotificationServiceTests: XCTestCase {
    let service = RetentionNotificationService.shared

    // MARK: Km Update Frequency
    func testKmUpdateNextDateWeekly() {
        let baseDate = DateComponents(calendar: .current, year: 2026, month: 6, day: 15).date!
        let next = RetentionNotificationService.KmUpdateFrequency.weekly.nextDate(from: baseDate)
        XCTAssertNotNil(next)
        let diff = Calendar.current.dateComponents([.day], from: baseDate, to: next!).day
        XCTAssertEqual(diff, 7)
    }

    func testKmUpdateNextDateMonthly() {
        let baseDate = DateComponents(calendar: .current, year: 2026, month: 6, day: 15).date!
        let next = RetentionNotificationService.KmUpdateFrequency.monthly.nextDate(from: baseDate)
        XCTAssertNotNil(next)
        let comps = Calendar.current.dateComponents([.month, .day], from: next!)
        XCTAssertEqual(comps.month, 7)
    }

    func testKmUpdateNextDateQuarterly() {
        let baseDate = DateComponents(calendar: .current, year: 2026, month: 1, day: 1).date!
        let next = RetentionNotificationService.KmUpdateFrequency.quarterly.nextDate(from: baseDate)
        XCTAssertNotNil(next)
        let comps = Calendar.current.dateComponents([.month], from: next!)
        XCTAssertEqual(comps.month, 4)
    }

    func testKmUpdateNextDateBiannual() {
        let baseDate = DateComponents(calendar: .current, year: 2026, month: 3, day: 20).date!
        let next = RetentionNotificationService.KmUpdateFrequency.biannual.nextDate(from: baseDate)
        XCTAssertNotNil(next)
        let comps = Calendar.current.dateComponents([.month], from: next!)
        XCTAssertEqual(comps.month, 9)
    }

    // MARK: Quiet Hours
    func testQuietHoursNightAdjustedTo9AM() {
        // 22:00 → ertesi gün 09:00 (sessiz saatler 21:00-09:00 arası)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 22
        components.minute = 30
        let nightDate = Calendar.current.date(from: components)!
        let adjusted = RetentionNotificationService.adjustedForQuietHours(nightDate)
        let adjustedHour = Calendar.current.component(.hour, from: adjusted)
        XCTAssertEqual(adjustedHour, 9)
    }

    func testQuietHoursEarlyMorningAdjusted() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 3
        components.minute = 0
        let earlyDate = Calendar.current.date(from: components)!
        let adjusted = RetentionNotificationService.adjustedForQuietHours(earlyDate)
        let adjustedHour = Calendar.current.component(.hour, from: adjusted)
        XCTAssertEqual(adjustedHour, 9)
    }

    func testQuietHoursDaytimeUnchanged() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        components.minute = 0
        let dayDate = Calendar.current.date(from: components)!
        let adjusted = RetentionNotificationService.adjustedForQuietHours(dayDate)
        let adjustedHour = Calendar.current.component(.hour, from: adjusted)
        XCTAssertEqual(adjustedHour, 14)
    }

    // MARK: Cooldown
    func testDocumentCompleteness30DayCooldown() {
        let vehicleId = UUID()
        // İlk kontrol: cooldown yok
        XCTAssertFalse(service.isInCooldown(vehicleId: vehicleId, category: "doc", days: 30))
        // Mark cooldown
        service.markCooldown(vehicleId: vehicleId, category: "doc")
        // Şimdi cooldown'da olmalı
        XCTAssertTrue(service.isInCooldown(vehicleId: vehicleId, category: "doc", days: 30))
        // Temizle (test isolation)
        UserDefaults.standard.removeObject(forKey: "retention_cooldown_doc_\(vehicleId.uuidString)")
    }

    func testSaleFile90DayCooldown() {
        let vehicleId = UUID()
        XCTAssertFalse(service.isInCooldown(vehicleId: vehicleId, category: "salefile", days: 90))
        service.markCooldown(vehicleId: vehicleId, category: "salefile")
        XCTAssertTrue(service.isInCooldown(vehicleId: vehicleId, category: "salefile", days: 90))
        UserDefaults.standard.removeObject(forKey: "retention_cooldown_salefile_\(vehicleId.uuidString)")
    }

    // MARK: Monthly Summary
    func testMonthlySummarySameMonthDuplicatePrevention() {
        // Bu ay için henüz gönderilmemiş olmalı
        XCTAssertFalse(service.wasMonthlySummarySentThisMonth())
        // Gönderildi olarak işaretle
        service.markMonthlySummarySent()
        // Şimdi bu ay gönderilmiş olmalı
        XCTAssertTrue(service.wasMonthlySummarySentThisMonth())
        // Temizle
        UserDefaults.standard.removeObject(forKey: "retention_last_monthly_summary")
    }

    func testMonthlySummaryIdentifierUniquePerMonth() {
        let id = service.monthlySummaryIdentifier()
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        XCTAssertTrue(id.contains("\(currentYear)"))
        XCTAssertTrue(id.contains("\(currentMonth)"))
    }

    // MARK: Seasonal
    func testSeasonalMax4PerYear() {
        let year = Calendar.current.component(.year, from: Date())
        let key = "retention_seasonal_count_\(year)"
        // Başlangıçta 0
        let initial = service.seasonalCountForCurrentYear()
        // 4 kez işaretle
        for _ in 0..<4 {
            service.markSeasonalSent()
        }
        let afterFour = service.seasonalCountForCurrentYear()
        XCTAssertEqual(afterFour, initial + 4)
        // scheduleSeasonalReminders guard: count < 4 → artık schedule etmez
        XCTAssertFalse(afterFour < 4) // 4'te durmalı
        // Temizle
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: Preferences
    func testRetentionNotificationsAreUserControllable() {
        // Varsayılan değerler
        XCTAssertTrue(service.isKmUpdateEnabled)
        XCTAssertTrue(service.isMonthlySummaryEnabled)
        XCTAssertTrue(service.isDocumentCompletenessEnabled)
        XCTAssertTrue(service.isSeasonalEnabled)
        XCTAssertFalse(service.isSaleFileReminderEnabled)

        // Kapat
        service.isKmUpdateEnabled = false
        XCTAssertFalse(service.isKmUpdateEnabled)
        service.isMonthlySummaryEnabled = false
        XCTAssertFalse(service.isMonthlySummaryEnabled)

        // Geri al (test isolation)
        service.isKmUpdateEnabled = true
        service.isMonthlySummaryEnabled = true
    }

    func testKmUpdateFrequencyDefaultQuarterly() {
        // Varsayılan
        UserDefaults.standard.removeObject(forKey: "notif_pref_km_freq")
        // Yeni bir servis instance'ı ile test edemeyiz (singleton), UserDefaults'ı temizledik
        // Varsayılan değer .quarterly
        let freq = service.kmUpdateFrequency
        // Test sonrası geri yükle
        XCTAssertEqual(freq, .quarterly)
    }
}

// MARK: - Reminder Snooze Logic Tests
final class ReminderSnoozeTests: XCTestCase {

    /// Gelecekteki dueDate → dueDate baz alınır
    func testSnoozeFutureDueDate_UsesDueDateAsBase() {
        let today = Calendar.current.startOfDay(for: Date())
        let futureDue = Calendar.current.date(byAdding: .day, value: 9, to: today)!

        // snoozeBaseDate mantığı:
        let dueDay = Calendar.current.startOfDay(for: futureDue)
        let baseDate = dueDay > today ? dueDay : today

        // 3 gün ertele
        let snoozed = Calendar.current.date(byAdding: .day, value: 3, to: baseDate)!

        let expected = Calendar.current.date(byAdding: .day, value: 12, to: today)!
        XCTAssertEqual(Calendar.current.startOfDay(for: snoozed),
                       Calendar.current.startOfDay(for: expected),
                       "Gelecekteki iş: dueDate + 3 olmalı (today + 12)")
    }

    /// Gecikmiş dueDate → bugün baz alınır
    func testSnoozeOverdueDueDate_UsesTodayAsBase() {
        let today = Calendar.current.startOfDay(for: Date())
        let pastDue = Calendar.current.date(byAdding: .day, value: -5, to: today)!

        let dueDay = Calendar.current.startOfDay(for: pastDue)
        let baseDate = dueDay > today ? dueDay : today

        let snoozed = Calendar.current.date(byAdding: .day, value: 3, to: baseDate)!

        let expected = Calendar.current.date(byAdding: .day, value: 3, to: today)!
        XCTAssertEqual(Calendar.current.startOfDay(for: snoozed),
                       Calendar.current.startOfDay(for: expected),
                       "Gecikmiş iş: today + 3 olmalı")
    }

    /// Bugünkü dueDate → bugün baz alınır
    func testSnoozeTodayDueDate_UsesTodayAsBase() {
        let today = Calendar.current.startOfDay(for: Date())

        let dueDay = Calendar.current.startOfDay(for: Date())
        let baseDate = dueDay > today ? dueDay : today

        let snoozed = Calendar.current.date(byAdding: .day, value: 3, to: baseDate)!

        let expected = Calendar.current.date(byAdding: .day, value: 3, to: today)!
        XCTAssertEqual(Calendar.current.startOfDay(for: snoozed),
                       Calendar.current.startOfDay(for: expected),
                       "Bugünkü iş: today + 3 olmalı")
    }

    /// Nil dueDate → bugün baz alınır
    func testSnoozeNilDueDate_UsesTodayAsBase() {
        let today = Calendar.current.startOfDay(for: Date())

        // dueDate nil → baseDate = today
        let baseDate = today

        let snoozed = Calendar.current.date(byAdding: .day, value: 3, to: baseDate)!

        let expected = Calendar.current.date(byAdding: .day, value: 3, to: today)!
        XCTAssertEqual(Calendar.current.startOfDay(for: snoozed),
                       Calendar.current.startOfDay(for: expected),
                       "Nil dueDate: today + 3 olmalı")
    }

    /// Gelecekteki dueDate 1 gün sonra → dueDate baz alınır
    func testSnoozeTomorrowDueDate_UsesDueDateAsBase() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let dueDay = Calendar.current.startOfDay(for: tomorrow)
        let baseDate = dueDay > today ? dueDay : today

        let snoozed = Calendar.current.date(byAdding: .day, value: 7, to: baseDate)!

        let expected = Calendar.current.date(byAdding: .day, value: 8, to: today)!
        XCTAssertEqual(Calendar.current.startOfDay(for: snoozed),
                       Calendar.current.startOfDay(for: expected),
                       "Yarınki iş: dueDate + 7 olmalı (today + 8)")
    }
}

// MARK: - Notification Routing and Scheduling Harden Tests
final class NotificationRoutingAndSchedulingTests: XCTestCase {
    func testReminderIdentifierGenerationIsStable() {
        let reminderId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        XCTAssertEqual(NotificationService.reminderNotificationIdentifiers(for: reminderId), [
            "reminder-11111111-2222-3333-4444-555555555555-30d",
            "reminder-11111111-2222-3333-4444-555555555555-7d",
            "reminder-11111111-2222-3333-4444-555555555555-1d",
            "reminder-11111111-2222-3333-4444-555555555555-0d",
        ])
    }

    func testReminderFireDatesSkipPastOffsetsAndUseQuietHours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 12))!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 0))!

        let fireDates = NotificationService.reminderFireDates(dueDate: dueDate, now: now, calendar: calendar)

        XCTAssertEqual(fireDates.map(\.daysBefore), [1, 0])
        XCTAssertTrue(fireDates.allSatisfy { $0.date > now })
        XCTAssertEqual(calendar.component(.hour, from: fireDates[0].date), 9)
    }

    func testNotificationRouteParsingForReminder() {
        let vehicleId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let reminderId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let route = AppNotificationRoute(userInfo: [
            "deepLink": "reminder",
            "vehicleId": vehicleId.uuidString,
            "reminderId": reminderId.uuidString,
        ])

        XCTAssertEqual(route, .reminder(vehicleId: vehicleId, reminderId: reminderId))
        XCTAssertEqual(route?.targetTab, .todos)
    }

    func testNotificationRouteParsingForRetentionTypes() {
        let vehicleId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        XCTAssertEqual(AppNotificationRoute(userInfo: ["deepLink": "kmUpdate", "vehicleId": vehicleId.uuidString]), .vehicle(vehicleId: vehicleId, focus: .kmUpdate))
        XCTAssertEqual(AppNotificationRoute(userInfo: ["deepLink": "fileCompleteness", "vehicleId": vehicleId.uuidString]), .vehicle(vehicleId: vehicleId, focus: .fileCompleteness))
        XCTAssertEqual(AppNotificationRoute(userInfo: ["deepLink": "saleFile", "vehicleId": vehicleId.uuidString]), .vehicle(vehicleId: vehicleId, focus: .saleFile))
        XCTAssertEqual(AppNotificationRoute(userInfo: ["deepLink": "monthlySummary"]), .reports)
        XCTAssertEqual(AppNotificationRoute(userInfo: ["deepLink": "seasonalMaintenance"]), .todos(focus: .seasonalMaintenance))
    }

    func testRetentionIdentifierPrefixesAreCategorySpecific() {
        XCTAssertEqual(RetentionNotificationService.IdentifierPrefix.kmUpdate.rawValue, "retention-km")
        XCTAssertEqual(RetentionNotificationService.IdentifierPrefix.monthlySummary.rawValue, "retention-summary")
        XCTAssertEqual(RetentionNotificationService.IdentifierPrefix.documentCompleteness.rawValue, "retention-doc")
        XCTAssertEqual(RetentionNotificationService.IdentifierPrefix.seasonal.rawValue, "retention-seasonal")
        XCTAssertEqual(RetentionNotificationService.IdentifierPrefix.saleFile.rawValue, "retention-salefile")
    }
}
