import SwiftUI

// MARK: - File Score Card
// Dosya Skoru gösterimi — tek yüzey (hero'daki inline indicator dışında).
// Outcome metni: kullanıcının ne kazanacağını söyleyen microcopy.
struct FileCompletenessCard: View {
    let vehicle: Vehicle
    let documents: [VehicleDocument]
    let fileScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Üst satır: takometre gauge + outcome metni
            HStack(alignment: .center, spacing: AppSpacing.md) {
                // İmza grafik: tik işaretli + ibreli takometre gauge
                TachometerGauge(
                    value: CGFloat(fileScore) / 100.0,
                    accent: scoreColor(fileScore),
                    size: 72
                )
                .accessibilityLabel("Dosya skoru yüzde \(fileScore)")

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Dosya Skoru")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Text(outcomeText(fileScore))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            // Chip'ler: Kimlik + Belge (Km hero'da zaten gösteriliyor).
            // Tamam = dolu tik + turkuaz; eksik = kesikli daire + nötr — durum tek bakışta ayrışır.
            HStack(spacing: AppSpacing.xs) {
                completenessChip(
                    icon: vehicle.year != nil ? "checkmark.circle.fill" : "circle.dashed",
                    label: "Kimlik",
                    isComplete: vehicle.year != nil
                )
                .accessibilityLabel(vehicle.year != nil ? "Kimlik tamamlandı" : "Kimlik eksik")

                completenessChip(
                    icon: !documents.isEmpty ? "checkmark.circle.fill" : "circle.dashed",
                    label: "Belge",
                    isComplete: !documents.isEmpty
                )
                .accessibilityLabel(!documents.isEmpty ? "Belge tamamlandı" : "Belge eksik")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func completenessChip(icon: String, label: String, isComplete: Bool) -> some View {
        Label(label, systemImage: icon)
            .font(AppTypography.captionMedium)
            .foregroundColor(isComplete ? AppColors.accentPrimary : AppColors.textTertiary)
            .lineLimit(1)
            .padding(.horizontal, AppSpacing.xs + 2)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isComplete ? AppColors.accentMuted : AppColors.textTertiary.opacity(0.07))
            )
            .overlay(
                Capsule()
                    .stroke(isComplete ? AppColors.accentPrimary.opacity(0.3) : AppColors.border, lineWidth: 0.5)
            )
    }

    // MARK: - Outcome Microcopy
    // Kullanıcının skor aralığına göre ne kazanacağını söyler.
    private func outcomeText(_ score: Int) -> String {
        if score >= 80 {
            return "Dosyan tamam — alıcı için güven dosyası oluşturabilirsin."
        }
        if score >= 60 {
            return "Son birkaç belge ile satışta değer kazandırabilirsin."
        }
        if score >= 30 {
            return "3-4 bilgi daha eklersen dosyan satışa hazır olur."
        }
        return "İlk belgeni ekle, dosyan şekillenmeye başlasın."
    }

    // Dosya Skoru renk semantiği: 80+ success, 30+ accentPrimary (turkuaz), <30 warning.
    // critical (#FF2D3C) yalnızca form hatası/gecikmiş reminder/destructive buton için.
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 30 { return AppColors.accentPrimary }
        return AppColors.warning
    }
}
