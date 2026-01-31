import Foundation
import CryptoKit

/// Protocol defining cryptographic operations for the vault.
protocol CryptoServiceProtocol: Actor {
    /// Derives and stores keys from the master password.
    func deriveKeys(from password: String, salt: Data) async throws

    /// Sets the master key directly (used when restoring from Keychain).
    func setMasterKey(_ keyData: Data)

    /// Clears all keys from memory.
    func clearKeys()

    /// Returns whether keys are currently available.
    var hasKeys: Bool { get async }

    /// Gets the master key data for Keychain storage.
    func getMasterKeyData() -> Data?

    /// Encrypts data using AES-256-GCM.
    func encrypt(_ data: Data, additionalData: Data?) throws -> Data

    /// Decrypts data using AES-256-GCM.
    func decrypt(_ data: Data, additionalData: Data?) throws -> Data

    /// Creates a password verifier for vault unlock verification.
    func createPasswordVerifier() throws -> Data

    /// Verifies a password by attempting to decrypt the verifier.
    func verifyPassword(_ encryptedVerifier: Data, password: String, salt: Data) async -> Bool

    /// Gets the search index key for HMAC operations.
    func getSearchKey() -> SymmetricKey?
}
