import SwiftUI

// MARK: - Border System
// "Cockpit Black" tasarımda gölge kullanılmaz.
// Derinlik, 1px turkuaz çerçeve ve tonal yüzey farkı ile sağlanır.
// Hero/elevated kartlarda üst kenarda hafif beyaz highlight olur.

enum AppShadows {
    // MARK: - ViewModifiers

    /// Hafif elevasyon — ince turkuaz çerçeve
    struct SubtleShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
        }
    }

    /// Kart elevasyonu — turkuaz çerçeve, kart radius'unda
    struct CardShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
        }
    }

    /// Yüksek elevasyon — turkuaz çerçeve + üst kenar highlight'ı
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
    /// Hafif elevasyonlu görünüm — ince turkuaz çerçeve
    func subtleShadow() -> some View {
        modifier(AppShadows.SubtleShadow())
    }

    /// Kart elevasyonlu görünüm — turkuaz çerçeve
    func cardShadow() -> some View {
        modifier(AppShadows.CardShadow())
    }

    /// Yüksek elevasyonlu görünüm — turkuaz çerçeve + üst highlight
    func elevatedShadow() -> some View {
        modifier(AppShadows.ElevatedShadow())
    }
}
