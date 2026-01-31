import Foundation
import CryptoKit

/// Generates Time-based One-Time Passwords (TOTP) per RFC 6238.
final class TOTPGenerator {
    // MARK: - Types

    enum TOTPError: Error {
        case invalidSecret
        case invalidBase32
    }

    struct TOTPCode {
        let code: String
        let remainingSeconds: Int
        let period: Int
    }

    // MARK: - Properties

    private let period: Int
    private let digits: Int

    // MARK: - Initialization

    init(period: Int = 30, digits: Int = 6) {
        self.period = period
        self.digits = digits
    }

    // MARK: - Public API

    /// Generates a TOTP code from a secret.
    /// - Parameter secret: Base32-encoded secret string
    /// - Returns: The current TOTP code and remaining seconds
    func generate(secret: String) throws -> TOTPCode {
        let cleanSecret = secret
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        guard let secretData = base32Decode(cleanSecret) else {
            throw TOTPError.invalidBase32
        }

        let counter = UInt64(Date().timeIntervalSince1970) / UInt64(period)
        let code = generateHOTP(secret: secretData, counter: counter)

        let remainingSeconds = period - Int(Date().timeIntervalSince1970) % period

        return TOTPCode(
            code: code,
            remainingSeconds: remainingSeconds,
            period: period
        )
    }

    /// Parses a TOTP URI (otpauth://totp/...) and extracts the secret.
    static func parseURI(_ uri: String) -> (secret: String, issuer: String?, account: String?)? {
        guard uri.lowercased().hasPrefix("otpauth://totp/") else {
            return nil
        }

        guard let url = URL(string: uri),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        // Extract secret from query parameters
        guard let secret = components.queryItems?.first(where: { $0.name == "secret" })?.value else {
            return nil
        }

        // Extract issuer
        let issuer = components.queryItems?.first(where: { $0.name == "issuer" })?.value

        // Extract account from path
        let path = components.path.dropFirst() // Remove leading /
        let account = String(path)

        return (secret: secret, issuer: issuer, account: account.isEmpty ? nil : account)
    }

    // MARK: - Private Helpers

    private func generateHOTP(secret: Data, counter: UInt64) -> String {
        // Convert counter to big-endian bytes
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: 8)

        // Calculate HMAC-SHA1
        let key = SymmetricKey(data: secret)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacData = Data(hmac)

        // Dynamic truncation
        let offset = Int(hmacData[hmacData.count - 1] & 0x0f)
        let truncatedHash = hmacData.subdata(in: offset..<offset + 4)

        var number = truncatedHash.withUnsafeBytes { ptr in
            ptr.load(as: UInt32.self).bigEndian
        }
        number &= 0x7fffffff

        // Generate code with specified number of digits
        let modulo = UInt32(pow(10.0, Double(digits)))
        let code = number % modulo

        return String(format: "%0\(digits)d", code)
    }

    private func base32Decode(_ input: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let paddedInput = input.padding(toLength: ((input.count + 7) / 8) * 8, withPad: "=", startingAt: 0)

        var result = Data()
        var buffer: UInt64 = 0
        var bitsRemaining = 0

        for char in paddedInput {
            if char == "=" {
                break
            }

            guard let index = alphabet.firstIndex(of: char) else {
                return nil
            }

            let value = alphabet.distance(from: alphabet.startIndex, to: index)
            buffer = (buffer << 5) | UInt64(value)
            bitsRemaining += 5

            if bitsRemaining >= 8 {
                bitsRemaining -= 8
                result.append(UInt8((buffer >> bitsRemaining) & 0xff))
            }
        }

        return result
    }
}
