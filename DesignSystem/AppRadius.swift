import CoreGraphics

// MARK: - Radius Token System
// "Cockpit Black" keskin geometri: container'lar 8px, kontroller 6px radius kullanır.
// Status element'ler (chip/pill) tam yuvarlak (9999) olur.

enum AppRadius {
    // MARK: Core tokens
    static let small: CGFloat = 4       // İnce kenar detayı
    static let medium: CGFloat = 6      // Kontroller (buton, input) — DESIGN.md "DEFAULT"
    static let large: CGFloat = 6       // Kart container'ları — DESIGN.md "lg" (HUD: 4-6pt)
    static let xlarge: CGFloat = 10     // Hero/medya kartları — DESIGN.md "xl"
    static let capsule: CGFloat = 9999  // Tam yuvarlak (chip, pill) — DESIGN.md "full"

    // MARK: Semantic aliases
    static let chip: CGFloat = capsule          // Status chip/pill
    static let row: CGFloat = medium            // Liste satırı: 6
    static let card: CGFloat = large            // Ana kart: 6
    static let heroCard: CGFloat = xlarge       // Hero kart: 10
    static let button: CGFloat = medium         // Buton: 6
    static let sheet: CGFloat = large           // Sheet/modal: 6
    // DESIGN.md uyumlu alias'lar
    static let sm: CGFloat = small              // 4
    static let md: CGFloat = medium             // 6
    static let lg: CGFloat = large              // 6
    static let xl: CGFloat = xlarge             // 10
    static let full: CGFloat = capsule          // 9999
}

extension CGFloat {
    static let radiusSmall = AppRadius.small
    static let radiusMedium = AppRadius.medium
    static let radiusLarge = AppRadius.large
    static let radiusXLarge = AppRadius.xlarge
    static let radiusCapsule = AppRadius.capsule
}
