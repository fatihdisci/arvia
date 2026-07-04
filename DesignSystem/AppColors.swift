import SwiftUI

// MARK: - Semantic Color System
// Dark-only "Cockpit Black" renk sistemi. AMOLED siyah + turkuaz vurgu.
// Tüm renkler sabit hex değerlerden gelir, asset catalog kullanılmaz.

// MARK: - Color Hex Initializer
extension Color {
    /// Hex string'den Color oluşturur. "#" prefix'li veya prefix'siz, 6 veya 8 karakter.
    /// Örnek: `Color(hex: "00E5C7")`, `Color(hex: "#000000")`
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let int = UInt64(hex, radix: 16) ?? 0
        let a, r, g, b: Double
        switch hex.count {
        case 6:
            (a, r, g, b) = (
                1.0,
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255
            )
        case 8:
            (a, r, g, b) = (
                Double((int >> 24) & 0xFF) / 255,
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255
            )
        default:
            (a, r, g, b) = (1, 0, 0, 0)
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Color Tokens
enum AppColors {
    // MARK: Background
    /// En derin arka plan rengi — AMOLED siyah (surface-container-lowest)
    static let backgroundPrimary = Color(hex: "000000")
    /// Ana arka plan / surface
    static let backgroundSecondary = Color(hex: "0A0A0A")
    /// Kart yüzeyleri (surface-container-low)
    static let surfacePrimary = Color(hex: "121214")
    /// Hafif elevasyonlu yüzey (surface-container)
    static let surfaceSecondary = Color(hex: "1A1A1C")

    // MARK: Text
    /// Soft white — saf beyaz yerine düşük glare
    static let textPrimary = Color(hex: "F5F5F7")
    /// Nötr gri secondary text
    static let textSecondary = Color(hex: "9A9AA0")
    /// Muted outline rengi
    static let textTertiary = Color(hex: "6E6E73")
    /// Turkuaz vurgu üstünde koyu teal metin
    static let textOnAccent = Color(hex: "00251F")
    /// Racing kırmızı (critical) fill üstünde koyu metin — #FF2D3C ile ≥4.5:1 (4.94:1)
    static let textOnCritical = Color(hex: "2B0A0C")

    // MARK: Accent
    /// Turkuaz — birincil vurgu rengi
    static let accentPrimary = Color(hex: "00E5C7")
    /// Açık turkuaz — ikincil vurgu
    static let accentSecondary = Color(hex: "33EDD4")
    /// Turkuaz tinted arka plan (accentPrimary @ 12%)
    static let accentMuted = Color(hex: "1F00E5C7")

    // MARK: Semantic
    /// Yeşil — başarı (saf siyah üzerinde ≥4.5:1)
    static let success = Color(hex: "3B8F5A")
    /// Success tint arka plan
    static let successBackground = Color(hex: "1F3B8F5A")
    /// Amber — uyarı
    static let warning = Color(hex: "D4A017")
    /// Warning tint arka plan
    static let warningBackground = Color(hex: "1FD4A017")
    /// Racing kırmızı — SADECE kritik/destructive; dekoratif kullanım yasak
    static let critical = Color(hex: "FF2D3C")
    /// Critical tint arka plan
    static let criticalBackground = Color(hex: "1FFF2D3C")

    // MARK: Functional
    /// Döküman rengi (secondary text ile aynı)
    static let document = Color(hex: "9A9AA0")
    /// Araç rengi (secondary text ile aynı)
    static let vehicle = Color(hex: "9A9AA0")
    /// 1px nötr hairline çerçeve — HUD/teknik şema hissi.
    /// Turkuaz yalnızca aktif/enerji vurgusudur; kart çerçeveleri nötrdür.
    static let border = Color(hex: "2A2A2C")
    /// Subtitle divider — white @ 5%
    static let divider = Color(hex: "0DFFFFFF")

    // MARK: TabBar
    /// Tab bar arka planı (backgroundSecondary ile aynı)
    static let tabBarBackground = Color(hex: "0A0A0A")
    /// Tab bar inaktif ikon/metin rengi (secondary text ile aynı)
    static let tabBarInactive = Color(hex: "9A9AA0")
}

// MARK: - SwiftUI Color extensions for semantic usage
extension Color {
    // Background
    static let appBackground = AppColors.backgroundPrimary
    static let appSurface = AppColors.surfacePrimary

    // Text
    static let appTextPrimary = AppColors.textPrimary
    static let appTextSecondary = AppColors.textSecondary

    // Accent
    static let appAccent = AppColors.accentPrimary
    static let appAccentSecondary = AppColors.accentSecondary

    // Semantic
    static let appSuccess = AppColors.success
    static let appWarning = AppColors.warning
    static let appCritical = AppColors.critical

    // Functional
    static let appBorder = AppColors.border
}
