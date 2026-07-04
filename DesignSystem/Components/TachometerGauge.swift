import SwiftUI

// MARK: - Tachometer Gauge
// İmza grafik: yarım daire "takometre yayı" — tam ring (Apple Fitness klonu) YASAK.
// Gerçek araç takometresi gibi: tik işaretleri + ibre + animasyonlu dolum.
// Kullanım: Dosya Skoru ve sağlık skorları (DossierCompletenessCard, FileCompletenessCard).
struct TachometerGauge: View {
    /// 0...1 arası doluluk.
    let value: CGFloat
    var accent: Color = AppColors.accentPrimary
    /// Genişlik (pt). Yükseklik otomatik: size/2 + hub payı.
    var size: CGFloat = 84

    @State private var animated: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var strokeWidth: CGFloat { size * 0.07 }
    private var radius: CGFloat { size / 2 - strokeWidth }
    private var hubPad: CGFloat { 8 }
    private var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }

    var body: some View {
        ZStack {
            // Arka plan yayı (silik track)
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(accent.opacity(0.14), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: size - strokeWidth * 2, height: size - strokeWidth * 2)
                .position(center)

            // Tik işaretleri — 5'lik minor, 25'lik major (takometre hissi)
            ForEach(0...20, id: \.self) { i in
                tick(at: CGFloat(i) / 20.0, isMajor: i % 5 == 0)
            }

            // Dolum yayı
            Circle()
                .trim(from: 0.5, to: 0.5 + animated * 0.5)
                .stroke(accent, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: size - strokeWidth * 2, height: size - strokeWidth * 2)
                .position(center)

            // İbre — hub'dan değere doğru
            Capsule()
                .fill(accent)
                .frame(width: 2, height: needleLength)
                .offset(y: -needleLength / 2)
                .rotationEffect(.degrees(Double(animated) * 180 - 90))
                .position(center)

            // Hub (ibre pimi)
            Circle()
                .fill(AppColors.surfaceSecondary)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(accent, lineWidth: 1.5))
                .position(center)
        }
        .frame(width: size, height: size / 2 + hubPad)
        .clipped()
        .onAppear { animate(to: value) }
        .onChange(of: value) { _, newValue in animate(to: newValue) }
        .accessibilityHidden(true)
    }

    // Tik: yayın hemen içinde, radyal yönde kısa çizgi.
    private func tick(at fraction: CGFloat, isMajor: Bool) -> some View {
        let angle = 180.0 + Double(fraction) * 180.0 // derece; y-aşağı koordinat
        let tickLength: CGFloat = isMajor ? size * 0.09 : size * 0.05
        let outerR = radius - strokeWidth - 2
        let midR = outerR - tickLength / 2
        let rad = angle * .pi / 180
        let x = center.x + cos(rad) * midR
        let y = center.y + sin(rad) * midR

        return Rectangle()
            .fill(isMajor ? AppColors.textSecondary : AppColors.textTertiary.opacity(0.55))
            .frame(width: isMajor ? 1.5 : 1, height: tickLength)
            .rotationEffect(.degrees(angle + 90))
            .position(x: x, y: y)
    }

    private var needleLength: CGFloat {
        radius - strokeWidth - size * 0.16
    }

    private func animate(to target: CGFloat) {
        let clamped = min(max(target, 0), 1)
        if reduceMotion {
            animated = clamped
        } else {
            withAnimation(.easeOut(duration: 0.8)) {
                animated = clamped
            }
        }
    }
}

// MARK: - Preview
#Preview("Tachometer — değerler") {
    VStack(spacing: 24) {
        TachometerGauge(value: 0.15, accent: AppColors.warning, size: 84)
        TachometerGauge(value: 0.55, accent: AppColors.accentPrimary, size: 84)
        TachometerGauge(value: 0.9, accent: AppColors.success, size: 84)
    }
    .padding()
    .background(Color.appBackground)
}
