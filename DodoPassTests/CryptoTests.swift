import XCTest
import CryptoKit
@testable import DodoPass

final class CryptoTests: XCTestCase {
    // MARK: - Key Derivation Tests

    func testKeyDerivation() {
        let password = "TestPassword123!"
        let salt = KeyDerivation.generateSalt()

        let key1 = KeyDerivation.deriveKey(from: password, salt: salt)
        let key2 = KeyDerivation.deriveKey(from: password, salt: salt)

        // Same password and salt should produce same key
        XCTAssertEqual(key1, key2)
    }

    func testKeyDerivationWithDifferentSalts() {
        let password = "TestPassword123!"
        let salt1 = KeyDerivation.generateSalt()
        let salt2 = KeyDerivation.generateSalt()

        let key1 = KeyDerivation.deriveKey(from: password, salt: salt1)
        let key2 = KeyDerivation.deriveKey(from: password, salt: salt2)

        // Different salts should produce different keys
        XCTAssertNotEqual(key1, key2)
    }

    func testKeyDerivationWithDifferentPasswords() {
        let salt = KeyDerivation.generateSalt()
        let key1 = KeyDerivation.deriveKey(from: "Password1", salt: salt)
        let key2 = KeyDerivation.deriveKey(from: "Password2", salt: salt)

        // Different passwords should produce different keys
        XCTAssertNotEqual(key1, key2)
    }

    func testSaltGeneration() {
        let salt1 = KeyDerivation.generateSalt()
        let salt2 = KeyDerivation.generateSalt()

        // Each salt should be unique
        XCTAssertNotEqual(salt1, salt2)

        // Salt should be correct length
        XCTAssertEqual(salt1.count, CryptoConstants.saltLength)
    }

    func testHKDFExpansion() {
        let masterKey = Data(repeating: 0x42, count: 32)

        let vaultKey = KeyDerivation.expandKey(masterKey, info: CryptoConstants.vaultKeyInfo)
        let searchKey = KeyDerivation.expandKey(masterKey, info: CryptoConstants.searchKeyInfo)
        let backupKey = KeyDerivation.expandKey(masterKey, info: CryptoConstants.backupKeyInfo)

        // Different info should produce different keys
        XCTAssertNotEqual(vaultKey, searchKey)
        XCTAssertNotEqual(searchKey, backupKey)
        XCTAssertNotEqual(vaultKey, backupKey)

        // Same input should produce same output
        let vaultKey2 = KeyDerivation.expandKey(masterKey, info: CryptoConstants.vaultKeyInfo)
        XCTAssertEqual(vaultKey, vaultKey2)
    }

    // MARK: - Encryption/Decryption Tests

    func testEncryptDecryptRoundtrip() async throws {
        let cryptoService = CryptoService()

        let password = "TestPassword123!"
        let salt = KeyDerivation.generateSalt()

        try await cryptoService.deriveAndSetKey(password: password, salt: salt)

        let plaintext = "Hello, World! This is a test message.".data(using: .utf8)!
        let encrypted = try await cryptoService.encrypt(plaintext)
        let decrypted = try await cryptoService.decrypt(encrypted)

        XCTAssertEqual(plaintext, decrypted)
    }

    func testEncryptProducesDifferentCiphertext() async throws {
        let cryptoService = CryptoService()

        let password = "TestPassword123!"
        let salt = KeyDerivation.generateSalt()

        try await cryptoService.deriveAndSetKey(password: password, salt: salt)

        let plaintext = "Test message".data(using: .utf8)!

        let encrypted1 = try await cryptoService.encrypt(plaintext)
        let encrypted2 = try await cryptoService.encrypt(plaintext)

        // Same plaintext should produce different ciphertext (due to random nonce)
        XCTAssertNotEqual(encrypted1, encrypted2)

        // But both should decrypt to same plaintext
        let decrypted1 = try await cryptoService.decrypt(encrypted1)
        let decrypted2 = try await cryptoService.decrypt(encrypted2)

        XCTAssertEqual(decrypted1, decrypted2)
        XCTAssertEqual(decrypted1, plaintext)
    }

    func testDecryptWithWrongKeyFails() async throws {
        let cryptoService1 = CryptoService()
        let cryptoService2 = CryptoService()

        let salt = KeyDerivation.generateSalt()

        try await cryptoService1.deriveAndSetKey(password: "Password1", salt: salt)
        try await cryptoService2.deriveAndSetKey(password: "Password2", salt: salt)

        let plaintext = "Secret message".data(using: .utf8)!
        let encrypted = try await cryptoService1.encrypt(plaintext)

        // Decrypting with different key should fail
        do {
            _ = try await cryptoService2.decrypt(encrypted)
            XCTFail("Should have thrown an error")
        } catch {
            // Expected
        }
    }

    func testEmptyDataEncryption() async throws {
        let cryptoService = CryptoService()

        let password = "TestPassword123!"
        let salt = KeyDerivation.generateSalt()

        try await cryptoService.deriveAndSetKey(password: password, salt: salt)

        let plaintext = Data()
        let encrypted = try await cryptoService.encrypt(plaintext)
        let decrypted = try await cryptoService.decrypt(encrypted)

        XCTAssertEqual(plaintext, decrypted)
    }

    func testLargeDataEncryption() async throws {
        let cryptoService = CryptoService()

        let password = "TestPassword123!"
        let salt = KeyDerivation.generateSalt()

        try await cryptoService.deriveAndSetKey(password: password, salt: salt)

        // 1MB of data
        let plaintext = Data(repeating: 0x42, count: 1024 * 1024)
        let encrypted = try await cryptoService.encrypt(plaintext)
        let decrypted = try await cryptoService.decrypt(encrypted)

        XCTAssertEqual(plaintext, decrypted)
    }

    // MARK: - Password Verification Tests

    func testPasswordVerification() async throws {
        let cryptoService = CryptoService()

        let password = "TestPassword123!"
        let salt = KeyDerivation.generateSalt()

        try await cryptoService.deriveAndSetKey(password: password, salt: salt)

        let verifier = await cryptoService.createVerifier()

        // Create new crypto service and verify
        let cryptoService2 = CryptoService()
        try await cryptoService2.deriveAndSetKey(password: password, salt: salt)

        let isValid = await cryptoService2.verify(verifier)
        XCTAssertTrue(isValid)
    }

    func testPasswordVerificationFailsWithWrongPassword() async throws {
        let cryptoService = CryptoService()

        let salt = KeyDerivation.generateSalt()

        try await cryptoService.deriveAndSetKey(password: "CorrectPassword", salt: salt)
        let verifier = await cryptoService.createVerifier()

        let cryptoService2 = CryptoService()
        try await cryptoService2.deriveAndSetKey(password: "WrongPassword", salt: salt)

        let isValid = await cryptoService2.verify(verifier)
        XCTAssertFalse(isValid)
    }

    // MARK: - Secure Memory Tests

    func testSecureDataWiping() {
        var data = Data([0x01, 0x02, 0x03, 0x04])
        SecureMemory.wipe(&data)

        // All bytes should be zero after wiping
        XCTAssertTrue(data.allSatisfy { $0 == 0 })
    }
}
