import Foundation

// MARK: - AI Receipt Merge (pure logic)
// Yerel parse ile AI sonucunu birleştirme kuralları. Saf ve test edilebilir;
// UI bu kararları uygular. AI yalnızca BOŞ veya düşük güvenli alanları doldurur,
// kullanıcının elle düzenlediği bir alanı asla sessizce üzerine yazmaz.
enum AIReceiptMerge {
    static let lowConfidenceThreshold = 0.6
    static let maintenanceAutoThreshold = 0.8 // konsept eşiği (bkz. maintenanceDecision)

    /// Bir metin/alan için AI değeri uygulanmalı mı?
    static func shouldApply(
        currentIsEmpty: Bool,
        userEdited: Bool,
        localConfidence: Double,
        aiHasValue: Bool
    ) -> Bool {
        guard aiHasValue, !userEdited else { return false }
        return currentIsEmpty || localConfidence < lowConfidenceThreshold
    }

    /// isMaintenanceInvoice otomatik seçimi:
    /// - Kullanıcı toggle'a dokunduysa: karar kullanıcının (nil → değiştirme).
    /// - AI bool'u ile kategori sinyali UYUMLU ise (yüksek güven): otomatik uygula.
    /// - Çelişki varsa (belirsiz): nil → toggle nötr kalır, kullanıcı seçer.
    static func maintenanceDecision(
        aiIsMaintenance: Bool,
        aiCategory: String?,
        toggleTouched: Bool
    ) -> Bool? {
        guard !toggleTouched else { return nil }
        let categorySaysMaintenance = (aiCategory?.lowercased() == "maintenance")
        return aiIsMaintenance == categorySaysMaintenance ? aiIsMaintenance : nil
    }

    /// AI kategori string'ini uygulama kategorisine çevirir.
    static func category(from ai: String?) -> ExpenseCategory? {
        switch ai?.lowercased() {
        case "fuel": return .fuel
        case "maintenance": return .service
        case "insurance": return .insurance
        case "tire": return .tire
        case "other": return .other
        default: return nil
        }
    }
}

// MARK: - AI Escalation (degrade paths)
enum AIReceiptEscalation {
    /// Düşük güven + AI kullanılabilir → otomatik AI'ya yükselt.
    static func shouldAutoEscalate(overallConfidence: Double, aiAvailable: Bool) -> Bool {
        aiAvailable && overallConfidence < AIReceiptMerge.lowConfidenceThreshold
    }

    /// Hata için kullanıcıya gösterilecek nazik uyarı; .disabled sessizdir (nil).
    static func notice(for error: AIProxyError) -> String? {
        switch error {
        case .disabled:
            return nil // sessiz yerel fallback — rahatsız etme
        case .quotaExceeded:
            return "Yapay zekâ ay limitine ulaşıldı. Yerel okuma kullanılıyor."
        default:
            return nil // diğer hatalarda da sessizce yerel sonuç kullanılır
        }
    }
}
