import CoreGraphics

// MARK: - 8pt Grid Spacing System
// Tüm spacing değerleri bu tokenlar üzerinden kullanılır.
// Hiçbir feature view'da ham CGFloat spacing kullanılmaz.

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // MARK: Semantic aliases
    static let relatedItems: CGFloat = xs      // 8 — ilgili öğeler arası
    static let cardPaddingH: CGFloat = md      // 16 — kart yatay iç padding
    static let cardPaddingV: CGFloat = md      // 16 — kart dikey iç padding (16-20 aralığı)
    static let sectionGap: CGFloat = lg        // 24 — bölümler arası
    static let screenMarginH: CGFloat = md     // 16 — ekran yatay margin (16-20)
    static let ctaSpacing: CGFloat = lg        // 24 — CTA çevresi
    static let largeGap: CGFloat = xl          // 32 — büyük bölüm arası
    static let floatingTabBarContentInset: CGFloat = 72

    // MARK: Minimums
    static let minimumRowHeight: CGFloat = 52
    static let minimumTapTarget: CGFloat = 44
}

extension CGFloat {
    static let xxs = AppSpacing.xxs
    static let xs = AppSpacing.xs
    static let sm = AppSpacing.sm
    static let md = AppSpacing.md
    static let lg = AppSpacing.lg
    static let xl = AppSpacing.xl
    static let xxl = AppSpacing.xxl
}
