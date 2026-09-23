import Foundation
import Security

enum APIKeyStore {
    /// 钥匙串 service 名，故意停留在旧的 bundle ID 上。
    ///
    /// bundle ID 已改为 `xyz.phpz.app.linguadock`（去掉了 `mac` 一层），但这个
    /// 字符串只是钥匙串条目的查找键，改了会让已存的 API key 读不回来。除非补一
    /// 段迁移逻辑，否则保持原值。
    private static let service = "xyz.phpz.app.mac.linguadock"
    private static let legacyAccount = "translation-api-key"

    static func account(for provider: APIProvider) -> String {
        "translation-api-key.\(provider.rawValue)"
    }

    static func load(for provider: APIProvider) -> String {
        load(account: account(for: provider))
    }

    static func save(_ value: String, for provider: APIProvider) throws {
        let account = account(for: provider)
        let query = keychainQuery(account: account)

        if value.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }

        let attributes = [kSecValueData as String: Data(value.utf8)]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        guard updateStatus == errSecItemNotFound else {
            throw keychainError(updateStatus)
        }

        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw keychainError(addStatus)
        }
    }

    static func migrateLegacyKeyToOpenAICompatible() throws {
        let legacyValue = load(account: legacyAccount)
        guard !legacyValue.isEmpty else { return }

        if load(for: .openAICompatible).isEmpty {
            try save(legacyValue, for: .openAICompatible)
        }

        let status = SecItemDelete(keychainQuery(account: legacyAccount) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status)
        }
    }

    private static func load(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return "" }
        return value
    }

    private static func keychainQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func keychainError(_ status: OSStatus) -> NSError {
        NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [
                NSLocalizedDescriptionKey: String(
                    localized: "error.keychain.save",
                    defaultValue: "The API key couldn’t be saved to the Keychain (\(status))."
                )
            ]
        )
    }
}
