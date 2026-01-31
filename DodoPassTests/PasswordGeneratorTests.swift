import XCTest
@testable import DodoPass

final class PasswordGeneratorTests: XCTestCase {
    let generator = PasswordGenerator.shared

    // MARK: - Basic Generation Tests

    func testDefaultGeneration() {
        let password = generator.generate()

        XCTAssertEqual(password.count, 20) // Default length
        XCTAssertTrue(password.contains { $0.isUppercase })
        XCTAssertTrue(password.contains { $0.isLowercase })
        XCTAssertTrue(password.contains { $0.isNumber })
        XCTAssertTrue(password.contains { !$0.isLetter && !$0.isNumber })
    }

    func testCustomLength() {
        let config = PasswordGenerator.Configuration(length: 32)
        let password = generator.generate(with: config)

        XCTAssertEqual(password.count, 32)
    }

    func testMinimumLength() {
        let config = PasswordGenerator.Configuration(length: 4)
        let password = generator.generate(with: config)

        XCTAssertEqual(password.count, 4)
    }

    func testUppercaseOnly() {
        let config = PasswordGenerator.Configuration(
            length: 20,
            includeUppercase: true,
            includeLowercase: false,
            includeNumbers: false,
            includeSymbols: false
        )
        let password = generator.generate(with: config)

        XCTAssertTrue(password.allSatisfy { $0.isUppercase })
    }

    func testLowercaseOnly() {
        let config = PasswordGenerator.Configuration(
            length: 20,
            includeUppercase: false,
            includeLowercase: true,
            includeNumbers: false,
            includeSymbols: false
        )
        let password = generator.generate(with: config)

        XCTAssertTrue(password.allSatisfy { $0.isLowercase })
    }

    func testNumbersOnly() {
        let config = PasswordGenerator.Configuration(
            length: 20,
            includeUppercase: false,
            includeLowercase: false,
            includeNumbers: true,
            includeSymbols: false
        )
        let password = generator.generate(with: config)

        XCTAssertTrue(password.allSatisfy { $0.isNumber })
    }

    func testExcludeAmbiguous() {
        let config = PasswordGenerator.Configuration(
            length: 100, // Large sample for statistical significance
            excludeAmbiguous: true
        )
        let password = generator.generate(with: config)

        let ambiguousChars = "0O1lI"
        XCTAssertFalse(password.contains { ambiguousChars.contains($0) })
    }

    func testCustomSymbols() {
        let config = PasswordGenerator.Configuration(
            length: 50,
            includeUppercase: false,
            includeLowercase: false,
            includeNumbers: false,
            includeSymbols: true,
            customSymbols: "!@#"
        )
        let password = generator.generate(with: config)

        let allowedSymbols = "!@#"
        XCTAssertTrue(password.allSatisfy { allowedSymbols.contains($0) })
    }

    // MARK: - Uniqueness Tests

    func testPasswordsAreUnique() {
        var passwords = Set<String>()

        for _ in 0..<100 {
            let password = generator.generate()
            passwords.insert(password)
        }

        // All passwords should be unique
        XCTAssertEqual(passwords.count, 100)
    }

    // MARK: - Strength Evaluation Tests

    func testVeryWeakPassword() {
        let strength = generator.evaluateStrength("abc")
        XCTAssertEqual(strength, .veryWeak)
    }

    func testWeakPassword() {
        let strength = generator.evaluateStrength("password")
        XCTAssertLessThanOrEqual(strength, .weak)
    }

    func testFairPassword() {
        let strength = generator.evaluateStrength("Password1")
        XCTAssertGreaterThanOrEqual(strength, .fair)
    }

    func testStrongPassword() {
        let strength = generator.evaluateStrength("Password123!")
        XCTAssertGreaterThanOrEqual(strength, .strong)
    }

    func testVeryStrongPassword() {
        let strength = generator.evaluateStrength("Tr0ub4dor&3#Horse!Battery@Staple")
        XCTAssertEqual(strength, .veryStrong)
    }

    func testSequenceDetection() {
        // Passwords with sequences should be weaker
        let withSequence = generator.evaluateStrength("abc123ABC")
        let withoutSequence = generator.evaluateStrength("kx7Pm2Qr")

        XCTAssertLessThan(withSequence, withoutSequence)
    }

    func testRepeatDetection() {
        // Passwords with repeats should be weaker
        let withRepeats = generator.evaluateStrength("aaa123BBB")
        let withoutRepeats = generator.evaluateStrength("xyz123ABC")

        XCTAssertLessThan(withRepeats, withoutRepeats)
    }

    // MARK: - Entropy Tests

    func testEntropyCalculation() {
        // Simple lowercase password
        let lowEntropy = generator.calculateEntropy("aaaa")
        // Mixed character password
        let highEntropy = generator.calculateEntropy("aA1!")

        XCTAssertLessThan(lowEntropy, highEntropy)
    }

    func testEntropyIncreasesWithLength() {
        let short = generator.calculateEntropy("Aa1!")
        let medium = generator.calculateEntropy("Aa1!Bb2@")
        let long = generator.calculateEntropy("Aa1!Bb2@Cc3#Dd4$")

        XCTAssertLessThan(short, medium)
        XCTAssertLessThan(medium, long)
    }

    func testEmptyPasswordEntropy() {
        let entropy = generator.calculateEntropy("")
        XCTAssertEqual(entropy, 0)
    }

    // MARK: - Passphrase Tests

    func testPassphraseGeneration() {
        let passphrase = generator.generatePassphrase()

        // Should have 4 words by default
        let words = passphrase.components(separatedBy: "-")
        XCTAssertEqual(words.count, 4)
    }

    func testPassphraseWordCount() {
        let passphrase = generator.generatePassphrase(wordCount: 6)

        let words = passphrase.components(separatedBy: "-")
        XCTAssertEqual(words.count, 6)
    }

    func testPassphraseCustomSeparator() {
        let passphrase = generator.generatePassphrase(separator: "_")

        XCTAssertTrue(passphrase.contains("_"))
        XCTAssertFalse(passphrase.contains("-"))
    }

    func testPassphraseCapitalization() {
        let capitalizedPassphrase = generator.generatePassphrase(capitalize: true)
        let lowercasePassphrase = generator.generatePassphrase(capitalize: false)

        let capitalizedWords = capitalizedPassphrase.components(separatedBy: "-")
        let lowercaseWords = lowercasePassphrase.components(separatedBy: "-")

        // Capitalized words should start with uppercase
        for word in capitalizedWords {
            XCTAssertTrue(word.first?.isUppercase ?? false)
        }

        // Lowercase words should start with lowercase
        for word in lowercaseWords {
            XCTAssertTrue(word.first?.isLowercase ?? false)
        }
    }

    // MARK: - Configuration Validation Tests

    func testInvalidConfiguration() {
        let invalidConfig = PasswordGenerator.Configuration(
            length: 2, // Too short
            includeUppercase: false,
            includeLowercase: false,
            includeNumbers: false,
            includeSymbols: false // Nothing included
        )

        XCTAssertFalse(invalidConfig.isValid)
    }

    func testValidConfiguration() {
        let validConfig = PasswordGenerator.Configuration(
            length: 16,
            includeUppercase: true,
            includeLowercase: true,
            includeNumbers: true,
            includeSymbols: true
        )

        XCTAssertTrue(validConfig.isValid)
    }

    func testCharacterPool() {
        let config = PasswordGenerator.Configuration(
            includeUppercase: true,
            includeLowercase: false,
            includeNumbers: true,
            includeSymbols: false
        )

        let pool = config.characterPool

        XCTAssertTrue(pool.contains("A"))
        XCTAssertTrue(pool.contains("Z"))
        XCTAssertTrue(pool.contains("0"))
        XCTAssertTrue(pool.contains("9"))
        XCTAssertFalse(pool.contains("a"))
        XCTAssertFalse(pool.contains("!"))
    }
}
