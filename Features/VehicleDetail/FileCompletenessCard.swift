import SwiftUI

// MARK: - File Score Card
struct FileCompletenessCard: View {
    let vehicle: Vehicle
    let documents: [VehicleDocument]
    let fileScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .stroke(AppColors.border.opacity(0.70), lineWidth: 3.5)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: CGFloat(fileScore) / 100.0)
                        .stroke(AppColors.accentPrimary.opacity(0.75), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: fileScore)

                    Text("%\(fileScore)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Dosya Skoru")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Text(scoreDescription(fileScore))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: AppSpacing.xs) {
                completenessChip(icon: "car.fill", title: vehicle.year == nil ? "Yıl eksik" : "Kimlik tamam", isComplete: vehicle.year != nil)
                completenessChip(icon: "gauge.with.needle", title: vehicle.currentOdometer == 0 ? "Km eksik" : "Km var", isComplete: vehicle.currentOdometer > 0)
                completenessChip(icon: "doc.text", title: documents.isEmpty ? "Belge bekliyor" : "Belge var", isComplete: !documents.isEmpty)
            }
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

    private func completenessChip(icon: String, title: String, isComplete: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.captionMedium)
            .foregroundColor(isComplete ? AppColors.textSecondary : AppColors.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, AppSpacing.xs + 2)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill((isComplete ? AppColors.accentPrimary : AppColors.textTertiary).opacity(0.07))
            )
    }

    private func scoreDescription(_ score: Int) -> String {
        if score >= 80 { return "Aracının geçmişi iyi dokümante edilmiş." }
        if score >= 50 { return "Birkaç bilgi veya belge daha ekleyebilirsin." }
        return "Skoru yükseltmek için bilgi, hatırlatıcı ve belge ekle."
    }
}
