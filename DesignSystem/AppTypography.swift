import SwiftUI

// MARK: - Typography System
// SF Pro (UI metinleri) + JetBrains Mono (veri: plaka, tutar, km).
// Dark-only luxury tasarımda tipografi hiyerarşisi DESIGN.md'den alınmıştır.
// Dynamic Type otomatik desteklenir (sistem font'ları için).

enum AppTypography {
    // MARK: SF Pro Display — Başlıklar

    /// Hero metrik — 64px Light (JetBrains Mono, terminal/odometre okuması)
    static var heroMetric: Font { .custom("JetBrainsMono-Light", size: 64) }
    /// Ekran başlığı — 28px Bold (SF Pro Display)
    static var screenTitle: Font { .system(size: 28, weight: .bold) }
    /// Bölüm başlığı — 18px Semibold (SF Pro Display)
    static var sectionTitle: Font { .system(size: 18, weight: .semibold) }

    // MARK: SF Pro Text — Gövde metinleri

    /// Kart başlığı — 16px Semibold (SF Pro Text)
    static var cardTitle: Font { .system(size: 16, weight: .semibold, design: .default) }
    /// Ana gövde — 16px Regular
    static var bodyMain: Font { .system(size: 16, weight: .regular, design: .default) }
    /// İkincil gövde — 14px Regular
    static var bodySecondary: Font { .system(size: 14, weight: .regular, design: .default) }
    /// Etiket (caps) — 11px Medium, 0.15em tracking
    static var labelCaps: Font { .system(size: 11, weight: .medium, design: .default) }

    // MARK: JetBrains Mono — Teknik veri

    /// Plaka gösterimi — 24px Bold, 0.125em tracking
    static var plateDisplay: Font { .custom("JetBrainsMono-Bold", size: 24) }
    /// Büyük tutar — 32px Light
    static var amountLg: Font { .custom("JetBrainsMono-Light", size: 32) }
    /// Orta tutar — 20px SemiBold
    static var amountMd: Font { .custom("JetBrainsMono-SemiBold", size: 20) }
    /// Mono etiket — 11px Regular
    static var labelMono: Font { .custom("JetBrainsMono-Regular", size: 11) }

    // MARK: Backward-compatible aliases
    /// @deprecated Use `plateDisplay` for new code
    static var plate: Font { plateDisplay }
    /// @deprecated Use `amountMd` for new code
    static var amount: Font { amountMd }
    /// @deprecated Use `amountLg` for new code
    static var amountLarge: Font { amountLg }
    /// @deprecated Use `heroMetric` for new code
    static var heroNumber: Font { heroMetric }
    /// @deprecated Use `screenTitle` for new code
    static var screenTitleWeight: Font { screenTitle }
    /// @deprecated Use `sectionTitle` for new code
    static var sectionTitleSmall: Font { .system(size: 20, weight: .semibold) }
    /// @deprecated Use `cardTitle` for new code
    static var cardTitleSmall: Font { .system(size: 18, weight: .semibold) }
    /// @deprecated Use `bodyMain` for new code
    static var body: Font { .body }
    /// @deprecated Use `bodyMain` for new code
    static var bodyMedium: Font { .system(size: 16, weight: .medium) }
    /// @deprecated Use `bodySecondary` for new code
    static var secondary: Font { .subheadline }
    /// @deprecated Use `bodySecondary` for new code
    static var secondaryMedium: Font { .system(size: 15, weight: .medium) }
    /// @deprecated Use `bodySecondary` for new code
    static var secondarySmall: Font { .system(size: 14, weight: .regular) }
    /// @deprecated Use `labelCaps` or `labelMono` for new code
    static var caption: Font { .caption }
    /// @deprecated Use `labelCaps` for new code
    static var captionMedium: Font { .system(size: 13, weight: .medium) }
}

// MARK: - SwiftUI View Modifiers

/// Hero metrik stili: 64px Light, JetBrains Mono
struct HeroMetricModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.heroMetric)
    }
}

/// Plaka metin stili: 24px Bold JetBrains Mono, 3pt tracking
struct PlateTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.plateDisplay)
            .tracking(3)
    }
}

extension View {
    /// Hero metrik stili uygular (64px Light JetBrains Mono)
    func heroNumberStyle() -> some View {
        modifier(HeroMetricModifier())
    }

    /// Plaka metin stili uygular (24px Bold JetBrains Mono, 3pt tracking)
    func plateTextStyle() -> some View {
        modifier(PlateTextModifier())
    }
}
