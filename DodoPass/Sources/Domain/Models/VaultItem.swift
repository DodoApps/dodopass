import Foundation

/// Protocol that all vault items must conform to.
protocol VaultItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID { get }
    var title: String { get set }
    var notes: String { get set }
    var tags: [String] { get set }
    var favorite: Bool { get set }
    var createdAt: Date { get }
    var modifiedAt: Date { get set }
    var category: ItemCategory { get }
    var icon: ItemIcon { get set }
    var customFields: [CustomField] { get set }

    /// Returns searchable text for this item.
    func searchableText() -> String
}

// MARK: - Item Category

/// Categories for organizing vault items.
enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case login = "login"
    case secureNote = "secure_note"
    case creditCard = "credit_card"
    case identity = "identity"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .login:
            return "Login"
        case .secureNote:
            return "Secure note"
        case .creditCard:
            return "Credit card"
        case .identity:
            return "Identity"
        }
    }

    var systemImage: String {
        switch self {
        case .login:
            return "key.fill"
        case .secureNote:
            return "doc.text.fill"
        case .creditCard:
            return "creditcard.fill"
        case .identity:
            return "person.text.rectangle.fill"
        }
    }
}

// MARK: - Item Icon

/// Icon options for vault items.
struct ItemIcon: Codable, Equatable, Hashable {
    var symbolName: String
    var colorName: String

    init(symbolName: String = "key.fill", colorName: String = "blue") {
        self.symbolName = symbolName
        self.colorName = colorName
    }

    static let `default` = ItemIcon()

    static let login = ItemIcon(symbolName: "key.fill", colorName: "blue")
    static let secureNote = ItemIcon(symbolName: "doc.text.fill", colorName: "purple")
    static let creditCard = ItemIcon(symbolName: "creditcard.fill", colorName: "orange")
    static let identity = ItemIcon(symbolName: "person.text.rectangle.fill", colorName: "green")

    static let availableSymbols: [String] = [
        // Most commonly used - Web & Social logins
        "globe",
        "link",
        "at",
        "envelope.fill",
        "person.fill",
        "key.fill",

        // Popular services & apps
        "cart.fill",
        "bag.fill",
        "creditcard.fill",
        "banknote.fill",
        "building.columns.fill",
        "dollarsign.circle.fill",

        // Work & Business
        "briefcase.fill",
        "building.2.fill",
        "doc.text.fill",
        "folder.fill",

        // Technology & Devices
        "laptopcomputer",
        "desktopcomputer",
        "iphone",
        "wifi",
        "server.rack",
        "cloud.fill",
        "gamecontroller.fill",

        // Communication
        "message.fill",
        "phone.fill",
        "video.fill",
        "bubble.left.fill",

        // Entertainment & Media
        "play.tv.fill",
        "music.note",
        "film.fill",
        "book.fill",
        "newspaper.fill",
        "camera.fill",

        // Travel & Transport
        "airplane",
        "car.fill",
        "house.fill",
        "bed.double.fill",

        // Health & Fitness
        "heart.fill",
        "cross.case.fill",
        "figure.run",
        "dumbbell.fill",

        // Food & Drink
        "fork.knife",
        "cup.and.saucer.fill",
        "wineglass.fill",

        // Security
        "lock.fill",
        "shield.fill",
        "lock.shield.fill",
        "checkmark.shield.fill",

        // Favorites & Organization
        "star.fill",
        "bookmark.fill",
        "pin.fill",
        "tag.fill",
        "flag.fill",

        // Education
        "graduationcap.fill",
        "books.vertical.fill",

        // Utilities & Tools
        "gearshape.fill",
        "wrench.and.screwdriver.fill",
        "lightbulb.fill",

        // Misc popular
        "gift.fill",
        "photo.fill",
        "pawprint.fill",
        "leaf.fill",
        "bolt.fill"
    ]

    static let availableColors: [String] = [
        "blue",
        "purple",
        "pink",
        "red",
        "orange",
        "yellow",
        "green",
        "teal",
        "cyan",
        "indigo",
        "gray"
    ]
}

// MARK: - Any Vault Item

/// Type-erased wrapper for vault items to enable heterogeneous collections.
struct AnyVaultItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    private let itemType: ItemCategory
    private let encodedData: Data

    var category: ItemCategory { itemType }

    init<T: VaultItem>(_ item: T) throws {
        self.id = item.id
        self.itemType = item.category
        self.encodedData = try JSONEncoder().encode(item)
    }

    func decode<T: VaultItem>(as type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: encodedData)
    }

    func decodeToConcreteType() throws -> any VaultItem {
        switch itemType {
        case .login:
            return try decode(as: LoginItem.self)
        case .secureNote:
            return try decode(as: SecureNote.self)
        case .creditCard:
            return try decode(as: CreditCard.self)
        case .identity:
            return try decode(as: Identity.self)
        }
    }

    static func == (lhs: AnyVaultItem, rhs: AnyVaultItem) -> Bool {
        lhs.id == rhs.id && lhs.itemType == rhs.itemType && lhs.encodedData == rhs.encodedData
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(itemType)
        hasher.combine(encodedData)
    }
}

// MARK: - Vault Items Collection

/// A collection of all vault items.
struct VaultItems: Codable, Equatable {
    var logins: [LoginItem]
    var secureNotes: [SecureNote]
    var creditCards: [CreditCard]
    var identities: [Identity]

    init(
        logins: [LoginItem] = [],
        secureNotes: [SecureNote] = [],
        creditCards: [CreditCard] = [],
        identities: [Identity] = []
    ) {
        self.logins = logins
        self.secureNotes = secureNotes
        self.creditCards = creditCards
        self.identities = identities
    }

    /// Returns all items as a flat array.
    var allItems: [any VaultItem] {
        var items: [any VaultItem] = []
        items.append(contentsOf: logins)
        items.append(contentsOf: secureNotes)
        items.append(contentsOf: creditCards)
        items.append(contentsOf: identities)
        return items
    }

    /// Returns the total count of all items.
    var count: Int {
        logins.count + secureNotes.count + creditCards.count + identities.count
    }

    /// Returns true if there are no items.
    var isEmpty: Bool {
        count == 0
    }

    /// Finds an item by ID across all categories.
    func item(withId id: UUID) -> (any VaultItem)? {
        if let item = logins.first(where: { $0.id == id }) { return item }
        if let item = secureNotes.first(where: { $0.id == id }) { return item }
        if let item = creditCards.first(where: { $0.id == id }) { return item }
        if let item = identities.first(where: { $0.id == id }) { return item }
        return nil
    }

    /// Removes an item by ID.
    mutating func removeItem(withId id: UUID) {
        logins.removeAll { $0.id == id }
        secureNotes.removeAll { $0.id == id }
        creditCards.removeAll { $0.id == id }
        identities.removeAll { $0.id == id }
    }

    /// Updates an item in place.
    mutating func updateItem(_ item: any VaultItem) {
        switch item.category {
        case .login:
            if let login = item as? LoginItem,
               let index = logins.firstIndex(where: { $0.id == login.id }) {
                logins[index] = login
            }
        case .secureNote:
            if let note = item as? SecureNote,
               let index = secureNotes.firstIndex(where: { $0.id == note.id }) {
                secureNotes[index] = note
            }
        case .creditCard:
            if let card = item as? CreditCard,
               let index = creditCards.firstIndex(where: { $0.id == card.id }) {
                creditCards[index] = card
            }
        case .identity:
            if let identity = item as? Identity,
               let index = identities.firstIndex(where: { $0.id == identity.id }) {
                identities[index] = identity
            }
        }
    }

    /// Adds a new item.
    mutating func addItem(_ item: any VaultItem) {
        switch item.category {
        case .login:
            if let login = item as? LoginItem {
                logins.append(login)
            }
        case .secureNote:
            if let note = item as? SecureNote {
                secureNotes.append(note)
            }
        case .creditCard:
            if let card = item as? CreditCard {
                creditCards.append(card)
            }
        case .identity:
            if let identity = item as? Identity {
                identities.append(identity)
            }
        }
    }

    /// Returns all unique tags across all items.
    var allTags: Set<String> {
        var tags = Set<String>()
        for item in allItems {
            tags.formUnion(item.tags)
        }
        return tags
    }

    /// Returns all favorite items.
    var favorites: [any VaultItem] {
        allItems.filter { $0.favorite }
    }

    /// Returns items filtered by category.
    func items(in category: ItemCategory) -> [any VaultItem] {
        switch category {
        case .login:
            return logins
        case .secureNote:
            return secureNotes
        case .creditCard:
            return creditCards
        case .identity:
            return identities
        }
    }

    /// Returns items with a specific tag.
    func items(withTag tag: String) -> [any VaultItem] {
        allItems.filter { $0.tags.contains(tag) }
    }

    /// Returns items sorted by modification date (most recent first).
    var recentlyModified: [any VaultItem] {
        allItems.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}
