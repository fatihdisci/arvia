import Foundation
import StoreKit
import SwiftUI

// MARK: - Paywall Service
// StoreKit 2 tabanlı abonelik yönetimi.
// Ürün politikası için tek kaynak. Ekranlar kendi Pro/Free kuralını tanımlamaz;
// tüm kararlar bu servis üzerinden verilir.
// App Store Connect yapılandırması olmadan dev mode'da UserDefaults ile çalışır.

@MainActor
final class PaywallService: ObservableObject {
    static let shared = PaywallService()

    @Published var isPro = false
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: String?
    /// productID -> kullanıcının bu üründe intro offer'a (trial) hâlâ uygun olup olmadığı
    @Published var introOfferEligibility: [String: Bool] = [:]

    enum Feature: CaseIterable {
        case additionalVehicle
        case documentVault
        case saleFile
        case advancedReports
        case inspectionReport
        case receiptScan
        case assistant

        var requiresPro: Bool {
            switch self {
            case .additionalVehicle, .saleFile, .advancedReports, .receiptScan, .assistant:
                return true
            case .documentVault, .inspectionReport:
                return false
            }
        }
    }

    enum FreeLimits {
        static let maxVehicles = 1
        static let documentLimit: Int? = nil
    }

    // MARK: - Product IDs
    // Auto-Renewable Subscriptions (App Store Connect → Subscriptions grubu)
    nonisolated static let subscriptionProductIDs = [
        "com.arvia.pro.monthly",
        "com.arvia.pro.yearly",
    ]

    // Non-Consumable IAP (App Store Connect → In-App Purchases, "Tek Seferlik")
    nonisolated static let nonConsumableProductIDs = [
        "com.arvia.pro.lifetime",
    ]

    // StoreKit'ten yüklenecek ve entitlement kontrolünde kullanılacak birleşik set
    nonisolated static var allProProductIDs: [String] {
        subscriptionProductIDs + nonConsumableProductIDs
    }

    private let productIDs = PaywallService.allProProductIDs

    // Dev mode: App Store Connect olmadan test için
    private let devModeKey = "paywall_dev_is_pro"

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Transaction listener
        updatesTask = Task {
            for await update in Transaction.updates {
                if let transaction = try? update.payloadValue {
                    await transaction.finish()
                }
                // Tek bir iptal/iade işlemi başka geçerli bir Pro hakkını
                // geçersiz kılmamalı. Her güncellemede tüm hakları yeniden hesapla.
                await checkEntitlements()
            }
        }

        // Dev mode kontrolü
        if isDevMode {
            isPro = UserDefaults.standard.bool(forKey: devModeKey)
        } else {
            Task {
                await loadProducts()
                await checkEntitlements()
            }
        }
    }

    #if DEBUG
    init(isProForTesting: Bool) {
        self.isPro = isProForTesting
    }
    #endif

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Dev Mode
    /// DEBUG'ta dev mode varsayılan açık (UserDefaults ile Pro simülasyonu).
    /// `-DisableDevPaywall` launch argümanı ile kapatılır → gerçek StoreKit test edilir.
    var isDevMode: Bool {
        #if DEBUG
        return !ProcessInfo.processInfo.arguments.contains("-DisableDevPaywall")
        #else
        return false
        #endif
    }

    /// DEBUG'ta UserDefaults-backed Pro simülasyonu.
    /// `enableProForDev` / `disableProForDev` çağrıldığında dev mode anahtarını
    /// günceller; final `isPro` değeri StoreKit'ten gelir (production davranışı).
    func enableProForDev() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: devModeKey)
        isPro = true
        #endif
    }

    func disableProForDev() {
        #if DEBUG
        UserDefaults.standard.set(false, forKey: devModeKey)
        isPro = false
        #endif
    }

    // MARK: - Product Loading
    func loadProducts() async {
        guard !isDevMode else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
            await loadIntroOfferEligibility()
        } catch {
            purchaseError = "Ürünler yüklenemedi."
        }
    }

    /// Her abonelik ürünü için: tanımlı bir intro offer (trial) var mı VE kullanıcı hâlâ uygun mu.
    private func loadIntroOfferEligibility() async {
        var result: [String: Bool] = [:]
        for product in products {
            guard let subscription = product.subscription,
                  subscription.introductoryOffer != nil else { continue }
            result[product.id] = await subscription.isEligibleForIntroOffer
        }
        introOfferEligibility = result
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async -> Bool {
        guard !isDevMode else {
            enableProForDev()
            return true
        }

        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = try? verification.payloadValue {
                    await transaction.finish()
                    await checkEntitlements()
                    return true
                }
                purchaseError = "Satın alma doğrulanamadı."
            case .userCancelled:
                purchaseError = nil
            case .pending:
                purchaseError = "Ödeme bekleniyor."
            @unknown default:
                purchaseError = "Bilinmeyen hata."
            }
        } catch {
            purchaseError = error.localizedDescription
        }

        return false
    }

    // MARK: - Restore
    func restorePurchases() async {
        guard !isDevMode else {
            // Dev mode'da UserDefaults'tan oku
            isPro = UserDefaults.standard.bool(forKey: devModeKey)
            return
        }

        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            purchaseError = "Satın almalar geri yüklenemedi."
        }

    }

    // MARK: - Entitlements
    struct EntitlementState: Equatable {
        let productID: String
        let isRevoked: Bool
    }

    static func resolvesPro(from states: [EntitlementState]) -> Bool {
        states.contains { allProProductIDs.contains($0.productID) && !$0.isRevoked }
    }

    func checkEntitlements() async {
        guard !isDevMode else { return }

        var states: [EntitlementState] = []
        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? entitlement.payloadValue {
                states.append(EntitlementState(
                    productID: transaction.productID,
                    isRevoked: transaction.revocationDate != nil
                ))
            }
        }
        isPro = Self.resolvesPro(from: states)
    }

    // MARK: - Limit Checks (MVP policy)
    func canAccess(_ feature: Feature) -> Bool {
        !feature.requiresPro || isPro
    }

    func canAddVehicle(currentCount: Int) -> Bool {
        if isPro { return true }
        return currentCount < FreeLimits.maxVehicles
    }

    func canAddDocument(currentCount: Int) -> Bool {
        guard let documentLimit = FreeLimits.documentLimit else { return true }
        if isPro { return true }
        return currentCount < documentLimit
    }

    func canSaveNewDocument(currentCount: Int) -> Bool {
        canAddDocument(currentCount: currentCount)
    }

    func canCreateSaleFile() -> Bool {
        canAccess(.saleFile)
    }

    func canAccessAdvancedReports() -> Bool {
        canAccess(.advancedReports)
    }

    func canCreateInspectionReport() -> Bool {
        canAccess(.inspectionReport)
    }

    var canUseReceiptScan: Bool {
        canAccess(.receiptScan)
    }

    var canUseAssistant: Bool {
        canAccess(.assistant)
    }

    // MARK: - Feature display
    static let freeFeatures: [(icon: String, title: String)] = [
        ("car", "1 araç"),
        ("doc.text", "Sınırsız belge"),
        ("bell", "Sınırsız hatırlatıcı"),
        ("wrench.and.screwdriver", "Masraf ve bakım kayıtları"),
        ("chart.bar", "Temel araç özeti"),
    ]

    static let proFeatures: [(icon: String, title: String)] = [
        ("steeringwheel", "Akıllı Sürüş Asistanı — seni tanıyan öneriler"),
        ("doc.viewfinder", "Fiş/Fatura Tarama"),
        ("car.2", "Sınırsız araç"),
        ("doc.richtext", "Satış dosyası ve gelişmiş raporlar"),
        ("bell.badge", "Tüm araçlar için kayıt ve hatırlatıcılar"),
    ]
}
