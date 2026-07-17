import SwiftUI

// MARK: - Pro Badge (Garaj Toolbar)
// Garaj ekranı toolbar'ında görünen kompakt "Pro" rozeti.
// Free kullanıcı için dikkat çekici (accent renk + boş taç), Pro kullanıcı için sade
// (secondary renk + dolu taç). Tıklanınca `ProIntroModal` açılır.
struct ProBadge: View {
    let isPro: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPro ? "crown.fill" : "crown")
                .font(.system(size: 10, weight: .bold))
            Text("Pro")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.5)
        }
        .foregroundColor(isPro ? AppColors.warning : AppColors.textOnAccent)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isPro
                      ? AppColors.backgroundSecondary
                      : AppColors.accentPrimary)
        )
        .overlay(
            Capsule()
                .stroke(isPro ? AppColors.warning.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Pro Intro Modal
// Garaj toolbar'ındaki Pro rozetinden açılan kompakt tanıtım modali.
// Gerçek Pro yetki politikasındaki özellikleri listeler.
// Free kullanıcıya satıra tıklayınca paywall açılır; Pro kullanıcıya doğrudan feature'a yönlendirilir.
// Modal `.medium` detent ile açılır — içerik kısa olduğu için büyük ekrana gerek yok,
// tab bar'ın üstünde kalması için alt padding'e güvenli alan eklenir.
struct ProIntroModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var paywallService: PaywallService

    let isPro: Bool
    /// Bir feature satırına tıklandığında çağrılır.
    /// Free → paywall açılır, Pro → ilgili yere yönlendirilir.
    /// Modal kapandıktan sonra parent sheet'in açılabilmesi için kısa gecikme
    /// (`asyncAfter`) uygulanır — aynı anda iki sheet çakışırsa iOS birini yutar.
    let onFeatureTap: (ProIntroModalFeature) -> Void
    /// Alttaki birincil CTA tıklandığında çağrılır (free ise paywall'a, Pro ise satış dosyası gibi başka bir yere yönlendirir).
    let onPrimaryAction: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.md) {
                headerSection
                featuresSection
                Spacer(minLength: 0)
                primaryActionSection
            }
            .padding(.horizontal, AppSpacing.screenMarginH)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header
    /// Üst kısım: ikon + başlık + alt başlık. Free / Pro'ya göre farklı metin.
    private var headerSection: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.accentPrimary.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: isPro ? "crown.fill" : "crown")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(isPro ? AppColors.warning : AppColors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isPro ? "Arvia Pro Aktif" : "Arvia Pro")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                Text(isPro ? "Tüm Pro özellikleri seni bekliyor." : "Aracın için fazlası.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Features
    /// 3 Pro özelliği — her satır buton; Free ise paywall, Pro ise feature'a yönlendirilir.
    private var featuresSection: some View {
        VStack(spacing: AppSpacing.xs) {
            ForEach(ProIntroModalFeature.allCases, id: \.self) { feature in
                Button {
                    onFeatureTap(feature)
                } label: {
                    featureRow(feature)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func featureRow(_ feature: ProIntroModalFeature) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(AppColors.accentPrimary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(feature.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(feature.subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: AppSpacing.sm)

            Image(systemName: isPro ? "arrow.right" : "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Primary Action
    /// Alt CTA — Free ise "Şimdi Pro'ya Geç" + altında "Satın Almaları Geri Yükle".
    /// Pro ise sadece bilgilendirme satırı.
    private var primaryActionSection: some View {
        VStack(spacing: AppSpacing.xs) {
            if isPro {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppColors.success)
                    Text("Pro üyeliğin aktif. İyi sürüşler.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
            } else {
                Button {
                    onPrimaryAction()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "crown.fill")
                        Text("Şimdi Pro'ya Geç")
                    }
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm + 2)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .fill(AppColors.accentPrimary)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await paywallService.restorePurchases() }
                } label: {
                    Text("Satın Almaları Geri Yükle")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Pro Intro Modal Feature
// Modalda listelenen gerçek Pro özellikleri.
enum ProIntroModalFeature: CaseIterable {
    case assistant
    case receiptScan
    case secondVehicle
    case saleFile
    case advancedReports

    var icon: String {
        switch self {
        case .assistant: return "steeringwheel"
        case .receiptScan: return "doc.viewfinder"
        case .secondVehicle: return "car.2"
        case .saleFile: return "doc.richtext"
        case .advancedReports: return "chart.xyaxis.line"
        }
    }

    var title: String {
        switch self {
        case .assistant: return "Akıllı Sürüş Asistanı"
        case .receiptScan: return "Fiş/Fatura Tarama"
        case .secondVehicle: return "Sınırsız Araç"
        case .saleFile: return "Satış Dosyası"
        case .advancedReports: return "Gelişmiş Raporlar"
        }
    }

    var subtitle: String {
        switch self {
        case .assistant: return "Kullanımına göre kişisel bakım önerileri."
        case .receiptScan: return "Fişleri fotoğrafla, masrafın saniyeler içinde eklensin."
        case .secondVehicle: return "İkinci, üçüncü aracını tek garajda yönet."
        case .saleFile: return "Araç geçmişini paylaşılabilir PDF'e dönüştür."
        case .advancedReports: return "Yıllık trend ve maliyet kırılımlarını gör."
        }
    }

    /// Deeplink için paywall feature. Yalnızca free kullanıcıda kullanılır.
    var paywallFeature: PaywallView.PaywallFeature {
        switch self {
        case .assistant: return .assistant
        case .receiptScan: return .receiptScan
        case .secondVehicle: return .secondVehicle
        case .saleFile: return .saleFileExport
        case .advancedReports: return .advancedReports
        }
    }
}
