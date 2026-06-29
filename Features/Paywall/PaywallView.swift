import SwiftUI
import StoreKit

// MARK: - SubscriptionPeriod Display Helper
extension Product.SubscriptionPeriod {
    var periodDisplay: String {
        let unitStr: String
        switch unit {
        case .day: unitStr = "gün"
        case .week: unitStr = "hafta"
        case .month: unitStr = "ay"
        case .year: unitStr = "yıl"
        @unknown default: unitStr = ""
        }
        if value == 1 {
            return "/\(unitStr)"
        }
        return "/\(value) \(unitStr)"
    }
}

// MARK: - Paywall View
// Etik freemium paywall. Karanlık desen yok.
// Değer anlarında gösterilir, ilk açılışta değil.
// Düzen: kritik öğeler (fiyat, CTA, restore, terms, privacy) ilk ekranda.

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var paywallService: PaywallService

    let feature: PaywallFeature

    enum PaywallFeature {
        case secondVehicle
        case documentLimit
        case saleFile
        case advancedReports
        case inspectionArchive

        var title: String {
            switch self {
            case .secondVehicle: return "İkinci Aracını da Ekle"
            case .documentLimit: return "Belge Limitini Kaldır"
            case .saleFile: return "Satış Dosyası Oluştur"
            case .advancedReports: return "Gelişmiş Raporlar"
            case .inspectionArchive: return "Ekspertiz Arşivi"
            }
        }

        var description: String {
            switch self {
            case .secondVehicle:
                return "Birden fazla aracın varsa hepsini tek yerden takip et."
            case .documentLimit:
                return "Poliçe, fatura ve ekspertiz raporlarını sınırsız sakla."
            case .saleFile:
                return "Aracının eksiksiz satış dosyasını PDF olarak oluştur ve paylaş."
            case .advancedReports:
                return "Yıllık trend, araç karşılaştırma ve detaylı maliyet analizi."
            case .inspectionArchive:
                return "Ekspertiz raporlarını arşivle ve satış dosyana dahil et."
            }
        }
    }

    @State private var selectedProductId = "com.ruhsatim.pro.yearly" // Varsayılan: yıllık
    @State private var isPurchasing = false
    @State private var isRestoring = false

    // MARK: - Pricing Options (StoreKit veya dev mode fallback)
    struct PricingOption: Identifiable {
        let id: String // product ID
        let title: String
        let price: String
        let period: String
        let badge: String?
        let sortOrder: Int
    }

    private var pricingOptions: [PricingOption] {
        if paywallService.products.isEmpty {
            #if DEBUG
            // Dev mode fallback — ürün ID'lerine göre sıralı
            return [
                PricingOption(id: "com.ruhsatim.pro.monthly", title: "Aylık", price: "₺79,99", period: "/ay", badge: nil, sortOrder: 0),
                PricingOption(id: "com.ruhsatim.pro.yearly", title: "Yıllık", price: "₺599,99", period: "/yıl", badge: "En Avantajlı", sortOrder: 1),
                PricingOption(id: "com.ruhsatim.pro.lifetime", title: "Ömür Boyu", price: "₺1.499,99", period: "", badge: "Tek Seferlik", sortOrder: 2),
            ]
            #else
            return []
            #endif
        }
        return paywallService.products.map { product in
            PricingOption(
                id: product.id,
                title: product.displayName,
                price: product.displayPrice,
                period: product.subscription?.subscriptionPeriod.periodDisplay ?? "",
                badge: product.id.contains("yearly") ? "En Avantajlı"
                     : (product.id.contains("lifetime") ? "Tek Seferlik" : nil),
                sortOrder: product.id.contains("monthly") ? 0
                         : (product.id.contains("yearly") ? 1 : 2)
            )
        }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private let privacyURL = URL(string: "https://fatihdisci.github.io/arvia/privacy.html")!
    private let termsURL = URL(string: "https://fatihdisci.github.io/arvia/terms.html")!
    private let supportURL = URL(string: "https://fatihdisci.github.io/arvia/support.html")!
    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Kompakt hero
                    heroSection

                    // Fiyatlandırma — ilk ekranda görünür
                    pricingSection

                    // CTA
                    ctaSection

                    // Geri yükle + yasal linkler + güven — ilk ekranda görünür
                    restoreAndLegalSection
                    trustSection

                    // Aşağıda: Pro özellik listesi
                    proBenefits

                    // Aşağıda: Free/Pro karşılaştırması
                    planComparison
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("Pro'ya Geç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.vehicle, AppColors.accentPrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)

                // Dark mode scrim: gradyan kartın koyulaşmasını ve metin okunabilirliğini artırır
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .fill(Color.black.opacity(0.35))
                        .frame(height: 100)
                }

                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.9))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text(feature.description)
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
            .padding(.horizontal, AppSpacing.screenMarginH)
        }
    }

    // MARK: - Benefits (aşağıda, scroll ile)
    private var proBenefits: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Pro ile Gelenler")

            VStack(spacing: 0) {
                ForEach(PaywallService.proFeatures, id: \.title) { feature in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: feature.icon)
                            .font(.body)
                            .foregroundColor(AppColors.accentPrimary)
                            .frame(width: 28)

                        Text(feature.title)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(AppColors.success)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)

                    if feature.title != PaywallService.proFeatures.last?.title {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(Color.appSurface)
            )
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }



    // MARK: - Free / Pro Comparison (aşağıda, scroll ile)
    private var planComparison: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Free ve Pro")

            HStack(alignment: .top, spacing: AppSpacing.sm) {
                planColumn(title: "Free", features: PaywallService.freeFeatures, accent: AppColors.textSecondary)
                planColumn(title: "Pro", features: PaywallService.proFeatures, accent: AppColors.accentPrimary)
            }
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func planColumn(title: String, features: [(icon: String, title: String)], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundColor(accent)

            ForEach(features, id: \.title) { feature in
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: feature.icon)
                        .font(.caption)
                        .foregroundColor(accent)
                        .frame(width: 16)
                    Text(feature.title)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(AppSpacing.sm)
        .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
    }


    // MARK: - Pricing (ilk ekranda)
    private var pricingSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(title: "Plan Seç")

            VStack(spacing: AppSpacing.sm) {
                if pricingOptions.isEmpty {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(AppColors.warning)
                        Text("Fiyat bilgisi yüklenemedi.")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Lütfen tekrar dene.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.md)
                    .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
                } else {
                    ForEach(pricingOptions) { option in
                        pricingOption(option, isSelected: selectedProductId == option.id)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func pricingOption(_ option: PricingOption, isSelected: Bool) -> some View {
        Button {
            selectedProductId = option.id
        } label: {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppSpacing.xxs) {
                        Text(option.title)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)

                        if let badge = option.badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(AppColors.success)
                                .padding(.horizontal, AppSpacing.xxs)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(AppColors.successBackground)
                                )
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(option.price)
                            .font(AppTypography.amount)
                            .foregroundColor(AppColors.textPrimary)
                        if !option.period.isEmpty {
                            Text(option.period)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.accentPrimary : AppColors.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(AppColors.accentPrimary)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(isSelected ? AppColors.accentPrimary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA (ilk ekranda)
    private var ctaSection: some View {
        Button {
            performPurchase()
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView().tint(.white)
                }
                Text(isPurchasing ? "İşlem yapılıyor..." : "Pro'ya Geç")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary)
        .disabled(isPurchasing || isRestoring || pricingOptions.isEmpty)
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Restore + Yasal Linkler (ilk ekranda)
    private var restoreAndLegalSection: some View {
        VStack(spacing: AppSpacing.sm) {
            // Satın almaları geri yükle
            Button {
                performRestore()
            } label: {
                HStack {
                    if isRestoring {
                        ProgressView()
                    }
                    Text(isRestoring ? "Kontrol ediliyor..." : "Satın Almaları Geri Yükle")
                }
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.accentPrimary)
            }
            .disabled(isPurchasing || isRestoring)

            // Yasal linkler
            HStack(spacing: AppSpacing.sm) {
                Link(destination: privacyURL) {
                    Text("Gizlilik Politikası")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Text("•")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)

                Link(destination: termsURL) {
                    Text("Kullanım Koşulları")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Text("•")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)

                Link(destination: supportURL) {
                    Text("Destek")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Text("•")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)

                Link(destination: eulaURL) {
                    Text("Apple EULA")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Trust (ilk ekranda, yasal linklerin hemen altında)
    private var trustSection: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("İstediğin zaman iptal edebilirsin.")
            }
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondary)

            Text("Bu otomatik yenilenen aboneliktir. Satın alma onayından sonra ödeme Apple Hesabına yansıtılır. Cari dönem bitmeden en az 24 saat kala iptal etmezsen abonelik otomatik olarak yenilenir. Satın alımlar Apple hesabın üzerinden yönetilir. Kullanmadığın süre için ücret iadesi Apple politikalarına tabidir.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xxl)
        }
    }

    // MARK: - Actions
    private func performPurchase() {
        guard !paywallService.isDevMode else {
            paywallService.enableProForDev()
            dismiss()
            return
        }

        guard !pricingOptions.isEmpty,
              let product = paywallService.products.first(where: { $0.id == selectedProductId }) else {
            paywallService.purchaseError = "Ürün bulunamadı."
            return
        }

        isPurchasing = true
        Task {
            let success = await paywallService.purchase(product)
            await MainActor.run {
                isPurchasing = false
                if success {
                    dismiss()
                }
            }
        }
    }

    private func performRestore() {
        isRestoring = true
        Task {
            await paywallService.restorePurchases()
            await MainActor.run {
                isRestoring = false
                if paywallService.isPro {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Paywall — 2. Araç") {
    PaywallView(feature: .secondVehicle)
        .environmentObject(PaywallService.shared)
}
