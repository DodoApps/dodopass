import Foundation
import CryptoKit

/// Service responsible for all cryptographic operations in the vault.
actor CryptoService {
    // MARK: - Errors

    enum CryptoError: LocalizedError {
        case encryptionFailed(underlying: Error?)
        case decryptionFailed(underlying: Error?)
        case invalidKey
        case invalidData
        case authenticationFailed
        case keyDerivationFailed(underlying: Error?)

        var errorDescription: String? {
            switch self {
            case .encryptionFailed(let error):
                return "Encryption failed: \(error?.localizedDescription ?? "Unknown error")"
            case .decryptionFailed(let error):
                return "Decryption failed: \(error?.localizedDescription ?? "Unknown error")"
            case .invalidKey:
                return "Invalid encryption key"
            case .invalidData:
                return "Invalid data for cryptographic operation"
            case .authenticationFailed:
                return "Data authentication failed - data may be corrupted or tampered with"
            case .keyDerivationFailed(let error):
                return "Key derivation failed: \(error?.localizedDescription ?? "Unknown error")"
            }
        }
    }

    // MARK: - Properties

    private var masterKey: SecureKey?
    private var vaultKey: SymmetricKey?
    private var searchKey: SymmetricKey?

    // MARK: - Initialization

    init() {}

    // MARK: - Key Management

    /// Derives and stores keys from the master password.
    /// - Parameters:
    ///   - password: The user's master password.
    ///   - salt: The salt for key derivation.
    /// - Throws: `CryptoError.keyDerivationFailed` if derivation fails.
    func deriveKeys(from password: String, salt: Data) async throws {
        do {
            let master = try KeyDerivation.deriveKey(from: password, salt: salt)
            masterKey = SecureKey(master)
            vaultKey = KeyDerivation.deriveSubkey(from: master, for: .vaultEncryption)
            searchKey = KeyDerivation.deriveSubkey(from: master, for: .searchIndex)
        } catch {
            throw CryptoError.keyDerivationFailed(underlying: error)
        }
    }

    /// Sets the master key directly (used when restoring from Keychain).
    /// - Parameter key: The master key data.
    func setMasterKey(_ keyData: Data) {
        let key = SymmetricKey(data: keyData)
        masterKey = SecureKey(key)
        vaultKey = KeyDerivation.deriveSubkey(from: key, for: .vaultEncryption)
        searchKey = KeyDerivation.deriveSubkey(from: key, for: .searchIndex)
    }

    /// Clears all keys from memory.
    func clearKeys() {
        masterKey?.clear()
        masterKey = nil
        vaultKey = nil
        searchKey = nil
    }

    /// Returns whether keys are currently available.
    var hasKeys: Bool {
        masterKey?.isValid == true && vaultKey != nil
    }

    /// Gets the master key data for Keychain storage.
    /// - Returns: The master key as Data, or nil if not set.
    func getMasterKeyData() -> Data? {
        guard let key = masterKey?.key else { return nil }
        return key.withUnsafeBytes { Data($0) }
    }

    // MARK: - Encryption

    /// Encrypts data using AES-256-GCM.
    /// - Parameters:
    ///   - data: The plaintext data to encrypt.
    ///   - additionalData: Optional authenticated additional data.
    /// - Returns: The encrypted data with prepended nonce.
    /// - Throws: `CryptoError` if encryption fails.
    func encrypt(_ data: Data, additionalData: Data? = nil) async throws -> Data {
        guard let key = vaultKey else {
            throw CryptoError.invalidKey
        }

        return try Self.encrypt(data, using: key, additionalData: additionalData)
    }

    /// Encrypts data using a specific key.
    /// - Parameters:
    ///   - data: The plaintext data to encrypt.
    ///   - key: The encryption key.
    ///   - additionalData: Optional authenticated additional data.
    /// - Returns: The encrypted data with prepended nonce.
    /// - Throws: `CryptoError` if encryption fails.
    static func encrypt(_ data: Data, using key: SymmetricKey, additionalData: Data? = nil) throws -> Data {
        do {
            let nonce = AES.GCM.Nonce()
            let sealedBox: AES.GCM.SealedBox

            if let aad = additionalData {
                sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce, authenticating: aad)
            } else {
                sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
            }

            // Combine nonce + ciphertext + tag
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed(underlying: nil)
            }
            return combined
        } catch let error as CryptoError {
            throw error
        } catch {
            throw CryptoError.encryptionFailed(underlying: error)
        }
    }

    // MARK: - Decryption

    /// Decrypts data using AES-256-GCM.
    /// - Parameters:
    ///   - data: The encrypted data (nonce + ciphertext + tag).
    ///   - additionalData: Optional authenticated additional data (must match encryption).
    /// - Returns: The decrypted plaintext data.
    /// - Throws: `CryptoError` if decryption fails.
    func decrypt(_ data: Data, additionalData: Data? = nil) async throws -> Data {
        guard let key = vaultKey else {
            throw CryptoError.invalidKey
        }

        return try Self.decrypt(data, using: key, additionalData: additionalData)
    }

    /// Decrypts data using a specific key.
    /// - Parameters:
    ///   - data: The encrypted data (nonce + ciphertext + tag).
    ///   - key: The decryption key.
    ///   - additionalData: Optional authenticated additional data (must match encryption).
    /// - Returns: The decrypted plaintext data.
    /// - Throws: `CryptoError` if decryption fails.
    static func decrypt(_ data: Data, using key: SymmetricKey, additionalData: Data? = nil) throws -> Data {
        guard data.count > CryptoConstants.nonceLength + CryptoConstants.tagLength else {
            throw CryptoError.invalidData
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let plaintext: Data

            if let aad = additionalData {
                plaintext = try AES.GCM.open(sealedBox, using: key, authenticating: aad)
            } else {
                plaintext = try AES.GCM.open(sealedBox, using: key)
            }

            return plaintext
        } catch CryptoKitError.authenticationFailure {
            throw CryptoError.authenticationFailed
        } catch let error as CryptoError {
            throw error
        } catch {
            throw CryptoError.decryptionFailed(underlying: error)
        }
    }

    // MARK: - Password Verification

    /// Creates a password verifier for vault unlock verification.
    /// - Returns: Encrypted verifier data that can be used to verify the password.
    func createPasswordVerifier() async throws -> Data {
        // Create a known plaintext that we can verify after decryption
        let verifierPlaintext = "DODOPASS_VERIFIER_V1".data(using: .utf8)!
        return try await encrypt(verifierPlaintext)
    }

    /// Verifies a password by attempting to decrypt the verifier.
    /// - Parameters:
    ///   - encryptedVerifier: The encrypted verifier from vault creation.
    ///   - password: The password to verify.
    ///   - salt: The salt used during vault creation.
    /// - Returns: true if the password is correct, false otherwise.
    func verifyPassword(_ encryptedVerifier: Data, password: String, salt: Data) async -> Bool {
        do {
            // Derive temporary keys
            let masterKey = try KeyDerivation.deriveKey(from: password, salt: salt)
            let vaultKey = KeyDerivation.deriveSubkey(from: masterKey, for: .vaultEncryption)

            // Try to decrypt the verifier
            let decrypted = try Self.decrypt(encryptedVerifier, using: vaultKey)
            let expectedVerifier = "DODOPASS_VERIFIER_V1".data(using: .utf8)!

            return decrypted == expectedVerifier
        } catch {
            return false
        }
    }

    // MARK: - Search Index Key

    /// Gets the search index key for HMAC operations.
    /// - Returns: The search key, or nil if not available.
    func getSearchKey() -> SymmetricKey? {
        searchKey
    }

    // MARK: - Utility

    /// Generates a random nonce for AES-GCM.
    /// - Returns: A new random nonce.
    static func generateNonce() -> AES.GCM.Nonce {
        // AES.GCM.Nonce() generates a random nonce by default
        return AES.GCM.Nonce()
    }

    /// Generates random bytes.
    /// - Parameter count: The number of bytes to generate.
    /// - Returns: Random data.
    static func generateRandomBytes(count: Int) -> Data {
        var bytes = Data(count: count)
        bytes.withUnsafeMutableBytes { buffer in
            _ = SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        return bytes
    }
}
