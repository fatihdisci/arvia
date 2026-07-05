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
    let onScanReceipt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Hızlı İşlemler")
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: AppSpacing.xs) {
                // Row 1: Km Güncelle + Fiş/Fatura Tara (Pro rozetli)
                HStack(spacing: AppSpacing.xs) {
                    vehicleDetailActionButton(icon: "gauge.with.needle", label: "Km Güncelle", color: AppColors.vehicle) {
                        onKmUpdate()
                    }
                    vehicleDetailActionButton(
                        icon: "doc.viewfinder", label: "Fiş/Fatura Tara",
                        color: AppColors.accentPrimary,
                        showProBadge: !PaywallService.shared.canUseReceiptScan
                    ) {
                        onScanReceipt()
                    }
                }
                // Row 2: Masraf Ekle + Yakıt Ekle
                HStack(spacing: AppSpacing.xs) {
                    vehicleDetailActionButton(icon: "turkishlirasign.circle", label: "Masraf Ekle", color: AppColors.accentPrimary) {
                        onAddExpense()
                    }
                    vehicleDetailActionButton(icon: "fuelpump", label: "Yakıt Ekle", color: AppColors.warning) {
                        onAddFuelExpense()
                    }
                }
                // Row 3: Belge Ekle + Hatırlatıcı Ekle
                HStack(spacing: AppSpacing.xs) {
                    vehicleDetailActionButton(icon: "doc.text.viewfinder", label: "Belge Ekle", color: AppColors.document) {
                        onAddDocument()
                    }
                    vehicleDetailActionButton(icon: "bell.badge", label: "Hatırlatıcı Ekle", color: AppColors.success) {
                        onAddReminder()
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
        showProBadge: Bool = false,
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
            .overlay(alignment: .topTrailing) {
                if showProBadge {
                    Text("Pro")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppColors.textOnAccent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.accentPrimary))
                        .offset(x: 2, y: -4)
                }
            }
        }
        .buttonStyle(PlainCardButtonStyle())
        .accessibilityLabel(showProBadge ? "\(label), Pro" : label)
    }
}
