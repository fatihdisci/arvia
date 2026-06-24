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
        XCTAssertEqual(ExpenseCategory.allCases.count, 17)
        XCTAssertEqual(ExpenseCategory.fuel.displayName, "Yakıt")
        XCTAssertEqual(ExpenseCategory.tax.displayName, "MTV")
    }

    func testReminderTypeAllCases() {
        XCTAssertEqual(ReminderType.allCases.count, 14)
        XCTAssertEqual(ReminderType.inspection.displayName, "Muayene")
        XCTAssertEqual(ReminderType.trafficInsurance.defaultIcon, "shield")
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
        let now = Date()
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
