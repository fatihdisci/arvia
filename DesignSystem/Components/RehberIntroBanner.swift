import SwiftUI

// MARK: - Rehber Intro Banner
// Faz 2.6 (Karar): Yeni kullanıcı ilk aracını ekledikten sonra
// Arvia Rehber'in ne işe yaradığını pasif banner ile açıklar.
// CTA yok. "Anlaşıldı" ile dismiss edilir, 7 gün boyunca gözükmez.
// Token-only, AI-slop uzak, dark luxury estetiği.

struct RehberIntroBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.body)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(AppColors.accentPrimary.opacity(0.12))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Arvia Rehber burada çalışıyor")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text("Aracın için yapılacakları, önemli tarihleri ve bakım hatırlatıcılarını sakin bir sırayla burada görürsün. İstediğinde kapatabilirsin.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Text("Anlaşıldı")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.accentPrimary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        Capsule().fill(AppColors.accentPrimary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rehber tanıtımını kapat")
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border.opacity(0.6), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview("Rehber Intro Banner") {
    RehberIntroBanner(onDismiss: {})
        .padding()
        .background(Color.appBackground)
}