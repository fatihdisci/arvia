import Foundation
import StoreKit
import SwiftUI

// MARK: - Paywall Service
// StoreKit 2 tabanlı abonelik yönetimi.
// MVP politikası: Arvia tek araç için ücretsiz ve reklamsızdır; Pro yalnızca ikinci ve sonraki araçlar içindir.
// App Store Connect yapılandırması olmadan dev mode'da UserDefaults ile çalışır.

@MainActor
final class PaywallService: ObservableObject {
    static let shared = PaywallService()

    @Published var isPro = false
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: String?

    enum FreeLimits {
        static let maxVehicles = 1
        static let documentLimit: Int? = nil
        static let saleFileRequiresPro = false
        static let advancedReportsRequiresPro = false
        static let inspectionReportsRequirePro = false
        static let receiptScanRequiresPro = true
    }

    // Ürün ID'leri — App Store Connect'te tanımlanmalı
    static let proProductIDs = [
        "com.ruhsatim.pro.monthly",
        "com.ruhsatim.pro.yearly",
        "com.ruhsatim.pro.lifetime",
    ]

    private let productIDs = PaywallService.proProductIDs

    // Dev mode: App Store Connect olmadan test için
    private let devModeKey = "paywall_dev_is_pro"

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Transaction listener
        updatesTask = Task {
            for await update in Transaction.updates {
                if let transaction = try? update.payloadValue {
                    await handleTransaction(transaction)
                }
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
    /// App Store Connect ürünleri tanımlanana kadar dev mode aktif.
    /// UserDefaults ile Pro durumunu simüle eder.
    var isDevMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

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
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Ürünler yüklenemedi."
        }
        isLoading = false
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async -> Bool {
        guard !isDevMode else {
            enableProForDev()
            return true
        }

        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = try? verification.payloadValue {
                    await handleTransaction(transaction)
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

        isLoading = false
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

        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            purchaseError = "Satın almalar geri yüklenemedi."
        }

        isLoading = false
    }

    // MARK: - Entitlements
    func checkEntitlements() async {
        guard !isDevMode else { return }

        var hasPro = false
        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? entitlement.payloadValue,
               productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                hasPro = true
                break
            }
        }
        isPro = hasPro
    }

    private func handleTransaction(_ transaction: StoreKit.Transaction) async {
        if productIDs.contains(transaction.productID),
           transaction.revocationDate == nil {
            isPro = true
        } else {
            isPro = false
        }
        await transaction.finish()
    }

    // MARK: - Limit Checks (MVP policy)
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
        !FreeLimits.saleFileRequiresPro || isPro
    }

    func canAccessAdvancedReports() -> Bool {
        !FreeLimits.advancedReportsRequiresPro || isPro
    }

    func canCreateInspectionReport() -> Bool {
        !FreeLimits.inspectionReportsRequirePro || isPro
    }

    var canUseReceiptScan: Bool {
        !FreeLimits.receiptScanRequiresPro || isPro
    }

    // Forum yazma artık Pro gerektirmez — auth yeterli.
    // Community gate'ler doğrudan CommunityAuthService üzerinden yapılır.

    // MARK: - Feature display
    static let freeFeatures: [(icon: String, title: String)] = [
        ("car", "1 araç"),
        ("doc.text", "Sınırsız belge"),
        ("bell", "Sınırsız hatırlatıcı"),
        ("wrench.and.screwdriver", "Masraf ve bakım kayıtları"),
        ("chart.bar", "Raporlar ve satış dosyası"),
    ]

    static let proFeatures: [(icon: String, title: String)] = [
        ("car.2", "Sınırsız araç"),
        ("wrench.and.screwdriver", "Araç bazlı bakım ve masraf geçmişi"),
        ("folder", "Araç bazlı belge kasası"),
        ("rectangle.grid.2x2", "Çoklu araç garajı"),
        ("bell.badge", "Tüm araçlar için hatırlatıcılar"),
    ]
}
