import Foundation

// MARK: - PII Masking Service
// Cihazdan herhangi bir metin ÇIKMADAN ÖNCE Türkiye'ye özgü kişisel verileri maskeler:
// TC kimlik (resmi checksum ile doğrulanmış), plaka, IBAN, telefon → [MASKED].
// Tamamen yerel, saf string işleme. Ağ yok.
enum PIIMaskingService {
    static let maskToken = "[MASKED]"

    // Uygulama sırası önemli: uzun sayı dizileri (IBAN, telefon) TC taramasından önce
    // maskelenir; TC yalnızca checksum geçerse maskelenir; plaka en sonda.
    private static let ibanPattern = "TR(?: ?[0-9]){24}"
    private static let phonePattern = "(?<![0-9])(?:\\+90 ?|0)5[0-9]{9}(?![0-9])"
    private static let tcknPattern = "(?<![0-9])[0-9]{11}(?![0-9])"
    private static let platePattern = "\\b[0-9]{2} ?[A-ZÇĞİÖŞÜ]{1,3} ?[0-9]{2,4}\\b"

    /// Metindeki tüm PII adaylarını maskeler.
    static func mask(_ text: String) -> String {
        var result = text
        result = replaceAll(pattern: ibanPattern, in: result)
        result = replaceAll(pattern: phonePattern, in: result)
        result = maskTCKN(in: result)
        result = replaceAll(pattern: platePattern, in: result)
        return result
    }

    // MARK: - TC Kimlik No checksum (resmi algoritma)
    /// 11 haneli, ilk hane 0 olmayan; 10. hane ((tek toplam*7 - çift toplam) mod 10);
    /// 11. hane (ilk 10 hane toplamı mod 10).
    static func isValidTCKN(_ s: String) -> Bool {
        guard s.count == 11 else { return false }
        let digits = s.compactMap { $0.wholeNumberValue }
        guard digits.count == 11 else { return false }
        guard digits[0] != 0 else { return false }

        let oddSum = digits[0] + digits[2] + digits[4] + digits[6] + digits[8]
        let evenSum = digits[1] + digits[3] + digits[5] + digits[7]
        let tenth = ((oddSum * 7) - evenSum) % 10
        guard tenth == digits[9] else { return false }

        let eleventh = digits[0...9].reduce(0, +) % 10
        return eleventh == digits[10]
    }

    // MARK: - Helpers
    private static func replaceAll(pattern: String, in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: maskToken)
    }

    /// 11 haneli dizileri bulur; yalnızca checksum geçerse maskeler (fatura no gibi
    /// geçersiz adayları olduğu gibi bırakır).
    private static func maskTCKN(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: tcknPattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        var result = text
        // Sondan başa doğru değiştir ki NSRange kaymasın.
        for match in matches.reversed() {
            guard let r = Range(match.range, in: result) else { continue }
            let candidate = String(result[r])
            if isValidTCKN(candidate) {
                result.replaceSubrange(r, with: maskToken)
            }
        }
        return result
    }
}
