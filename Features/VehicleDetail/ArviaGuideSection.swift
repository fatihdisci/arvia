import SwiftUI

// MARK: - Arvia Rehber
struct ArviaGuideSection: View {
    let insights: [VehicleInsight]
    let vehicleId: UUID
    let onAction: (VehicleInsightAction) -> Void
    let onDismissInsight: (VehicleInsight) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Arvia Rehber")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Aracının kayıtlarına göre bakım, belge ve satış hazırlığı önerileri.")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if insights.isEmpty {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.seal")
                        .font(.body)
                        .foregroundColor(AppColors.success.opacity(0.7))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Şimdilik öne çıkan öneri yok")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Kayıt ekledikçe Arvia Rehber genel önerilerini burada günceller.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
            } else {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(insights.prefix(3)) { insight in
                        VehicleInsightCard(
                            insight: insight,
                            vehicleId: vehicleId,
                            onAction: { onAction($0) },
                            onDismiss: {
                                onDismissInsight(insight)
                            }
                        )
                    }
                }
            }

            arviaGuideDisclaimer
        }
    }

    private var arviaGuideDisclaimer: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
                .accessibilityHidden(true)
            Text("Arvia Rehber, araç kayıtlarına göre genel öneriler sunar.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
