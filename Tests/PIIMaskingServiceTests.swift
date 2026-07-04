import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - PII Masking Service Tests
// TC checksum + plaka/IBAN/telefon maskeleme; false-positive tuzakları dahil.
final class PIIMaskingServiceTests: XCTestCase {

    // Geçerli TC örnekleri (resmi algoritmadan üretildi).
    private let validTC1 = "10000000146"
    private let validTC2 = "29380892012"
    // Checksum'ı GEÇMEYEN 11 haneli fatura numarası — maskelenmemeli.
    private let invalidTC = "12345678901"

    private let mask = "[MASKED]"

    // 1
    func testTCKNChecksumValid() {
        XCTAssertTrue(PIIMaskingService.isValidTCKN(validTC1))
        XCTAssertTrue(PIIMaskingService.isValidTCKN(validTC2))
    }

    // 2 — kritik false-positive: geçersiz checksum maskelenmez.
    func testInvalidTCKNNotMasked() {
        XCTAssertFalse(PIIMaskingService.isValidTCKN(invalidTC))
        XCTAssertEqual(PIIMaskingService.mask("Fatura No \(invalidTC)"), "Fatura No \(invalidTC)")
    }

    // 3
    func testValidTCKNMasked() {
        XCTAssertEqual(PIIMaskingService.mask("Müşteri TC: \(validTC1) teşekkürler"),
                       "Müşteri TC: \(mask) teşekkürler")
    }

    // 4
    func testSecondValidTCKNMasked() {
        XCTAssertEqual(PIIMaskingService.mask("kimlik \(validTC2)"), "kimlik \(mask)")
    }

    // 5 — plaka (3 harf)
    func testPlateThreeLetters() {
        XCTAssertEqual(PIIMaskingService.mask("Plaka 34 ABC 123"), "Plaka \(mask)")
    }

    // 6 — plaka (2 harf, 4 rakam)
    func testPlateTwoLetters() {
        XCTAssertEqual(PIIMaskingService.mask("06 BC 1234 aracı"), "\(mask) aracı")
    }

    // 7 — IBAN boşluklu
    func testIBANWithSpaces() {
        XCTAssertEqual(PIIMaskingService.mask("IBAN: TR33 0006 1005 1978 6457 8413 26 hesap"),
                       "IBAN: \(mask) hesap")
    }

    // 8 — IBAN boşluksuz
    func testIBANNoSpaces() {
        XCTAssertEqual(PIIMaskingService.mask("TR330006100519786457841326"), mask)
    }

    // 9 — telefon 05...
    func testPhone05() {
        XCTAssertEqual(PIIMaskingService.mask("Ara: 05551234567"), "Ara: \(mask)")
    }

    // 10 — telefon +90...
    func testPhonePlus90() {
        XCTAssertEqual(PIIMaskingService.mask("Tel +905551234567 acil"), "Tel \(mask) acil")
    }

    // 11 — temiz metin değişmez
    func testCleanTextUnchanged() {
        let s = "Bugün hava güzel, 3 elma aldım"
        XCTAssertEqual(PIIMaskingService.mask(s), s)
    }

    // 12 — 10 haneli sayı TC değil, maskelenmez
    func testTenDigitNotMasked() {
        XCTAssertEqual(PIIMaskingService.mask("Kod 1234567890 son"), "Kod 1234567890 son")
    }

    // 13 — düz tutar plaka sanılmamalı
    func testAmountNotMistakenForPlate() {
        XCTAssertEqual(PIIMaskingService.mask("Toplam 1234 TL"), "Toplam 1234 TL")
    }

    // 14 — aynı metinde birden fazla PII
    func testMultiplePIIInOneString() {
        XCTAssertEqual(PIIMaskingService.mask("\(validTC1) ve 34 ABC 123 ve 05551234567"),
                       "\(mask) ve \(mask) ve \(mask)")
    }
}
