import Foundation
import CryptoKit
import CommonCrypto

/// Handles key derivation operations using PBKDF2 and HKDF.
enum KeyDerivation {
    // MARK: - Errors

    enum KeyDerivationError: LocalizedError {
        case pbkdf2Failed(status: CCCryptorStatus)
        case invalidPassword
        case invalidSalt

        var errorDescription: String? {
            switch self {
            case .pbkdf2Failed(let status):
                return "Key derivation failed with status: \(status)"
            case .invalidPassword:
                return "Invalid password provided"
            case .invalidSalt:
                return "Invalid salt provided"
            }
        }
    }

    // MARK: - Salt Generation

    /// Generates a cryptographically secure random salt.
    /// - Parameter length: The length of the salt in bytes.
    /// - Returns: Random salt data.
    static func generateSalt(length: Int = CryptoConstants.saltLength) -> Data {
        var salt = Data(count: length)
        salt.withUnsafeMutableBytes { buffer in
            _ = SecRandomCopyBytes(kSecRandomDefault, length, buffer.baseAddress!)
        }
        return salt
    }

    // MARK: - PBKDF2

    /// Derives a key from a password using PBKDF2-SHA256.
    /// - Parameters:
    ///   - password: The user's master password.
    ///   - salt: The salt to use for derivation.
    ///   - iterations: Number of iterations (defaults to CryptoConstants.pbkdf2Iterations).
    ///   - keyLength: Length of the derived key in bytes.
    /// - Returns: The derived key.
    /// - Throws: `KeyDerivationError` if derivation fails.
    static func deriveKey(
        from password: String,
        salt: Data,
        iterations: Int = CryptoConstants.pbkdf2Iterations,
        keyLength: Int = CryptoConstants.derivedKeyLength
    ) throws -> SymmetricKey {
        guard !password.isEmpty else {
            throw KeyDerivationError.invalidPassword
        }

        guard salt.count >= 16 else {
            throw KeyDerivationError.invalidSalt
        }

        let passwordData = Data(password.utf8)
        var derivedKey = Data(count: keyLength)

        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBuffer in
            salt.withUnsafeBytes { saltBuffer in
                passwordData.withUnsafeBytes { passwordBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw KeyDerivationError.pbkdf2Failed(status: status)
        }

        return SymmetricKey(data: derivedKey)
    }

    // MARK: - HKDF

    /// Derives a purpose-specific key from a master key using HKDF.
    /// - Parameters:
    ///   - masterKey: The master key to derive from.
    ///   - purpose: The purpose of the derived key.
    ///   - outputLength: Length of the output key in bytes.
    /// - Returns: The purpose-specific derived key.
    static func deriveSubkey(
        from masterKey: SymmetricKey,
        for purpose: DerivedKeyPurpose,
        outputLength: Int = CryptoConstants.derivedKeyLength
    ) -> SymmetricKey {
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            info: purpose.info,
            outputByteCount: outputLength
        )
        return derivedKey
    }

    /// Derives a purpose-specific key from a master key using HKDF with custom info.
    /// - Parameters:
    ///   - masterKey: The master key to derive from.
    ///   - info: Custom info data for the derivation.
    ///   - outputLength: Length of the output key in bytes.
    /// - Returns: The derived key.
    static func deriveSubkey(
        from masterKey: SymmetricKey,
        info: Data,
        outputLength: Int = CryptoConstants.derivedKeyLength
    ) -> SymmetricKey {
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            info: info,
            outputByteCount: outputLength
        )
        return derivedKey
    }
}
