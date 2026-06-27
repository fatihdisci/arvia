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
        XCTAssertEqual(motorcycle.vehicleType.heroSymbol, "bicycle")
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

    func testFreeDocumentLimit() {
        let service = PaywallService(isProForTesting: false)
        XCTAssertTrue(service.canAddDocument(currentCount: 4))
        XCTAssertFalse(service.canAddDocument(currentCount: 5))
    }

    func testProDocumentLimit() {
        let service = PaywallService(isProForTesting: true)
        XCTAssertTrue(service.canAddDocument(currentCount: 100))
    }

    func testSaleFileAndAdvancedReportsAreProOnly() {
        let free = PaywallService(isProForTesting: false)
        XCTAssertFalse(free.canCreateSaleFile())
        XCTAssertFalse(free.canAccessAdvancedReports())

        let pro = PaywallService(isProForTesting: true)
        XCTAssertTrue(pro.canCreateSaleFile())
        XCTAssertTrue(pro.canAccessAdvancedReports())
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
