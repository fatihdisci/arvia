import SwiftUI

// MARK: - Border System
// "Cockpit Black" tasarımda gölge kullanılmaz.
// Derinlik, 1px hairline çerçeve ve tonal yüzey farkı ile sağlanır.
// Hero/elevated kartlarda üst kenarda hafif beyaz highlight olur.

enum AppShadows {
    // MARK: - ViewModifiers

    /// Hafif elevasyon — ince hairline çerçeve
    struct SubtleShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
        }
    }

    /// Kart elevasyonu — hairline çerçeve, kart radius'unda
    struct CardShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
        }
    }

    /// Yüksek elevasyon — hairline çerçeve + üst kenar highlight'ı
    struct ElevatedShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.heroCard)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
                .overlay(
                    // Üst kenarda 1px physicial thickness hissi
                    // (saf siyah zeminde 0.05 yeterince okunmuyor → 0.08)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.white.opacity(0.08)),
                    alignment: .top
                )
        }
    }
}

extension View {
    /// Hafif elevasyonlu görünüm — ince hairline çerçeve
    func subtleShadow() -> some View {
        modifier(AppShadows.SubtleShadow())
    }

    /// Kart elevasyonlu görünüm — hairline çerçeve
    func cardShadow() -> some View {
        modifier(AppShadows.CardShadow())
    }

    /// Yüksek elevasyonlu görünüm — hairline çerçeve + üst highlight
    func elevatedShadow() -> some View {
        modifier(AppShadows.ElevatedShadow())
    }
}
