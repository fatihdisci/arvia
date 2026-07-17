import SwiftUI

// MARK: - Goal Starter Card
// Onboarding'de seçilen önceliğe (primary_goal) göre ana ekranda gösterilen
// tek eylemli başlangıç kartı. "Bugün aracımla ilgili neyi bilmem gerekiyor?"
// sorusuna kullanıcının kendi amacıyla cevap verir.
//
// Veri-güdümlü: yalnızca ilgili boşluk varken (ör. amaç "masraf" ama henüz
// masraf kaydı yok) gösterilir; kullanıcı ilk kaydını ekleyince kendiliğinden
// kaybolur. Ayrıca elle kapatılabilir. Böylece gereksiz yere sürekli görünmez.

struct GoalStarterCard: View {
    let icon: String
    let title: String
    let message: String
    let ctaTitle: String
    let onCTA: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(AppColors.accentPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: AppSpacing.minimumTapTarget, height: AppSpacing.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kapat")
            }

            Button(action: onCTA) {
                Label(ctaTitle, systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.accentPrimary.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("GoalStarterCard") {
    VStack {
        GoalStarterCard(
            icon: "turkishlirasign.circle",
            title: "İlk masrafını kaydet",
            message: "Bir masraf ekle; aylık ve kategori bazlı özetin oluşmaya başlasın.",
            ctaTitle: "Masraf Ekle",
            onCTA: {},
            onDismiss: {}
        )
        .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.appBackground)
}
