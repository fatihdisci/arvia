import SwiftUI

// MARK: - Empty State View
// Design kuralı: Boş durum çıkmaz sokak değil.
// 1. Ne olmadığı açıkça söylenir.
// 2. Neden önemli olduğu anlatılır.
// 3. Tek net CTA verilir.
struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.textTertiary)
                .padding(.bottom, AppSpacing.xs)

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.sectionTitleSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(description)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(.primary)
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - Error State View
// Design kuralı: Hata mesajı formatı:
// 1. Ne oldu?
// 2. Kullanıcı ne yapabilir?
// 3. Veri kaybı var mı?
struct ErrorStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let retryTitle: LocalizedStringKey?
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?

    init(
        icon: String = "exclamationmark.triangle",
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        retryTitle: LocalizedStringKey? = nil,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppColors.warning)
                .padding(.bottom, AppSpacing.xs)

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.cardTitleSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            HStack(spacing: AppSpacing.md) {
                if let retryTitle, let retryAction {
                    Button(action: retryAction) {
                        Text(retryTitle)
                    }
                    .buttonStyle(.primary)
                }

                if let dismissAction {
                    Button(action: dismissAction) {
                        Text("Kapat")
                    }
                    .buttonStyle(.text)
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - Preview
#Preview("Boş Durum — Araç Yok") {
    EmptyStateView(
        icon: "car",
        title: "İlk aracının dosyasını oluşturalım",
        description: "Muayene, sigorta, bakım ve belgeleri tek yerde takip etmek için aracını ekle.",
        actionTitle: "Araç Ekle",
        action: {}
    )
}

#Preview("Hata Durumu — Ağ Hatası") {
    ErrorStateView(
        title: "Belge kaydedilemedi",
        message: "İnternet bağlantını kontrol edip tekrar deneyebilirsin. Seçtiğin dosya cihazından silinmedi.",
        retryTitle: "Tekrar Dene",
        retryAction: {},
        dismissAction: {}
    )
}

// MARK: - String + Sanitized Integer Input
extension String {
    /// Nokta ve virgülleri temizleyerek sadece rakamlardan oluşan
    /// bir metin döndürür. "192.000" → "192000", "1,500" → "1500"
    func sanitizedIntInput() -> String {
        trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
    }
}

#Preview("Boş Durum — Dark Mode") {
    EmptyStateView(
        icon: "doc.text",
        title: "Belgelerini burada saklayabilirsin",
        description: "Poliçe, muayene, ekspertiz ve faturaları aracının dijital dosyasına ekle.",
        actionTitle: "Belge Ekle",
        action: {}
    )
    .preferredColorScheme(.dark)
}
