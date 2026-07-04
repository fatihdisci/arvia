import SwiftUI

// MARK: - Sale File Preview Card
/// Satış Dosyası önizleme kartı.
/// Güvenli dil: Mekanik/hukuki garanti ima etmez.
struct SaleFilePreviewCard: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.success.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.richtext")
                        .font(.title3)
                        .foregroundColor(AppColors.success)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Satış Dosyası")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Bakım, belge ve ekspertiz kayıtlarından güven dosyası oluştur.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(Color.appSurface)
            )
            .subtleShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Satış Dosyası — Bakım, belge ve ekspertiz kayıtlarından güven dosyası oluştur.")
        .accessibilityHint("Satış dosyası oluşturmak için çift tıkla")
    }
}
