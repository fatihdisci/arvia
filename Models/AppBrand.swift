import Foundation

// MARK: - App Brand Constants
// Merkezi marka/branding sabitleri. Tüm kullanıcıya görünen marka metinleri
// bu dosya üzerinden referanslanır. App adı değişirse tek yerden güncellenir.

enum AppBrand {
    /// Uygulamanın görünen adı
    static let appName = "Arvia"

    /// Tagline / slogan
    static let tagline = "Aracına iyi bak."

    /// Bundle identifier (değişmez)
    static let bundleIdentifier = "com.ruhsatim.app"
}
