import Foundation
import Security
import LocalAuthentication

/// Service for securely storing and retrieving data from the Keychain.
final class KeychainService {
    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case unhandledError(status: OSStatus)
        case itemNotFound
        case duplicateItem
        case invalidData
        case authenticationFailed

        var errorDescription: String? {
            switch self {
            case .unhandledError(let status):
                if let message = SecCopyErrorMessageString(status, nil) {
                    return message as String
                }
                return "Keychain error: \(status)"
            case .itemNotFound:
                return "Item not found in Keychain"
            case .duplicateItem:
                return "Item already exists in Keychain"
            case .invalidData:
                return "Invalid data format"
            case .authenticationFailed:
                return "Authentication required to access Keychain"
            }
        }
    }

    // MARK: - Properties

    private let service: String
    private let accessGroup: String?

    // MARK: - Initialization

    init(
        service: String = CryptoConstants.keychainService,
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    // MARK: - Master Key Storage

    /// Stores the master key in the Keychain with biometric protection.
    /// - Parameter keyData: The master key data to store.
    func storeMasterKey(_ keyData: Data) throws {
        let account = CryptoConstants.keychainVaultKeyAccount

        // Delete existing item first
        try? deleteMasterKey()

        // Try to create access control with biometric requirement
        var error: Unmanaged<CFError>?
        let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,  // Use userPresence which allows biometrics OR passcode
            &error
        )

        // Build query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData
        ]

        // Add access control if available, otherwise use simpler accessibility
        if let accessControl = accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        AuditLogger.shared.log("Master key stored in Keychain", category: .security)
    }

    /// Retrieves the master key from the Keychain.
    /// - Returns: The master key data, or nil if not found.
    func retrieveMasterKey() throws -> Data? {
        let account = CryptoConstants.keychainVaultKeyAccount

        // Create LAContext for biometric prompt customization
        let context = LAContext()
        context.localizedReason = "Access your vault encryption key"

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        case errSecAuthFailed, errSecUserCanceled:
            throw KeychainError.authenticationFailed
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Deletes the master key from the Keychain.
    func deleteMasterKey() throws {
        let account = CryptoConstants.keychainVaultKeyAccount

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }

        AuditLogger.shared.log("Master key removed from Keychain", category: .security)
    }

    /// Checks if the master key exists in the Keychain.
    func hasMasterKey() -> Bool {
        let account = CryptoConstants.keychainVaultKeyAccount

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    // MARK: - Generic Storage

    /// Stores generic data in the Keychain.
    /// - Parameters:
    ///   - data: The data to store.
    ///   - account: The account identifier.
    ///   - requireBiometrics: Whether biometric authentication is required.
    func store(_ data: Data, forAccount account: String, requireBiometrics: Bool = false) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        if requireBiometrics {
            var error: Unmanaged<CFError>?
            guard let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                &error
            ) else {
                throw error?.takeRetainedValue() ?? KeychainError.unhandledError(status: errSecParam)
            }
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Delete existing item first
        try? delete(forAccount: account)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Retrieves data from the Keychain.
    /// - Parameter account: The account identifier.
    /// - Returns: The stored data, or nil if not found.
    func retrieve(forAccount account: String) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        case errSecAuthFailed, errSecUserCanceled:
            throw KeychainError.authenticationFailed
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Deletes data from the Keychain.
    /// - Parameter account: The account identifier.
    func delete(forAccount account: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Deletes all items for this service.
    func deleteAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }

        AuditLogger.shared.log("All Keychain items deleted", category: .security)
    }
}
