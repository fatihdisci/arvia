import Foundation
import Security

// MARK: - Legacy Anonymous AI Client ID Cleanup
// 1.0.1, kota anahtarı için Keychain'de rastgele bir kimlik tutuyordu.
// 1.1.0 kotaları doğrulanmış App Store hakkından türettiği için bu değer artık
// üretilmez veya gönderilmez; güncelleme sonrasında eski kayıt temizlenir.
enum AIClientID {
    private static let service = "com.arvia.ai.proxy"
    private static let account = "anonymous_client_id"

    static func removeLegacyIdentifier() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
