import Foundation

// MARK: - App Environment
// Uygulama genelinde kullanılan çevre değişkenleri ve
// konfigürasyonların merkezi yönetimi.

enum AppEnvironment {
    static let appName = AppBrand.appName
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    // MARK: Feature flags
    // CloudKit private database sync.
    // ÖNEMLİ: Bu flag'i true yapmadan ÖNCE Xcode'da şunlar yapılmalı:
    //   1. Signing & Capabilities → + Capability → iCloud → CloudKit işaretle
    //   2. Container ekle: "iCloud.com.ruhsatim.app" (VehicleDossierApp.swift ile birebir aynı)
    //   3. Background Modes → Remote notifications aç (arka plan senkron itmesi için)
    // Capability eklenmeden flag açılırsa ModelContainer init başarısız olur (fatalError).
    static let isCloudKitSyncEnabled = true
    static let isPartnerVerificationEnabled = false
    static let isSupabaseEnabled = false
    static let isCommunityEnabled = true

    // MARK: Limits
    enum Free {
        static let maxVehicles = 1
        static let maxDocuments = 5
        static let maxSaleFileExports = 2
    }

    enum Pro {
        static let maxVehicles = Int.max
        static let maxDocuments = Int.max
        static let maxSaleFileExports = Int.max
    }
}
