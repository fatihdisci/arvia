import Foundation

// MARK: - Parsed Receipt
// Kural tabanlı ayrıştırma sonucu. Her alan için ayrı güven skoru (0-1) taşır;
// UI bu skorları kullanarak alanları önceden doldurur ve düşük güvenli alanları
// kullanıcıya doğrulatır.
struct ParsedReceipt: Equatable {
    var date: Date?
    var dateConfidence: Double = 0

    var total: Decimal?
    var totalConfidence: Double = 0

    var vendor: String?
    var vendorConfidence: Double = 0

    var odometer: Int?
    var odometerConfidence: Double = 0

    var category: ExpenseCategory?
    var categoryConfidence: Double = 0

    /// Alanların ortalama güveni (yalnızca bir değer bulunmuş alanlar sayılır).
    var overallConfidence: Double {
        let scored = [
            date != nil ? dateConfidence : nil,
            total != nil ? totalConfidence : nil,
            vendor != nil ? vendorConfidence : nil,
            odometer != nil ? odometerConfidence : nil,
            category != nil ? categoryConfidence : nil,
        ].compactMap { $0 }
        guard !scored.isEmpty else { return 0 }
        return scored.reduce(0, +) / Double(scored.count)
    }
}

// MARK: - Receipt Parser Service
// Vision OCR metninden fiş/fatura alanlarını kural tabanlı çıkarır.
// Tamamen cihaz üstü, ağ yok. Türkçe fiş formatlarına göre ayarlanmıştır.
final class ReceiptParserService {
    static let shared = ReceiptParserService()

    init() {}

    // MARK: - Public API
    func parse(_ text: String) -> ParsedReceipt {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var result = ParsedReceipt()

        let dateResult = parseDate(from: text)
        result.date = dateResult.value
        result.dateConfidence = dateResult.confidence

        let totalResult = parseTotal(from: lines)
        result.total = totalResult.value
        result.totalConfidence = totalResult.confidence

        let vendorResult = parseVendor(from: lines)
        result.vendor = vendorResult.value
        result.vendorConfidence = vendorResult.confidence

        let odometerResult = parseOdometer(from: lines)
        result.odometer = odometerResult.value
        result.odometerConfidence = odometerResult.confidence

        let categoryResult = parseCategory(from: text)
        result.category = categoryResult.value
        result.categoryConfidence = categoryResult.confidence

        return result
    }

    // MARK: - Normalization
    /// Türkçe karakterleri ASCII'ye indirger ve büyük harfe çevirir.
    /// OCR'ın İ/I, Ş/S gibi tutarsızlıklarına karşı anahtar kelime eşleşmesini sağlamlaştırır.
    static func normalizedUppercase(_ s: String) -> String {
        var out = s.uppercased(with: Locale(identifier: "tr_TR"))
        let map: [Character: Character] = [
            "İ": "I", "I": "I", "Ş": "S", "Ğ": "G",
            "Ü": "U", "Ö": "O", "Ç": "C", "Â": "A",
        ]
        out = String(out.map { map[$0] ?? $0 })
        return out
    }

    // MARK: - Date
    private func parseDate(from text: String) -> (value: Date?, confidence: Double) {
        // dd.MM.yyyy / dd/MM/yyyy / dd-MM-yyyy (yıl 2 veya 4 hane)
        let pattern = #"\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (nil, 0) }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current

        for match in matches {
            guard match.numberOfRanges == 4,
                  let day = Int(ns.substring(with: match.range(at: 1))),
                  let month = Int(ns.substring(with: match.range(at: 2))) else { continue }
            var year = Int(ns.substring(with: match.range(at: 3))) ?? 0
            if year < 100 { year += 2000 }

            guard (1...31).contains(day), (1...12).contains(month), (2000...2100).contains(year) else { continue }

            var components = DateComponents()
            components.day = day
            components.month = month
            components.year = year
            if let date = calendar.date(from: components) {
                return (date, 0.9)
            }
        }
        return (nil, 0)
    }

    // MARK: - Total
    private func parseTotal(from lines: [String]) -> (value: Decimal?, confidence: Double) {
        // Öncelik: GENEL TOPLAM > TOPLAM > TUTAR
        var generalTotals: [Decimal] = []
        var totals: [Decimal] = []
        var amounts: [Decimal] = []

        for line in lines {
            let norm = Self.normalizedUppercase(line)
            let values = extractAmounts(from: line).filter { isPlausibleTotal($0) }
            guard !values.isEmpty else { continue }
            if norm.contains("GENEL TOPLAM") {
                generalTotals.append(contentsOf: values)
            } else if norm.contains("TOPLAM") {
                totals.append(contentsOf: values)
            } else if norm.contains("TUTAR") {
                amounts.append(contentsOf: values)
            }
        }

        if let best = generalTotals.max() { return (best, 0.9) }
        if let best = totals.max() { return (best, 0.8) }
        if let best = amounts.max() { return (best, 0.6) }
        return (nil, 0)
    }

    private func isPlausibleTotal(_ value: Decimal) -> Bool {
        value > 0 && value < 10_000_000
    }

    /// Bir satırdaki Türk sayı formatındaki tutarları çıkarır ("1.234,56" → 1234.56).
    private func extractAmounts(from line: String) -> [Decimal] {
        // İsteğe bağlı binlik nokta ayracı + isteğe bağlı virgül ondalık.
        let pattern = #"\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+,\d{1,2}|\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { m in
            let token = ns.substring(with: m.range)
            // Binlik noktaları kaldır, ondalık virgülü noktaya çevir.
            let normalized = token
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Decimal(string: normalized)
        }
    }

    // MARK: - Vendor
    private func parseVendor(from lines: [String]) -> (value: String?, confidence: Double) {
        // İlk 3 satırdan, tamamen rakam/tarih olmayan ilk anlamlı satırı seç.
        for line in lines.prefix(3) {
            if isSkippableVendorLine(line) { continue }
            // Baş/son süs karakterlerini kırp; nokta korunur ("A.Ş." bozulmasın).
            let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: " -*:"))
            if cleaned.count >= 2 {
                return (cleaned, 0.5)
            }
        }
        return (nil, 0)
    }

    private func isSkippableVendorLine(_ line: String) -> Bool {
        // Sayfa işaretçisi
        if line.hasPrefix("---") { return true }
        // Harf içermiyorsa (tamamen rakam/sembol) atla
        let hasLetter = line.rangeOfCharacter(from: .letters) != nil
        if !hasLetter { return true }
        // Sadece tarih olan satır
        let dateOnly = #"^\s*\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\s*$"#
        if line.range(of: dateOnly, options: .regularExpression) != nil { return true }
        return false
    }

    // MARK: - Odometer
    private func parseOdometer(from lines: [String]) -> (value: Int?, confidence: Double) {
        for line in lines {
            let norm = Self.normalizedUppercase(line)
            guard norm.contains("KM") else { continue }
            // "KM 123456", "123456 KM", "KM: 123.456"
            let pattern = #"(\d[\d.\s]{2,})\s*KM|KM[:\s]*(\d[\d.\s]{2,})"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = norm as NSString
            if let m = regex.firstMatch(in: norm, range: NSRange(location: 0, length: ns.length)) {
                for idx in 1..<m.numberOfRanges {
                    let r = m.range(at: idx)
                    if r.location != NSNotFound {
                        let digits = ns.substring(with: r).filter { $0.isNumber }
                        if let value = Int(digits), (1000...9_999_999).contains(value) {
                            return (value, 0.6)
                        }
                    }
                }
            }
        }
        return (nil, 0)
    }

    // MARK: - Category
    private func parseCategory(from text: String) -> (value: ExpenseCategory?, confidence: Double) {
        let norm = Self.normalizedUppercase(text)
        // Sıra önemli: daha spesifik kategoriler önce.
        let rules: [(keywords: [String], category: ExpenseCategory)] = [
            (["AKARYAKIT", "BENZIN", "MOTORIN", "LPG", "DIZEL"], .fuel),
            (["SIGORTA", "KASKO"], .insurance),
            (["LASTIK"], .tire),
            (["YAG", "FILTRE", "BAKIM", "SERVIS"], .service),
        ]
        for rule in rules {
            if rule.keywords.contains(where: { norm.contains($0) }) {
                return (rule.category, 0.7)
            }
        }
        return (nil, 0)
    }
}
