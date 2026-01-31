import Foundation
import CryptoKit

/// Checks passwords and emails against breach databases using k-anonymity.
/// Uses Have I Been Pwned API with SHA-1 prefix matching to avoid sending actual passwords.
final class BreachChecker: ObservableObject {
    // MARK: - Types

    struct BreachResult {
        let isBreached: Bool
        let count: Int  // Number of times seen in breaches
    }

    struct EmailBreachResult {
        let isBreached: Bool
        let breaches: [BreachInfo]
    }

    struct BreachInfo: Codable, Identifiable {
        let name: String
        let title: String
        let domain: String
        let breachDate: String
        let description: String
        let pwnCount: Int

        var id: String { name }

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case title = "Title"
            case domain = "Domain"
            case breachDate = "BreachDate"
            case description = "Description"
            case pwnCount = "PwnCount"
        }
    }

    enum BreachCheckError: Error {
        case networkError
        case invalidResponse
        case rateLimited
    }

    // MARK: - Properties

    static let shared = BreachChecker()

    private let session: URLSession
    private let passwordAPIBase = "https://api.pwnedpasswords.com/range/"
    private let breachAPIBase = "https://haveibeenpwned.com/api/v3/breachedaccount/"

    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckDate: Date?

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "DodoPass-PasswordManager"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Password Breach Check

    /// Checks if a password has been found in data breaches using k-anonymity.
    /// Only the first 5 characters of the SHA-1 hash are sent to the API.
    func checkPassword(_ password: String) async throws -> BreachResult {
        // Calculate SHA-1 hash of password
        let passwordData = Data(password.utf8)
        let hash = Insecure.SHA1.hash(data: passwordData)
        let hashString = hash.map { String(format: "%02x", $0) }.joined().uppercased()

        // Split hash: first 5 chars (prefix) and rest (suffix)
        let prefix = String(hashString.prefix(5))
        let suffix = String(hashString.dropFirst(5))

        // Request all hashes with this prefix
        guard let url = URL(string: "\(passwordAPIBase)\(prefix)") else {
            throw BreachCheckError.networkError
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BreachCheckError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw BreachCheckError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            throw BreachCheckError.invalidResponse
        }

        // Parse response - each line is "SUFFIX:COUNT"
        guard let responseString = String(data: data, encoding: .utf8) else {
            throw BreachCheckError.invalidResponse
        }

        // Search for our suffix in the response
        for line in responseString.components(separatedBy: "\n") {
            let parts = line.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ":")
            if parts.count == 2 && parts[0].uppercased() == suffix {
                let count = Int(parts[1]) ?? 0
                return BreachResult(isBreached: true, count: count)
            }
        }

        return BreachResult(isBreached: false, count: 0)
    }

    // MARK: - Email Breach Check

    /// Checks if an email has been found in data breaches.
    /// Note: This requires a paid HIBP API key for production use.
    func checkEmail(_ email: String, apiKey: String? = nil) async throws -> EmailBreachResult {
        guard let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(breachAPIBase)\(encodedEmail)?truncateResponse=false") else {
            throw BreachCheckError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // API key required for HIBP v3
        if let key = apiKey {
            request.setValue(key, forHTTPHeaderField: "hibp-api-key")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BreachCheckError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let breaches = try JSONDecoder().decode([BreachInfo].self, from: data)
            return EmailBreachResult(isBreached: true, breaches: breaches)
        case 404:
            return EmailBreachResult(isBreached: false, breaches: [])
        case 429:
            throw BreachCheckError.rateLimited
        default:
            throw BreachCheckError.invalidResponse
        }
    }

    // MARK: - Batch Check

    /// Checks multiple passwords and returns breach status for each.
    /// Uses rate limiting to avoid hitting API limits.
    func checkPasswords(_ passwords: [(id: UUID, password: String)]) async -> [UUID: BreachResult] {
        var results: [UUID: BreachResult] = [:]

        await MainActor.run {
            isChecking = true
        }

        defer {
            Task { @MainActor in
                isChecking = false
                lastCheckDate = Date()
            }
        }

        for (id, password) in passwords {
            do {
                let result = try await checkPassword(password)
                results[id] = result

                // Rate limiting: 1.5 second delay between requests
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            } catch {
                // Continue with other passwords if one fails
                AuditLogger.shared.log("Breach check failed for item: \(error.localizedDescription)", category: .app, level: .warning)
            }
        }

        return results
    }

    // MARK: - Password Strength

    /// Calculates password strength score (0-100).
    func calculatePasswordStrength(_ password: String) -> Int {
        var score = 0

        // Length scoring
        let length = password.count
        if length >= 8 { score += 20 }
        if length >= 12 { score += 15 }
        if length >= 16 { score += 15 }

        // Character type scoring
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbols = password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil

        if hasUppercase { score += 10 }
        if hasLowercase { score += 10 }
        if hasNumbers { score += 10 }
        if hasSymbols { score += 10 }

        // Variety bonus
        let charTypes = [hasUppercase, hasLowercase, hasNumbers, hasSymbols].filter { $0 }.count
        if charTypes >= 3 { score += 5 }
        if charTypes == 4 { score += 5 }

        return min(score, 100)
    }

    /// Returns strength level for display.
    func strengthLevel(_ password: String) -> PasswordStrengthLevel {
        let score = calculatePasswordStrength(password)
        switch score {
        case 0..<30: return .weak
        case 30..<60: return .fair
        case 60..<80: return .good
        default: return .strong
        }
    }
}

// MARK: - Strength Level

enum PasswordStrengthLevel: String {
    case weak = "Weak"
    case fair = "Fair"
    case good = "Good"
    case strong = "Strong"

    var color: String {
        switch self {
        case .weak: return "#FF453A"     // Red
        case .fair: return "#FF9500"     // Orange
        case .good: return "#34C759"     // Green
        case .strong: return "#30D158"   // Bright green
        }
    }
}
