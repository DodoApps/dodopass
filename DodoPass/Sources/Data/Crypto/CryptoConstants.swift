import Foundation
import CryptoKit

/// Cryptographic constants used throughout the application.
/// These values follow current security best practices.
enum CryptoConstants {
    // MARK: - Key Derivation

    /// Number of PBKDF2 iterations for key derivation.
    /// 600,000 is recommended by OWASP for SHA-256 as of 2023.
    static let pbkdf2Iterations: Int = 600_000

    /// Salt length in bytes for PBKDF2.
    static let saltLength: Int = 32

    /// Derived key length in bytes (256 bits for AES-256).
    static let derivedKeyLength: Int = 32

    // MARK: - Encryption

    /// AES-GCM nonce/IV length in bytes.
    static let nonceLength: Int = 12

    /// AES-GCM authentication tag length in bytes.
    static let tagLength: Int = 16

    // MARK: - Vault Format

    /// Magic bytes identifying a DodoPass vault file.
    static let vaultMagic: Data = "DODO".data(using: .utf8)!

    /// Current vault format version.
    static let currentFormatVersion: UInt32 = 1

    /// File extension for vault files.
    static let vaultFileExtension: String = "vaultdb"

    /// Default vault filename.
    static let defaultVaultFilename: String = "DodoPass.vaultdb"

    // MARK: - HKDF Info Strings

    /// HKDF info for vault encryption key derivation.
    static let hkdfVaultKeyInfo: Data = "dodopass-vault-key".data(using: .utf8)!

    /// HKDF info for search index key derivation.
    static let hkdfSearchKeyInfo: Data = "dodopass-search-key".data(using: .utf8)!

    /// HKDF info for backup encryption key derivation.
    static let hkdfBackupKeyInfo: Data = "dodopass-backup-key".data(using: .utf8)!

    // MARK: - Keychain

    /// Keychain service identifier.
    static let keychainService: String = "com.dodopass.vault"

    /// Keychain account for the vault key.
    static let keychainVaultKeyAccount: String = "vault-master-key"

    // MARK: - Security Timeouts

    /// Auto-lock timeout in seconds (default: 5 minutes).
    static let defaultAutoLockTimeout: TimeInterval = 300

    /// Clipboard auto-clear timeout in seconds.
    static let clipboardClearTimeout: TimeInterval = 30

    // MARK: - Password Requirements

    /// Minimum master password length.
    static let minimumPasswordLength: Int = 8

    /// Recommended master password length.
    static let recommendedPasswordLength: Int = 16
}

// MARK: - Derived Key Purpose

/// Purposes for derived keys using HKDF.
enum DerivedKeyPurpose {
    case vaultEncryption
    case searchIndex
    case backup

    var info: Data {
        switch self {
        case .vaultEncryption:
            return CryptoConstants.hkdfVaultKeyInfo
        case .searchIndex:
            return CryptoConstants.hkdfSearchKeyInfo
        case .backup:
            return CryptoConstants.hkdfBackupKeyInfo
        }
    }
}
