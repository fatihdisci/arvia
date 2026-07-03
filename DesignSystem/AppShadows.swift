import SwiftUI

// MARK: - Border System
// Dark-only luxury tasarımda gölge kullanılmaz.
// Derinlik, 1px altın çerçeve ve tonal yüzey farkı ile sağlanır.
// Hero/elevated kartlarda üst kenarda hafif beyaz highlight olur.

enum AppShadows {
    // MARK: - ViewModifiers

    /// Hafif elevasyon — ince altın çerçeve
    struct SubtleShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
        }
    }

    /// Kart elevasyonu — altın çerçeve, kart radius'unda
    struct CardShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
        }
    }

    /// Yüksek elevasyon — altın çerçeve + üst kenar highlight'ı
    struct ElevatedShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.heroCard)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
                .overlay(
                    // Üst kenarda 1px physicial thickness hissi
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.white.opacity(0.05)),
                    alignment: .top
                )
        }
    }
}

extension View {
    /// Hafif elevasyonlu görünüm — ince altın çerçeve
    func subtleShadow() -> some View {
        modifier(AppShadows.SubtleShadow())
    }

    /// Kart elevasyonlu görünüm — altın çerçeve
    func cardShadow() -> some View {
        modifier(AppShadows.CardShadow())
    }

    /// Yüksek elevasyonlu görünüm — altın çerçeve + üst highlight
    func elevatedShadow() -> some View {
        modifier(AppShadows.ElevatedShadow())
    }
}
