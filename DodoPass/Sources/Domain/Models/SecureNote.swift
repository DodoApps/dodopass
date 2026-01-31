import Foundation

/// A secure note item stored in the vault.
struct SecureNote: VaultItem {
    let id: UUID
    var title: String
    var content: String
    var notes: String
    var tags: [String]
    var favorite: Bool
    let createdAt: Date
    var modifiedAt: Date
    var icon: ItemIcon
    var customFields: [CustomField]

    var category: ItemCategory { .secureNote }

    init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        notes: String = "",
        tags: [String] = [],
        favorite: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        icon: ItemIcon = .secureNote,
        customFields: [CustomField] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.notes = notes
        self.tags = tags
        self.favorite = favorite
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.icon = icon
        self.customFields = customFields
    }

    func searchableText() -> String {
        var text = [title, content, notes]
        text.append(contentsOf: tags)
        text.append(contentsOf: customFields.map { "\($0.label) \($0.value)" })
        return text.joined(separator: " ").lowercased()
    }

    /// Returns a preview of the content (first 100 characters).
    var contentPreview: String {
        if content.count <= 100 {
            return content
        }
        return String(content.prefix(100)) + "..."
    }

    /// Returns the word count of the content.
    var wordCount: Int {
        content.split(separator: " ").count
    }
}

// MARK: - Sample Data

extension SecureNote {
    static let example = SecureNote(
        title: "Personal Notes",
        content: """
        These are my secure personal notes.

        - Important dates
        - Secret information
        - Private thoughts
        """,
        tags: ["personal"],
        favorite: false
    )

    static let examples: [SecureNote] = [
        SecureNote(
            title: "WiFi Passwords",
            content: """
            Home WiFi: MyHomeNetwork
            Password: home_wifi_2024

            Office WiFi: CorpNetwork
            Password: corp_secure_pass
            """,
            tags: ["network"],
            favorite: true,
            icon: ItemIcon(symbolName: "wifi", colorName: "blue")
        ),
        SecureNote(
            title: "Recovery Codes",
            content: """
            Backup recovery codes for 2FA:
            1. ABC123DEF
            2. GHI456JKL
            3. MNO789PQR
            """,
            tags: ["security"],
            icon: ItemIcon(symbolName: "lock.shield.fill", colorName: "green")
        )
    ]
}
