import Foundation

/// A credit card item stored in the vault.
struct CreditCard: VaultItem {
    let id: UUID
    var title: String
    var cardholderName: String
    var cardNumber: String
    var expirationMonth: Int
    var expirationYear: Int
    var cvv: String
    var pin: String
    var cardType: CardType
    var notes: String
    var tags: [String]
    var favorite: Bool
    let createdAt: Date
    var modifiedAt: Date
    var icon: ItemIcon
    var customFields: [CustomField]

    // Billing address
    var billingAddress: Address?

    var category: ItemCategory { .creditCard }

    init(
        id: UUID = UUID(),
        title: String,
        cardholderName: String = "",
        cardNumber: String = "",
        expirationMonth: Int = 1,
        expirationYear: Int = Calendar.current.component(.year, from: Date()),
        cvv: String = "",
        pin: String = "",
        cardType: CardType = .unknown,
        notes: String = "",
        tags: [String] = [],
        favorite: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        icon: ItemIcon = .creditCard,
        customFields: [CustomField] = [],
        billingAddress: Address? = nil
    ) {
        self.id = id
        self.title = title
        self.cardholderName = cardholderName
        self.cardNumber = cardNumber
        self.expirationMonth = expirationMonth
        self.expirationYear = expirationYear
        self.cvv = cvv
        self.pin = pin
        self.cardType = cardType
        self.notes = notes
        self.tags = tags
        self.favorite = favorite
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.icon = icon
        self.customFields = customFields
        self.billingAddress = billingAddress
    }

    func searchableText() -> String {
        var text = [title, cardholderName]
        text.append(contentsOf: tags)
        text.append(notes)
        text.append(contentsOf: customFields.map { "\($0.label) \($0.value)" })
        // Include last 4 digits of card number for searching
        if cardNumber.count >= 4 {
            text.append(String(cardNumber.suffix(4)))
        }
        return text.joined(separator: " ").lowercased()
    }

    /// Returns the masked card number (shows only last 4 digits).
    var maskedCardNumber: String {
        guard cardNumber.count >= 4 else {
            return cardNumber
        }
        let lastFour = String(cardNumber.suffix(4))
        let maskedPart = String(repeating: "•", count: cardNumber.count - 4)
        return maskedPart + lastFour
    }

    /// Returns a formatted card number with spaces.
    var formattedCardNumber: String {
        var formatted = ""
        for (index, char) in cardNumber.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted += String(char)
        }
        return formatted
    }

    /// Returns the formatted expiration date (MM/YY).
    var formattedExpiration: String {
        let month = String(format: "%02d", expirationMonth)
        let year = String(expirationYear).suffix(2)
        return "\(month)/\(year)"
    }

    /// Returns true if the card is expired.
    var isExpired: Bool {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        if expirationYear < currentYear {
            return true
        } else if expirationYear == currentYear && expirationMonth < currentMonth {
            return true
        }
        return false
    }

    /// Detects and sets the card type based on the card number.
    mutating func detectCardType() {
        cardType = CardType.detect(from: cardNumber)
    }
}

// MARK: - Card Type

/// Credit card network types.
enum CardType: String, Codable, CaseIterable, Identifiable {
    case visa
    case mastercard
    case amex
    case discover
    case dinersClub = "diners_club"
    case jcb
    case unionPay = "union_pay"
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .visa:
            return "Visa"
        case .mastercard:
            return "Mastercard"
        case .amex:
            return "American Express"
        case .discover:
            return "Discover"
        case .dinersClub:
            return "Diners Club"
        case .jcb:
            return "JCB"
        case .unionPay:
            return "UnionPay"
        case .unknown:
            return "Unknown"
        }
    }

    /// Detects the card type based on the card number prefix.
    static func detect(from cardNumber: String) -> CardType {
        let digits = cardNumber.filter { $0.isNumber }
        guard !digits.isEmpty else { return .unknown }

        // Visa: starts with 4
        if digits.hasPrefix("4") {
            return .visa
        }

        // Mastercard: starts with 51-55 or 2221-2720
        if let firstTwo = Int(String(digits.prefix(2))) {
            if (51...55).contains(firstTwo) {
                return .mastercard
            }
        }
        if let firstFour = Int(String(digits.prefix(4))) {
            if (2221...2720).contains(firstFour) {
                return .mastercard
            }
        }

        // American Express: starts with 34 or 37
        if digits.hasPrefix("34") || digits.hasPrefix("37") {
            return .amex
        }

        // Discover: starts with 6011, 644-649, or 65
        if digits.hasPrefix("6011") || digits.hasPrefix("65") {
            return .discover
        }
        if let firstThree = Int(String(digits.prefix(3))) {
            if (644...649).contains(firstThree) {
                return .discover
            }
        }

        // JCB: starts with 3528-3589
        if let firstFour = Int(String(digits.prefix(4))) {
            if (3528...3589).contains(firstFour) {
                return .jcb
            }
        }

        // Diners Club: starts with 300-305, 36, 38, 39
        if digits.hasPrefix("36") || digits.hasPrefix("38") || digits.hasPrefix("39") {
            return .dinersClub
        }
        if let firstThree = Int(String(digits.prefix(3))) {
            if (300...305).contains(firstThree) {
                return .dinersClub
            }
        }

        // UnionPay: starts with 62
        if digits.hasPrefix("62") {
            return .unionPay
        }

        return .unknown
    }
}

// MARK: - Address

/// A physical address.
struct Address: Codable, Equatable, Hashable {
    var street: String
    var city: String
    var state: String
    var postalCode: String
    var country: String

    init(
        street: String = "",
        city: String = "",
        state: String = "",
        postalCode: String = "",
        country: String = ""
    ) {
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
    }

    var isEmpty: Bool {
        street.isEmpty && city.isEmpty && state.isEmpty && postalCode.isEmpty && country.isEmpty
    }

    var formattedAddress: String {
        var parts: [String] = []
        if !street.isEmpty { parts.append(street) }
        if !city.isEmpty { parts.append(city) }
        if !state.isEmpty || !postalCode.isEmpty {
            parts.append("\(state) \(postalCode)".trimmingCharacters(in: .whitespaces))
        }
        if !country.isEmpty { parts.append(country) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Sample Data

extension CreditCard {
    static let example = CreditCard(
        title: "Personal Visa",
        cardholderName: "John Doe",
        cardNumber: "4111111111111111",
        expirationMonth: 12,
        expirationYear: 2026,
        cvv: "123",
        cardType: .visa,
        favorite: true
    )

    static let examples: [CreditCard] = [
        CreditCard(
            title: "Chase Sapphire",
            cardholderName: "Jane Smith",
            cardNumber: "5555555555554444",
            expirationMonth: 6,
            expirationYear: 2025,
            cvv: "456",
            cardType: .mastercard,
            tags: ["travel"],
            icon: ItemIcon(symbolName: "creditcard.fill", colorName: "blue")
        ),
        CreditCard(
            title: "Business Amex",
            cardholderName: "John Doe",
            cardNumber: "378282246310005",
            expirationMonth: 9,
            expirationYear: 2027,
            cvv: "7890",
            cardType: .amex,
            tags: ["business"],
            icon: ItemIcon(symbolName: "creditcard.fill", colorName: "green")
        )
    ]
}
