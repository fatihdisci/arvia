import Foundation
import Security

// MARK: - Anonymous AI Client ID
// Rastgele UUID, ilk kullanımda Keychain'e yazılır. Keychain reinstall'ı
// UserDefaults'tan daha iyi atlatır; kotaları anonim clientId ile eşler.
// Kişisel veri değildir — sadece rate-limit anahtarı.
enum AIClientID {
    private static let service = "com.arvia.ai.proxy"
    private static let account = "anonymous_client_id"

    static func current() -> String {
        if let existing = read() { return existing }
        let generated = UUID().uuidString
        save(generated)
        return generated
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    @discardableResult
    private static func save(_ value: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var attributes = base
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}
