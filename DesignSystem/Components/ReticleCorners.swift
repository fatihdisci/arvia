import SwiftUI

// MARK: - Reticle Corners
// İmza grafik: köşe ayraç/nişangah motifi ("⌐" köşe işaretleri).
// Araç fotoğrafı çevresinde ve tarama/fotoğraf çekme aksiyonlarında kullanılır —
// hedefleme/enstrüman hissi. Dekoratif değil: "bu alan aracın görsel kimliği" der.
struct ReticleCorners: Shape {
    /// Her köşe kolunun uzunluğu.
    var length: CGFloat = 16
    /// Kenarlardan içeri çekilme.
    var inset: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.insetBy(dx: inset, dy: inset)

        // Sol üst
        p.move(to: CGPoint(x: r.minX, y: r.minY + length))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + length, y: r.minY))
        // Sağ üst
        p.move(to: CGPoint(x: r.maxX - length, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + length))
        // Sağ alt
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - length))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - length, y: r.maxY))
        // Sol alt
        p.move(to: CGPoint(x: r.minX + length, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - length))

        return p
    }
}

extension View {
    /// Köşe ayraç/reticle overlay'i — araç fotoğrafı ve tarama alanları için imza motif.
    func reticleCorners(
        color: Color = AppColors.accentPrimary.opacity(0.8),
        length: CGFloat = 16,
        inset: CGFloat = 10,
        lineWidth: CGFloat = 1.5
    ) -> some View {
        overlay(
            ReticleCorners(length: length, inset: inset)
                .stroke(color, lineWidth: lineWidth)
                .accessibilityHidden(true)
        )
    }
}

// MARK: - Preview
#Preview("Reticle — foto çerçevesi") {
    RoundedRectangle(cornerRadius: AppRadius.heroCard)
        .fill(AppColors.surfacePrimary)
        .frame(width: 320, height: 180)
        .reticleCorners()
        .padding()
        .background(Color.appBackground)
}
