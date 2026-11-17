import Foundation
import Security

enum APIKeyStore {
    private static let service = "xyz.phpz.app.linguadock"
    private static let legacyService = "xyz.phpz.app.mac.linguadock"
    private static let legacyAccount = "translation-api-key"

    static func account(for provider: APIProvider) -> String {
        "translation-api-key.\(provider.rawValue)"
    }

    static func load(for provider: APIProvider) -> String {
        load(account: account(for: provider))
    }

    static func save(_ value: String, for provider: APIProvider) throws {
        try save(value, account: account(for: provider))
    }

    static func save(_ value: String, account: String) throws {
        let query = keychainQuery(account: account)

        if value.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw keychainError(status) }
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: legacyService,
                kSecAttrAccount as String: account,
            ]
            let legacyStatus = SecItemDelete(legacyQuery as CFDictionary)
            guard legacyStatus == errSecSuccess || legacyStatus == errSecItemNotFound else { throw keychainError(legacyStatus) }
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
        try migrateLegacyService()
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

    static func load(account: String) -> String {
        // If a protected legacy item could not be renamed, keep it readable
        // rather than silently treating the credential as absent.
        read(account: account, service: service) ?? read(account: account, service: legacyService) ?? ""
    }

    private static func read(account: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func migrateLegacyService() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return }
        guard status == errSecSuccess else { throw keychainError(status) }
        guard let items = result as? [[String: Any]] else { throw keychainError(errSecInternalError) }
        let accounts = try items.map { item -> String in
            guard let account = item[kSecAttrAccount as String] as? String else { throw keychainError(errSecInternalError) }
            return account
        }
        try KeychainServiceMigration.run(accounts: accounts) { account in
            let item: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: legacyService,
                kSecAttrAccount as String: account,
            ]
            return SecItemUpdate(item as CFDictionary, [kSecAttrService as String: service] as CFDictionary)
        }
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

/// Injectable credentials keep configuration persistence testable without reading a user's Keychain.
@MainActor
struct ModelKeyStore {
    var load: (String) -> String
    var save: (String, String) throws -> Void
    var migrate: () throws -> Void

    static let keychain = ModelKeyStore(
        load: { APIKeyStore.load(account: $0) },
        save: { try APIKeyStore.save($0, account: $1) },
        migrate: { try APIKeyStore.migrateLegacyKeyToOpenAICompatible() }
    )
}

/// Renaming an item preserves its value and access controls. A collision or
/// locked Keychain stops the migration without deleting either item.
enum KeychainServiceMigration {
    static func run(accounts: [String], rename: (String) -> OSStatus) throws {
        for account in accounts {
            let status = rename(account)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "error.keychain.save", defaultValue: "The Keychain migration could not be completed (\(status)).")
                ])
            }
        }
    }
}
