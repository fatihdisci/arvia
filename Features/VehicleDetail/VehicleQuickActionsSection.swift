import SwiftUI

// MARK: - Daily Quick Actions
// 6 tile, 3 satır × 2 sütun — aksiyon odaklı label'lar ile.
// 2'li grid her butona yeterli yatay alan sağlar, kesilme olmaz.
struct VehicleQuickActionsSection: View {
    let onKmUpdate: () -> Void
    let onAddExpense: () -> Void
    let onAddFuelExpense: () -> Void
    let onAddDocument: () -> Void
    let onAddReminder: () -> Void
    let onAddInspection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Hızlı İşlemler")
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    vehicleDetailActionButton(icon: "gauge.with.needle", label: "Km Güncelle", color: AppColors.vehicle) {
                        onKmUpdate()
                    }
                    vehicleDetailActionButton(icon: "turkishlirasign.circle", label: "Masraf Ekle", color: AppColors.accentPrimary) {
                        onAddExpense()
                    }
                }
                HStack(spacing: 8) {
                    vehicleDetailActionButton(icon: "fuelpump", label: "Yakıt Ekle", color: AppColors.warning) {
                        onAddFuelExpense()
                    }
                    vehicleDetailActionButton(icon: "doc.text.viewfinder", label: "Belge Ekle", color: AppColors.document) {
                        onAddDocument()
                    }
                }
                HStack(spacing: 8) {
                    vehicleDetailActionButton(icon: "bell.badge", label: "Hatırlatıcı Ekle", color: AppColors.success) {
                        onAddReminder()
                    }
                    vehicleDetailActionButton(icon: "magnifyingglass", label: "Ekspertiz Ekle", color: AppColors.accentPrimary) {
                        onAddInspection()
                    }
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(height: 22)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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
