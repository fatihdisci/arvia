import Foundation
import SwiftData

// MARK: - Receipt Model
// Fiş/fatura tarama (Faz 1) sonucu. Cihaz üstünde Vision OCR + kural tabanlı
// ayrıştırma ile üretilir — ağ yok, LLM yok. Ayrıştırılan alanlar kullanıcı
// tarafından düzenlenip Expense veya ServiceRecord'a bağlanır; orijinal sayfalar
// belge kasasına eklenir.
@Model
final class Receipt {
    // CloudKit uyumu için tüm non-optional alanlara property seviyesinde default verildi.
    var id: UUID = UUID()
    var vehicleId: UUID = UUID()
    var createdAt: Date = Date()

    // MARK: - Görüntü verisi
    // Taranan sayfaların ham görüntüleri (JPEG, sıkıştırılmış). Orijinal sayfalar
    // ayrıca DocumentStorageService ile belge kasasına da yazılır; burada Receipt'in
    // kendi kopyası tutulur. (externalStorage koleksiyon tiplerinde güvenilir
    // desteklenmediği için satır içi saklanır.)
    var pageImagesData: [Data] = []

    // MARK: - OCR + ayrıştırma
    var rawOCRText: String = ""
    var parsedDate: Date?
    var parsedTotal: Decimal?
    var parsedVendor: String?
    var parsedOdometer: Int?
    var suggestedCategory: String?

    // MARK: - Bağlantılar
    var linkedExpenseId: UUID?
    var linkedServiceRecordId: UUID?

    // Ayrıştırmanın genel güven skoru (0-1).
    var confidence: Double = 0

    // MARK: - Computed helpers
    var pageCount: Int { pageImagesData.count }

    var suggestedExpenseCategory: ExpenseCategory? {
        guard let raw = suggestedCategory else { return nil }
        return ExpenseCategory(rawValue: raw)
    }

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        createdAt: Date = Date(),
        pageImagesData: [Data] = [],
        rawOCRText: String = "",
        parsedDate: Date? = nil,
        parsedTotal: Decimal? = nil,
        parsedVendor: String? = nil,
        parsedOdometer: Int? = nil,
        suggestedCategory: String? = nil,
        linkedExpenseId: UUID? = nil,
        linkedServiceRecordId: UUID? = nil,
        confidence: Double = 0
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.createdAt = createdAt
        self.pageImagesData = pageImagesData
        self.rawOCRText = rawOCRText
        self.parsedDate = parsedDate
        self.parsedTotal = parsedTotal
        self.parsedVendor = parsedVendor
        self.parsedOdometer = parsedOdometer
        self.suggestedCategory = suggestedCategory
        self.linkedExpenseId = linkedExpenseId
        self.linkedServiceRecordId = linkedServiceRecordId
        self.confidence = confidence
    }
}
