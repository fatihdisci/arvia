import SwiftUI

// MARK: - Semantic Color System
// Dark-only luxury renk sistemi. Mat altın + deep navy palet.
// Tüm renkler sabit hex değerlerden gelir, asset catalog kullanılmaz.

// MARK: - Color Hex Initializer
extension Color {
    /// Hex string'den Color oluşturur. "#" prefix'li veya prefix'siz, 6 veya 8 karakter.
    /// Örnek: `Color(hex: "E6C479")`, `Color(hex: "#0A0E1A")`
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
    /// En derin arka plan rengi (surface-container-lowest)
    static let backgroundPrimary = Color(hex: "0A0E1A")
    /// Ana arka plan / surface
    static let backgroundSecondary = Color(hex: "0F131F")
    /// Kart yüzeyleri (surface-container-low)
    static let surfacePrimary = Color(hex: "171B28")
    /// Hafif elevasyonlu yüzey (surface-container)
    static let surfaceSecondary = Color(hex: "1B1F2C")

    // MARK: Text
    /// Cream-white — saf beyaz yerine düşük glare
    static let textPrimary = Color(hex: "F5F0E8")
    /// Gri-mavi secondary text
    static let textSecondary = Color(hex: "8B95A8")
    /// Muted outline rengi
    static let textTertiary = Color(hex: "999080")
    /// Gold buton üstünde koyu metin
    static let textOnAccent = Color(hex: "3F2E00")

    // MARK: Accent
    /// Mat altın — birincil vurgu rengi
    static let accentPrimary = Color(hex: "E6C479")
    /// Şampanya — ikincil vurgu
    static let accentSecondary = Color(hex: "D8C594")
    /// Gold tinted arka plan (accentPrimary @ 12%)
    static let accentMuted = Color(hex: "1FE6C479")

    // MARK: Semantic
    /// Koyu yeşil — başarı
    static let success = Color(hex: "2D5F3F")
    /// Success tint arka plan
    static let successBackground = Color(hex: "1F2D5F3F")
    /// Amber/altın — uyarı
    static let warning = Color(hex: "D4A017")
    /// Warning tint arka plan
    static let warningBackground = Color(hex: "1FD4A017")
    /// Koyu kırmızı — kritik/hata
    static let critical = Color(hex: "8B2C2C")
    /// Critical tint arka plan
    static let criticalBackground = Color(hex: "1F8B2C2C")

    // MARK: Functional
    /// Döküman rengi (secondary text ile aynı)
    static let document = Color(hex: "8B95A8")
    /// Araç rengi (secondary text ile aynı)
    static let vehicle = Color(hex: "8B95A8")
    /// 1px altın çerçeve — primary-container @ 15%
    static let border = Color(hex: "26C9A961")
    /// Subtitle divider — white @ 5%
    static let divider = Color(hex: "0DFFFFFF")

    // MARK: TabBar
    /// Tab bar arka planı (surface ile aynı)
    static let tabBarBackground = Color(hex: "0F131F")
    /// Tab bar inaktif ikon/metin rengi
    static let tabBarInactive = Color(hex: "8B95A8")
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
