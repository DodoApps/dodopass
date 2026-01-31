import Foundation

/// A login credential item stored in the vault.
struct LoginItem: VaultItem {
    let id: UUID
    var title: String
    var username: String
    var password: String
    var urls: [String]
    var notes: String
    var tags: [String]
    var favorite: Bool
    let createdAt: Date
    var modifiedAt: Date
    var icon: ItemIcon
    var customFields: [CustomField]

    // Login-specific fields
    var totpSecret: String?
    var passwordHistory: [PasswordHistoryEntry]

    var category: ItemCategory { .login }

    init(
        id: UUID = UUID(),
        title: String,
        username: String = "",
        password: String = "",
        urls: [String] = [],
        notes: String = "",
        tags: [String] = [],
        favorite: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        icon: ItemIcon = .login,
        customFields: [CustomField] = [],
        totpSecret: String? = nil,
        passwordHistory: [PasswordHistoryEntry] = []
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.urls = urls
        self.notes = notes
        self.tags = tags
        self.favorite = favorite
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.icon = icon
        self.customFields = customFields
        self.totpSecret = totpSecret
        self.passwordHistory = passwordHistory
    }

    /// Returns the primary URL if available.
    var primaryUrl: String? {
        urls.first
    }

    /// Returns the domain from the primary URL.
    var domain: String? {
        guard let urlString = primaryUrl,
              let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        return host
    }

    func searchableText() -> String {
        var text = [title, username]
        text.append(contentsOf: urls)
        text.append(contentsOf: tags)
        text.append(notes)
        text.append(contentsOf: customFields.map { "\($0.label) \($0.value)" })
        return text.joined(separator: " ").lowercased()
    }

    /// Updates the password and adds the old one to history.
    mutating func updatePassword(_ newPassword: String) {
        if !password.isEmpty {
            passwordHistory.insert(
                PasswordHistoryEntry(password: password, changedAt: Date()),
                at: 0
            )
            // Keep only the last 10 password history entries
            if passwordHistory.count > 10 {
                passwordHistory = Array(passwordHistory.prefix(10))
            }
        }
        password = newPassword
        modifiedAt = Date()
    }
}

// MARK: - Password History Entry

/// An entry in the password history.
struct PasswordHistoryEntry: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    let password: String
    let changedAt: Date

    init(id: UUID = UUID(), password: String, changedAt: Date) {
        self.id = id
        self.password = password
        self.changedAt = changedAt
    }
}

// MARK: - Sample Data

extension LoginItem {
    static let example = LoginItem(
        title: "Example Login",
        username: "user@example.com",
        password: "secretpassword123",
        urls: ["https://example.com"],
        notes: "This is an example login item.",
        tags: ["work", "important"],
        favorite: true
    )

    static let examples: [LoginItem] = [
        LoginItem(
            title: "GitHub",
            username: "developer@email.com",
            password: "gh_password_123",
            urls: ["https://github.com"],
            tags: ["development"],
            favorite: true,
            icon: ItemIcon(symbolName: "chevron.left.forwardslash.chevron.right", colorName: "gray")
        ),
        LoginItem(
            title: "Gmail",
            username: "user@gmail.com",
            password: "gmail_secure_pass",
            urls: ["https://mail.google.com"],
            tags: ["personal"],
            icon: ItemIcon(symbolName: "envelope.fill", colorName: "red")
        ),
        LoginItem(
            title: "Netflix",
            username: "viewer@email.com",
            password: "netflix_pass",
            urls: ["https://netflix.com"],
            tags: ["entertainment"],
            icon: ItemIcon(symbolName: "tv.fill", colorName: "red")
        )
    ]
}
