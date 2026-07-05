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
        case assistant

        var title: String {
            switch self {
            case .secondVehicle: return "Birden fazla aracı tek garajda yönet"
            case .documentLimit: return "Sınırsız belge kasası"
            case .saleFileExport: return "Sınırsız satış dosyası"
            case .advancedReports: return "Gelişmiş raporlar"
            case .inspectionReport: return "Ekspertiz raporları"
            case .receiptScan: return "Fiş ve faturaları tarayarak ekle"
            case .assistant: return "Akıllı Sürüş Asistanı — seni tanıyan öneriler"
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
            case .assistant: return "Pro ile kişiselleştirilmiş sürüş asistanı."
            }
        }
    }

    @State private var selectedProductId = "com.ruhsatim.pro.yearly" // Varsayılan: yıllık
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var currentPage = 0

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

                // Pro özellik karoseli — tüm özellikler arası geçiş
                proFeaturesCarousel
                    .padding(.horizontal, AppSpacing.screenMarginH)

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
        // Sheet yüksekliği: ekranın %85'i. Karosel + fiyat seçenekleri + CTA + yasal.
        .presentationDetents([.fraction(0.85)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Pro Highlight Features (Free'den farkı: sadece bu 3 özellik Pro'ya özel)
    private struct ProHighlight: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
    }

    private let proHighlights: [ProHighlight] = [
        ProHighlight(
            icon: "brain.head.profile",
            title: "Akıllı Sürüş Asistanı",
            description: "Sürüş alışkanlıklarını öğrenir, sana özel bakım planı oluşturur."
        ),
        ProHighlight(
            icon: "doc.viewfinder",
            title: "Fiş/Fatura Tarama",
            description: "Kamerayla tara, masrafın otomatik tanınsın. Tek tek girişe son."
        ),
        ProHighlight(
            icon: "car.2",
            title: "Sınırsız Araç",
            description: "Tüm araçlarını tek garajda yönet. Her birine özel dijital dosya."
        ),
    ]

    // MARK: - Pro Features Carousel (her sayfada tek özellik)
    private var proFeaturesCarousel: some View {
        VStack(spacing: AppSpacing.sm) {
            TabView(selection: $currentPage) {
                ForEach(Array(proHighlights.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: item.icon)
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(AppColors.accentPrimary)
                        Text(item.title)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(item.description)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.lg)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 140)

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<proHighlights.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? AppColors.accentPrimary : AppColors.border)
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
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
                Text("Akıllı asistan, fiş tarama, sınırsız araç ve daha fazlası.")
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