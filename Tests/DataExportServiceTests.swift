import Foundation
import SwiftData
import XCTest
@testable import Ruhsatim

// MARK: - DataExportService Tests

final class DataExportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([
            Vehicle.self, Reminder.self, Expense.self,
            ServiceRecord.self, PartChange.self,
            VehicleDocument.self, InspectionReport.self, SaleFile.self,
            Receipt.self, VehicleUsageProfile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    // MARK: - Empty Export

    func testEmptyExportDoesNotCrash() throws {
        let result = try DataExportService.export(context: context)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        let data = try Data(contentsOf: result.url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Tüm recordCounts sıfır
        XCTAssertEqual(result.recordCounts["vehicles"], 0)
        XCTAssertEqual(result.recordCounts["reminders"], 0)
        XCTAssertEqual(result.recordCounts["expenses"], 0)
        XCTAssertEqual(result.recordCounts["serviceRecords"], 0)
        XCTAssertEqual(result.recordCounts["partChanges"], 0)
        XCTAssertEqual(result.recordCounts["documents"], 0)
        XCTAssertEqual(result.recordCounts["inspectionReports"], 0)
        XCTAssertEqual(result.recordCounts["saleFiles"], 0)
        XCTAssertEqual(result.recordCounts["receipts"], 0)
        XCTAssertEqual(result.recordCounts["usageProfiles"], 0)

        // Boş diziler
        XCTAssertEqual((json["vehicles"] as? [Any])?.count, 0)
        XCTAssertEqual((json["reminders"] as? [Any])?.count, 0)
    }

    // MARK: - Top-Level Keys Exist

    func testExportContainsExpectedTopLevelKeys() throws {
        // Insert one vehicle
        let vehicle = Vehicle(brand: "Test", model: "Car")
        context.insert(vehicle)
        try context.save()

        let result = try DataExportService.export(context: context)
        let data = try Data(contentsOf: result.url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let expectedKeys: Set<String> = [
            "vehicles", "reminders", "expenses", "serviceRecords",
            "partChanges", "documents", "inspectionReports", "saleFiles",
            "receipts", "usageProfiles", "exportDate", "appVersion",
            "exportFormatVersion", "recordCounts", "note"
        ]
        for key in expectedKeys {
            XCTAssertTrue(json.keys.contains(key), "Missing top-level key: \(key)")
        }

        // Metadata keys
        XCTAssertNotNil(json["exportDate"] as? String)
        XCTAssertNotNil(json["appVersion"] as? String)
        XCTAssertEqual(json["exportFormatVersion"] as? Int, 3)
        XCTAssertEqual(json["note"] as? String, "Belge dosyaları, araç fotoğrafları ve taranmış fiş görselleri JSON içine dahil edilmez.")
    }

    // MARK: - Document Files Not Embedded

    func testDocumentFilesNotEmbedded() throws {
        let vehicle = Vehicle(brand: "Test", model: "Car")
        context.insert(vehicle)
        try context.save()

        let doc = VehicleDocument(
            vehicleId: vehicle.id,
            type: .other,
            title: "Test Doc",
            originalFileName: "test.pdf"
        )
        context.insert(doc)
        try context.save()

        let result = try DataExportService.export(context: context)
        let data = try Data(contentsOf: result.url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let docs = json["documents"] as! [[String: Any]]
        XCTAssertEqual(docs.count, 1)

        // originalFileName var ama binary data yok
        XCTAssertEqual(docs[0]["originalFileName"] as? String, "test.pdf")
        XCTAssertNil(docs[0]["fileData"])
        XCTAssertNil(docs[0]["fileContent"])
    }

    // MARK: - Record Counts Correct

    func testRecordCountsMatchInsertedData() throws {
        let v1 = Vehicle(brand: "A", model: "B")
        let v2 = Vehicle(brand: "C", model: "D")
        context.insert(v1)
        context.insert(v2)

        let r1 = Reminder(vehicleId: v1.id, type: .custom, title: "Test")
        context.insert(r1)

        let e1 = Expense(vehicleId: v1.id, category: .fuel, amount: 100, currencyCode: "TRY", date: Date())
        context.insert(e1)

        try context.save()

        let result = try DataExportService.export(context: context)
        XCTAssertEqual(result.recordCounts["vehicles"], 2)
        XCTAssertEqual(result.recordCounts["reminders"], 1)
        XCTAssertEqual(result.recordCounts["expenses"], 1)
        XCTAssertEqual(result.recordCounts["serviceRecords"], 0)
    }

    func testReceiptAndUsageProfileAreIncludedWithoutBinaryImages() throws {
        let vehicle = Vehicle(brand: "Test", model: "Car")
        context.insert(vehicle)
        context.insert(Receipt(
            vehicleId: vehicle.id,
            pageImagesData: [Data([0x01, 0x02])],
            rawOCRText: "TOPLAM 100 TL",
            parsedTotal: 100
        ))
        context.insert(VehicleUsageProfile(
            vehicleId: vehicle.id,
            dailyKmBand: .from50to100,
            routeType: .city
        ))
        try context.save()

        let result = try DataExportService.export(context: context)
        let data = try Data(contentsOf: result.url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let receipts = json["receipts"] as! [[String: Any]]
        let profiles = json["usageProfiles"] as! [[String: Any]]

        XCTAssertEqual(receipts.count, 1)
        XCTAssertEqual(receipts[0]["pageCount"] as? Int, 1)
        XCTAssertNil(receipts[0]["pageImagesData"])
        XCTAssertEqual(profiles.first?["dailyKmBand"] as? String, DailyKmBand.from50to100.rawValue)
        XCTAssertEqual(result.recordCounts["receipts"], 1)
        XCTAssertEqual(result.recordCounts["usageProfiles"], 1)
    }

    // MARK: - Filename Format

    func testFilenameFormat() throws {
        let result = try DataExportService.export(context: context)
        let filename = result.url.lastPathComponent
        XCTAssertTrue(filename.hasPrefix("arvia-export-"))
        XCTAssertTrue(filename.hasSuffix(".json"))
        // Format: arvia-export-YYYY-MM-DD.json
        let datePart = filename
            .replacingOccurrences(of: "arvia-export-", with: "")
            .replacingOccurrences(of: ".json", with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        XCTAssertNotNil(formatter.date(from: datePart), "Filename date format should be yyyy-MM-dd")
    }
}
