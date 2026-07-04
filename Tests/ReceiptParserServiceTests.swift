import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - Receipt Parser Service Tests
// Gerçekçi Türkçe fiş/fatura metin fixture'ları ile kural tabanlı ayrıştırma testleri.
// Fixture'lar OCR çıktısını taklit eder (satır satır, Türkçe format).

final class ReceiptParserServiceTests: XCTestCase {

    private let parser = ReceiptParserService()

    private func date(_ day: Int, _ month: Int, _ year: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: Fixture 1 — Akaryakıt fişi
    private let fuelReceipt = """
    OPET AKARYAKIT
    Bağdat Cad. No:12 İstanbul
    Tarih: 15.03.2024
    MOTORİN
    Litre: 25,40
    Birim: 42,50
    TOPLAM: 1.079,50 TL
    """

    func testFuelReceipt() {
        let r = parser.parse(fuelReceipt)
        XCTAssertEqual(r.date, date(15, 3, 2024))
        XCTAssertEqual(r.total, Decimal(string: "1079.50"))
        XCTAssertEqual(r.category, .fuel)
        XCTAssertEqual(r.vendor, "OPET AKARYAKIT")
        XCTAssertGreaterThan(r.totalConfidence, 0.5)
    }

    // MARK: Fixture 2 — Servis/bakım faturası (km + genel toplam)
    private let serviceInvoice = """
    ÖZ USTA OTO SERVİS
    Vergi No: 1234567890
    Fatura Tarihi 03/11/2023
    Periyodik Bakım
    Motor Yağı Değişimi
    Yağ Filtresi
    KM: 87.450
    İşçilik: 500,00
    Ara Toplam: 1.250,00
    GENEL TOPLAM: 1.750,00
    """

    func testServiceInvoice() {
        let r = parser.parse(serviceInvoice)
        XCTAssertEqual(r.date, date(3, 11, 2023))
        XCTAssertEqual(r.total, Decimal(string: "1750.00"))
        XCTAssertEqual(r.category, .service)
        XCTAssertEqual(r.odometer, 87450)
        XCTAssertEqual(r.vendor, "ÖZ USTA OTO SERVİS")
    }

    // MARK: Fixture 3 — Sigorta poliçesi
    private let insurancePolicy = """
    ANADOLU SİGORTA A.Ş.
    Trafik Sigortası Poliçesi
    Poliçe No: 987654321
    Düzenleme: 01-01-2024
    Prim Tutarı
    TUTAR 3.420,75
    """

    func testInsurancePolicy() {
        let r = parser.parse(insurancePolicy)
        XCTAssertEqual(r.date, date(1, 1, 2024))
        XCTAssertEqual(r.total, Decimal(string: "3420.75"))
        XCTAssertEqual(r.category, .insurance)
        XCTAssertEqual(r.vendor, "ANADOLU SİGORTA A.Ş.")
    }

    // MARK: Fixture 4 — Lastik fişi
    private let tireReceipt = """
    LASTİKÇİ MEHMET
    Sanayi Sitesi
    22.07.2023
    4 Adet Lastik
    Balans + Rot Ayarı
    TOPLAM 8.500,00 TL
    """

    func testTireReceipt() {
        let r = parser.parse(tireReceipt)
        XCTAssertEqual(r.date, date(22, 7, 2023))
        XCTAssertEqual(r.total, Decimal(string: "8500.00"))
        XCTAssertEqual(r.category, .tire)
        XCTAssertEqual(r.vendor, "LASTİKÇİ MEHMET")
    }

    // MARK: Fixture 5 — Market/basit fiş (kategori yok, virgüllü küçük tutar)
    private let simpleReceipt = """
    MIGROS
    18/09/2024
    Cam Suyu
    Ampul
    TOPLAM 249,90
    """

    func testSimpleReceipt() {
        let r = parser.parse(simpleReceipt)
        XCTAssertEqual(r.date, date(18, 9, 2024))
        XCTAssertEqual(r.total, Decimal(string: "249.90"))
        XCTAssertNil(r.category)
        XCTAssertEqual(r.vendor, "MIGROS")
    }

    // MARK: Fixture 6 — LPG + iki haneli yıl
    private let lpgReceipt = """
    AYGAZ OTOGAZ
    Tarih 05.02.24
    LPG
    Litre 38,00
    GENEL TOPLAM 912,00 TL
    """

    func testLPGReceiptTwoDigitYear() {
        let r = parser.parse(lpgReceipt)
        XCTAssertEqual(r.date, date(5, 2, 2024))
        XCTAssertEqual(r.total, Decimal(string: "912.00"))
        XCTAssertEqual(r.category, .fuel)
    }

    // MARK: - Alan bazlı davranış
    func testMissingFieldsReturnNilAndZeroConfidence() {
        let r = parser.parse("Teşekkür ederiz\nTekrar bekleriz")
        XCTAssertNil(r.date)
        XCTAssertNil(r.total)
        XCTAssertNil(r.odometer)
        XCTAssertNil(r.category)
        XCTAssertEqual(r.dateConfidence, 0)
        XCTAssertEqual(r.totalConfidence, 0)
    }

    func testGeneralTotalPreferredOverSubtotal() {
        let text = """
        Ara Toplam: 1.000,00
        GENEL TOPLAM: 1.180,00
        """
        let r = parser.parse(text)
        XCTAssertEqual(r.total, Decimal(string: "1180.00"))
    }

    func testTurkishDecimalCommaParsing() {
        let text = "TUTAR 12.345,67"
        let r = parser.parse(text)
        XCTAssertEqual(r.total, Decimal(string: "12345.67"))
    }

    func testOdometerRangeGuard() {
        // 3 haneli sayı km değil, atlanmalı.
        let text = "KM 250"
        let r = parser.parse(text)
        XCTAssertNil(r.odometer)
    }

    func testVendorSkipsDateAndNumericLines() {
        let text = """
        01.01.2024
        123456789
        TAM OTO YIKAMA
        TOPLAM 150,00
        """
        let r = parser.parse(text)
        XCTAssertEqual(r.vendor, "TAM OTO YIKAMA")
    }

    func testNormalizationFoldsTurkishCharacters() {
        XCTAssertEqual(ReceiptParserService.normalizedUppercase("Şişli Benzin"), "SISLI BENZIN")
        XCTAssertEqual(ReceiptParserService.normalizedUppercase("Yağ Değişimi"), "YAG DEGISIMI")
    }
}
