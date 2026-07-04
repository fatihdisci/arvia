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
// Apple Review uyumlu kompakt paywall.
// İlk ekranda (scroll olmadan) görünmesi gerekenler:
//   - Fiyat seçenekleri (3 plan)
//   - Satın al / Pro'ya Geç CTA
//   - Restore Purchases
//   - Privacy Policy + Terms + EULA + Destek linkleri
//   - Otomatik yenileme açıklaması
// Etik freemium: dark pattern yok, fiyat net, koşullar görünür.

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var paywallService: PaywallService

    let feature: PaywallFeature

    enum PaywallFeature {
        case secondVehicle
        case documentLimit
        case saleFileExport
        case advancedReports
        case inspectionReport
        case receiptScan

        var title: String {
            switch self {
            case .secondVehicle: return "Birden fazla aracı tek garajda yönet"
            case .documentLimit: return "Sınırsız belge kasası"
            case .saleFileExport: return "Sınırsız satış dosyası"
            case .advancedReports: return "Gelişmiş raporlar"
            case .inspectionReport: return "Ekspertiz raporları"
            case .receiptScan: return "Fiş ve faturaları tarayarak ekle"
            }
        }

        var shortPitch: String {
            switch self {
            case .secondVehicle: return "Pro ile sınırsız araç ekle."
            case .documentLimit: return "Pro ile sınırsız belge."
            case .saleFileExport: return "Pro ile sınırsız satış dosyası."
            case .advancedReports: return "Pro ile gelişmiş raporlar."
            case .inspectionReport: return "Pro ile sınırsız ekspertiz."
            case .receiptScan: return "Pro ile fiş/fatura tarama."
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
                badge: product.subscription?.subscriptionPeriod.unit == .year ? "En Avantajlı"
                     : (product.type == .nonConsumable ? "Tek Seferlik" : nil),
                sortOrder: product.subscription?.subscriptionPeriod.unit == .month ? 0
                         : (product.subscription?.subscriptionPeriod.unit == .year ? 1 : 2)
            )
        }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private let privacyURL = URL(string: "https://fatihdisci.github.io/arvia/privacy.html")!
    private let termsURL = URL(string: "https://fatihdisci.github.io/arvia/terms.html")!
    private let supportURL = URL(string: "https://fatihdisci.github.io/arvia/support.html")!
    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: - Body (scroll'suz, her şey ilk ekranda)
    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.sm) {
                // Üst — kompakt hero
                heroCompact
                    .padding(.top, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.xs)

                // Orta — fiyatlar + CTA + yasal (scroll gerektirmeyen içerik)
                VStack(spacing: AppSpacing.sm) {
                    pricingSection
                    ctaSection
                    restoreAndLegalSection
                    autoRenewalDisclosure
                }
                .padding(.horizontal, AppSpacing.screenMarginH)

                Spacer(minLength: 0)
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
        // Sheet yüksekliği: ekranın %65'i (~555pt). Tek detent — swipe kapalı.
        // Pro özellikleri arttıkça fraction büyütülür.
        .presentationDetents([.fraction(0.65)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Compact Hero (80pt)
    private var heroCompact: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.accentPrimary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.accentPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Arvia Pro")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text(feature.shortPitch)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Pricing (3 plan, kompakt kartlar)
    private var pricingSection: some View {
        VStack(spacing: AppSpacing.xs) {
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
                .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
                .cardShadow()
            } else {
                ForEach(pricingOptions) { option in
                    pricingRow(option, isSelected: selectedProductId == option.id)
                }
            }
        }
    }

    private func pricingRow(_ option: PricingOption, isSelected: Bool) -> some View {
        Button {
            selectedProductId = option.id
        } label: {
            HStack(spacing: AppSpacing.sm) {
                // Radio indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.accentPrimary : AppColors.border, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(AppColors.accentPrimary)
                            .frame(width: 10, height: 10)
                    }
                }
                .accessibilityHidden(true)

                // Title + badge
                HStack(spacing: AppSpacing.xxs) {
                    Text(option.title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    if let badge = option.badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppColors.textOnAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(AppColors.accentPrimary)
                            )
                    }
                }

                Spacer()

                // Price + period
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(option.price)
                        .font(AppTypography.amountMd)
                        .foregroundColor(AppColors.textPrimary)
                    if !option.period.isEmpty {
                        Text(option.period)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(isSelected ? AppColors.accentPrimary : AppColors.border, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(option.title), \(option.price)\(option.period.isEmpty ? "" : option.period)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - CTA
    private var ctaSection: some View {
        Button {
            performPurchase()
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView().tint(AppColors.textOnAccent)
                }
                Text(isPurchasing ? "İşlem yapılıyor..." : "Pro'ya Geç")
                    .font(AppTypography.bodyMedium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.minimumTapTarget + 8)
        }
        .buttonStyle(.primary)
        .disabled(isPurchasing || isRestoring || pricingOptions.isEmpty)
    }

    // MARK: - Restore + Legal (compact, 2 satır)
    private var restoreAndLegalSection: some View {
        VStack(spacing: AppSpacing.xs) {
            // Yasal linkler — tek satırda 4 link
            HStack(spacing: AppSpacing.xs) {
                linkButton("Gizlilik", url: privacyURL)
                bulletDot
                linkButton("Koşullar", url: termsURL)
                bulletDot
                linkButton("EULA", url: eulaURL)
                bulletDot
                linkButton("Destek", url: supportURL)
            }

            // Restore Purchases — Apple zorunlu
            Button {
                performRestore()
            } label: {
                HStack(spacing: 4) {
                    if isRestoring {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isRestoring ? "Kontrol ediliyor..." : "Satın Almaları Geri Yükle")
                        .underline()
                }
                .font(AppTypography.caption)
                .foregroundColor(AppColors.accentPrimary)
            }
            .disabled(isPurchasing || isRestoring)
            .padding(.top, AppSpacing.xxs)
        }
        .frame(maxWidth: .infinity)
    }

    private func linkButton(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .underline()
        }
    }

    private var bulletDot: some View {
        Text("•")
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textTertiary)
    }

    // MARK: - Auto-Renewal Disclosure (Apple zorunlu, kısa)
    private var autoRenewalDisclosure: some View {
        Text("Otomatik yenilenen abonelik. Satın alma onayından sonra ödeme Apple Hesabına yansıtılır. Cari dönem bitmeden en az 24 saat kala iptal etmezsen abonelik otomatik yenilenir. İstediğin zaman iptal edebilirsin.")
            .font(.system(size: 10))
            .foregroundColor(AppColors.textTertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, AppSpacing.xxs)
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

#Preview("Paywall — Belge") {
    PaywallView(feature: .documentLimit)
        .environmentObject(PaywallService.shared)
}