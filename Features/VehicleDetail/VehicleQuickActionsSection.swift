import SwiftUI

// MARK: - Daily Quick Actions
struct VehicleQuickActionsSection: View {
    let onKmUpdate: () -> Void
    let onAddExpense: () -> Void
    let onAddFuelExpense: () -> Void
    let onAddDocument: () -> Void
    let onAddReminder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Hızlı İşlemler")
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                vehicleDetailActionButton(icon: "gauge.with.needle", label: "Km", color: AppColors.vehicle) {
                    onKmUpdate()
                }
                vehicleDetailActionButton(icon: "turkishlirasign.circle", label: "Masraf", color: AppColors.accentPrimary) {
                    onAddExpense()
                }
                vehicleDetailActionButton(icon: "fuelpump", label: "Yakıt", color: AppColors.warning) {
                    onAddFuelExpense()
                }
                vehicleDetailActionButton(icon: "doc.text.viewfinder", label: "Belge", color: AppColors.document) {
                    onAddDocument()
                }
                vehicleDetailActionButton(icon: "bell.badge", label: "Hatırlatıcı", color: AppColors.success) {
                    onAddReminder()
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func vehicleDetailActionButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                    .frame(height: 24)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColors.backgroundSecondary.opacity(0.65))
            )
        }
        .buttonStyle(PlainCardButtonStyle())
        .accessibilityLabel(label)
    }
}
