import Foundation
import UniformTypeIdentifiers
import CryptoKit

/// Service for importing and exporting vault data.
final class ImportExportService {
    // MARK: - Singleton

    static let shared = ImportExportService()

    private init() {}

    // MARK: - Export Formats

    enum ExportFormat: String, CaseIterable, Identifiable {
        case dodopassEncrypted = "DodoPass Encrypted (.dodobackup)"
        case dodopassJSON = "DodoPass JSON (.json)"
        case csv = "CSV (.csv)"

        var id: String { rawValue }

        var fileExtension: String {
            switch self {
            case .dodopassEncrypted: return "dodobackup"
            case .dodopassJSON: return "json"
            case .csv: return "csv"
            }
        }

        var utType: UTType {
            switch self {
            case .dodopassEncrypted: return UTType(filenameExtension: "dodobackup") ?? .data
            case .dodopassJSON: return .json
            case .csv: return .commaSeparatedText
            }
        }
    }

    // MARK: - Import Formats

    enum ImportFormat: String, CaseIterable, Identifiable {
        case dodopassEncrypted = "DodoPass Encrypted Backup"
        case dodopassJSON = "DodoPass JSON"
        case onePasswordCSV = "1Password CSV"
        case chromeCSV = "Chrome/Brave CSV"
        case genericCSV = "Generic CSV"

        var id: String { rawValue }

        var supportedExtensions: [String] {
            switch self {
            case .dodopassEncrypted: return ["dodobackup"]
            case .dodopassJSON: return ["json"]
            case .onePasswordCSV, .chromeCSV, .genericCSV: return ["csv"]
            }
        }
    }

    // MARK: - Import Result

    struct ImportResult {
        let itemsImported: Int
        let itemsSkipped: Int
        let errors: [String]
    }

    // MARK: - Export

    /// Exports vault items to the specified format.
    func export(
        items: VaultItems,
        format: ExportFormat,
        password: String? = nil
    ) throws -> Data {
        switch format {
        case .dodopassEncrypted:
            guard let password = password, !password.isEmpty else {
                throw ImportExportError.passwordRequired
            }
            return try exportEncrypted(items: items, password: password)

        case .dodopassJSON:
            return try exportJSON(items: items)

        case .csv:
            return try exportCSV(items: items)
        }
    }

    private func exportEncrypted(items: VaultItems, password: String) throws -> Data {
        // Create exportable structure
        let exportData = ExportableVault(from: items)
        let jsonData = try JSONEncoder().encode(exportData)

        // Encrypt with password
        let salt = KeyDerivation.generateSalt()
        let key = try KeyDerivation.deriveKey(from: password, salt: salt)
        let encrypted = try CryptoService.encrypt(jsonData, using: key)

        // Create container with salt and encrypted data
        var container = Data()
        container.append(contentsOf: "DODO".utf8) // Magic bytes
        container.append(UInt8(1)) // Version
        container.append(salt)
        container.append(encrypted)

        return container
    }

    private func exportJSON(items: VaultItems) throws -> Data {
        let exportData = ExportableVault(from: items)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exportData)
    }

    private func exportCSV(items: VaultItems) throws -> Data {
        var csv = "name,url,username,password,notes,type,totp\n"

        for login in items.logins {
            let row = [
                escapeCSV(login.title),
                escapeCSV(login.urls.first ?? ""),
                escapeCSV(login.username),
                escapeCSV(login.password),
                escapeCSV(login.notes),
                "login",
                escapeCSV(login.totpSecret ?? "")
            ].joined(separator: ",")
            csv += row + "\n"
        }

        for note in items.secureNotes {
            let row = [
                escapeCSV(note.title),
                "",
                "",
                "",
                escapeCSV(note.content),
                "note",
                ""
            ].joined(separator: ",")
            csv += row + "\n"
        }

        for card in items.creditCards {
            let row = [
                escapeCSV(card.title),
                "",
                escapeCSV(card.cardholderName),
                escapeCSV(card.cardNumber),
                escapeCSV("CVV: \(card.cvv), Exp: \(card.expirationMonth)/\(card.expirationYear)"),
                "card",
                ""
            ].joined(separator: ",")
            csv += row + "\n"
        }

        for identity in items.identities {
            let row = [
                escapeCSV(identity.title),
                "",
                escapeCSV(identity.email),
                "",
                escapeCSV("Name: \(identity.fullName), Phone: \(identity.phone)"),
                "identity",
                ""
            ].joined(separator: ",")
            csv += row + "\n"
        }

        guard let data = csv.data(using: .utf8) else {
            throw ImportExportError.encodingFailed
        }
        return data
    }

    private func escapeCSV(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    // MARK: - Import

    /// Imports vault items from the specified data and format.
    func importItems(
        from data: Data,
        format: ImportFormat,
        password: String? = nil
    ) throws -> ([any VaultItem], ImportResult) {
        switch format {
        case .dodopassEncrypted:
            guard let password = password, !password.isEmpty else {
                throw ImportExportError.passwordRequired
            }
            return try importEncrypted(data: data, password: password)

        case .dodopassJSON:
            return try importJSON(data: data)

        case .onePasswordCSV:
            return try import1PasswordCSV(data: data)

        case .chromeCSV:
            return try importChromeCSV(data: data)

        case .genericCSV:
            return try importGenericCSV(data: data)
        }
    }

    private func importEncrypted(data: Data, password: String) throws -> ([any VaultItem], ImportResult) {
        // Verify magic bytes
        guard data.count > 37,
              String(data: data.prefix(4), encoding: .utf8) == "DODO" else {
            throw ImportExportError.invalidFormat
        }

        let version = data[4]
        guard version == 1 else {
            throw ImportExportError.unsupportedVersion
        }

        let salt = data[5..<37]
        let encrypted = data[37...]

        // Decrypt
        let key = try KeyDerivation.deriveKey(from: password, salt: Data(salt))
        let decrypted = try CryptoService.decrypt(Data(encrypted), using: key)

        // Parse JSON
        return try importJSON(data: decrypted)
    }

    private func importJSON(data: Data) throws -> ([any VaultItem], ImportResult) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportedVault = try decoder.decode(ExportableVault.self, from: data)
        var items: [any VaultItem] = []
        var errors: [String] = []

        for login in exportedVault.logins {
            items.append(login.toVaultItem())
        }

        for note in exportedVault.secureNotes {
            items.append(note.toVaultItem())
        }

        for card in exportedVault.creditCards {
            items.append(card.toVaultItem())
        }

        for identity in exportedVault.identities {
            items.append(identity.toVaultItem())
        }

        let result = ImportResult(
            itemsImported: items.count,
            itemsSkipped: 0,
            errors: errors
        )

        return (items, result)
    }

    private func import1PasswordCSV(data: Data) throws -> ([any VaultItem], ImportResult) {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportExportError.invalidFormat
        }

        let rows = parseCSV(content)
        guard rows.count > 1 else {
            throw ImportExportError.emptyFile
        }

        let headers = rows[0].map { $0.lowercased() }
        var items: [any VaultItem] = []
        var errors: [String] = []
        var skipped = 0

        // Find column indices for 1Password format
        let titleIndex = headers.firstIndex(of: "title") ?? headers.firstIndex(of: "name")
        let urlIndex = headers.firstIndex(of: "url") ?? headers.firstIndex(of: "website")
        let usernameIndex = headers.firstIndex(of: "username") ?? headers.firstIndex(of: "login")
        let passwordIndex = headers.firstIndex(of: "password")
        let notesIndex = headers.firstIndex(of: "notes") ?? headers.firstIndex(of: "notesplain")
        let totpIndex = headers.firstIndex(of: "otp") ?? headers.firstIndex(of: "one-time password")

        for (index, row) in rows.dropFirst().enumerated() {
            guard row.count > 0, !row.allSatisfy({ $0.isEmpty }) else {
                skipped += 1
                continue
            }

            let title = titleIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? "Imported Item \(index + 1)"
            let url = urlIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let username = usernameIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let password = passwordIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let notes = notesIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let totp = totpIndex.flatMap { row.indices.contains($0) ? row[$0] : nil }

            if password.isEmpty && username.isEmpty && url.isEmpty {
                // Treat as secure note
                if !notes.isEmpty || !title.isEmpty {
                    let note = SecureNote(title: title, content: notes)
                    items.append(note)
                } else {
                    skipped += 1
                }
            } else {
                // Create login item
                var login = LoginItem(
                    title: title,
                    username: username,
                    password: password,
                    urls: url.isEmpty ? [] : [url],
                    notes: notes
                )
                if let totpSecret = totp, !totpSecret.isEmpty {
                    login.totpSecret = extractTOTPSecret(from: totpSecret)
                }
                items.append(login)
            }
        }

        let result = ImportResult(
            itemsImported: items.count,
            itemsSkipped: skipped,
            errors: errors
        )

        return (items, result)
    }

    private func importChromeCSV(data: Data) throws -> ([any VaultItem], ImportResult) {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportExportError.invalidFormat
        }

        let rows = parseCSV(content)
        guard rows.count > 1 else {
            throw ImportExportError.emptyFile
        }

        let headers = rows[0].map { $0.lowercased() }
        var items: [any VaultItem] = []
        var errors: [String] = []
        var skipped = 0

        // Chrome CSV format: name,url,username,password
        let nameIndex = headers.firstIndex(of: "name")
        let urlIndex = headers.firstIndex(of: "url")
        let usernameIndex = headers.firstIndex(of: "username")
        let passwordIndex = headers.firstIndex(of: "password")
        let noteIndex = headers.firstIndex(of: "note") ?? headers.firstIndex(of: "notes")

        for (index, row) in rows.dropFirst().enumerated() {
            guard row.count >= 4 else {
                skipped += 1
                continue
            }

            let name = nameIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let url = urlIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let username = usernameIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let password = passwordIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let notes = noteIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""

            // Use URL domain as title if name is empty
            let title = name.isEmpty ? extractDomain(from: url) : name

            if password.isEmpty && username.isEmpty {
                skipped += 1
                continue
            }

            let login = LoginItem(
                title: title,
                username: username,
                password: password,
                urls: url.isEmpty ? [] : [url],
                notes: notes
            )
            items.append(login)
        }

        let result = ImportResult(
            itemsImported: items.count,
            itemsSkipped: skipped,
            errors: errors
        )

        return (items, result)
    }

    private func importGenericCSV(data: Data) throws -> ([any VaultItem], ImportResult) {
        // Try to detect format and use appropriate importer
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportExportError.invalidFormat
        }

        let rows = parseCSV(content)
        guard rows.count > 1 else {
            throw ImportExportError.emptyFile
        }

        let headers = rows[0].map { $0.lowercased() }

        // Detect format based on headers
        if headers.contains("title") || headers.contains("notesplain") || headers.contains("one-time password") {
            return try import1PasswordCSV(data: data)
        } else {
            return try importChromeCSV(data: data)
        }
    }

    // MARK: - CSV Parsing

    private func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        let chars = Array(content)
        var i = 0

        while i < chars.count {
            let char = chars[i]

            if inQuotes {
                if char == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        // Escaped quote
                        currentField.append("\"")
                        i += 1
                    } else {
                        // End of quoted field
                        inQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if char == "\n" || char == "\r" {
                    if char == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 1
                    }
                    currentRow.append(currentField)
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    currentField = ""
                } else {
                    currentField.append(char)
                }
            }

            i += 1
        }

        // Handle last field/row
        currentRow.append(currentField)
        if !currentRow.allSatisfy({ $0.isEmpty }) {
            rows.append(currentRow)
        }

        return rows
    }

    private func extractTOTPSecret(from value: String) -> String {
        // Handle both raw secret and otpauth:// URI
        if value.lowercased().hasPrefix("otpauth://") {
            if let url = URL(string: value),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let secret = components.queryItems?.first(where: { $0.name == "secret" })?.value {
                return secret
            }
        }
        return value
    }

    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

// MARK: - Errors

enum ImportExportError: LocalizedError {
    case passwordRequired
    case invalidFormat
    case unsupportedVersion
    case encodingFailed
    case emptyFile
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .passwordRequired:
            return "A password is required for this operation."
        case .invalidFormat:
            return "The file format is invalid or corrupted."
        case .unsupportedVersion:
            return "This file version is not supported."
        case .encodingFailed:
            return "Failed to encode the data."
        case .emptyFile:
            return "The file is empty or contains no valid data."
        case .decryptionFailed:
            return "Failed to decrypt the file. Check your password."
        }
    }
}

// MARK: - Exportable Types

struct ExportableVault: Codable {
    let version: Int
    let exportedAt: Date
    let logins: [ExportableLogin]
    let secureNotes: [ExportableSecureNote]
    let creditCards: [ExportableCreditCard]
    let identities: [ExportableIdentity]

    init(from items: VaultItems) {
        self.version = 1
        self.exportedAt = Date()
        self.logins = items.logins.map { ExportableLogin(from: $0) }
        self.secureNotes = items.secureNotes.map { ExportableSecureNote(from: $0) }
        self.creditCards = items.creditCards.map { ExportableCreditCard(from: $0) }
        self.identities = items.identities.map { ExportableIdentity(from: $0) }
    }
}

struct ExportableLogin: Codable {
    let title: String
    let username: String
    let password: String
    let urls: [String]
    let notes: String
    let tags: [String]
    let favorite: Bool
    let totpSecret: String?
    let customFields: [ExportableCustomField]
    let createdAt: Date
    let modifiedAt: Date

    init(from login: LoginItem) {
        self.title = login.title
        self.username = login.username
        self.password = login.password
        self.urls = login.urls
        self.notes = login.notes
        self.tags = login.tags
        self.favorite = login.favorite
        self.totpSecret = login.totpSecret
        self.customFields = login.customFields.map { ExportableCustomField(from: $0) }
        self.createdAt = login.createdAt
        self.modifiedAt = login.modifiedAt
    }

    func toVaultItem() -> LoginItem {
        var login = LoginItem(
            title: title,
            username: username,
            password: password,
            urls: urls,
            notes: notes
        )
        login.tags = tags
        login.favorite = favorite
        login.totpSecret = totpSecret
        login.customFields = customFields.map { $0.toCustomField() }
        return login
    }
}

struct ExportableSecureNote: Codable {
    let title: String
    let content: String
    let notes: String
    let tags: [String]
    let favorite: Bool
    let customFields: [ExportableCustomField]
    let createdAt: Date
    let modifiedAt: Date

    init(from note: SecureNote) {
        self.title = note.title
        self.content = note.content
        self.notes = note.notes
        self.tags = note.tags
        self.favorite = note.favorite
        self.customFields = note.customFields.map { ExportableCustomField(from: $0) }
        self.createdAt = note.createdAt
        self.modifiedAt = note.modifiedAt
    }

    func toVaultItem() -> SecureNote {
        var note = SecureNote(title: title, content: content)
        note.notes = notes
        note.tags = tags
        note.favorite = favorite
        note.customFields = customFields.map { $0.toCustomField() }
        return note
    }
}

struct ExportableCreditCard: Codable {
    let title: String
    let cardholderName: String
    let cardNumber: String
    let expirationMonth: Int
    let expirationYear: Int
    let cvv: String
    let pin: String
    let notes: String
    let tags: [String]
    let favorite: Bool
    let customFields: [ExportableCustomField]
    let createdAt: Date
    let modifiedAt: Date

    init(from card: CreditCard) {
        self.title = card.title
        self.cardholderName = card.cardholderName
        self.cardNumber = card.cardNumber
        self.expirationMonth = card.expirationMonth
        self.expirationYear = card.expirationYear
        self.cvv = card.cvv
        self.pin = card.pin
        self.notes = card.notes
        self.tags = card.tags
        self.favorite = card.favorite
        self.customFields = card.customFields.map { ExportableCustomField(from: $0) }
        self.createdAt = card.createdAt
        self.modifiedAt = card.modifiedAt
    }

    func toVaultItem() -> CreditCard {
        var card = CreditCard(
            title: title,
            cardholderName: cardholderName,
            cardNumber: cardNumber,
            expirationMonth: expirationMonth,
            expirationYear: expirationYear,
            cvv: cvv
        )
        card.pin = pin
        card.notes = notes
        card.tags = tags
        card.favorite = favorite
        card.customFields = customFields.map { $0.toCustomField() }
        return card
    }
}

struct ExportableIdentity: Codable {
    let title: String
    let firstName: String
    let middleName: String
    let lastName: String
    let email: String
    let phone: String
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let dateOfBirth: Date?
    let notes: String
    let tags: [String]
    let favorite: Bool
    let customFields: [ExportableCustomField]
    let createdAt: Date
    let modifiedAt: Date

    init(from identity: Identity) {
        self.title = identity.title
        self.firstName = identity.firstName
        self.middleName = identity.middleName
        self.lastName = identity.lastName
        self.email = identity.email
        self.phone = identity.phone
        self.street = identity.address.street
        self.city = identity.address.city
        self.state = identity.address.state
        self.postalCode = identity.address.postalCode
        self.country = identity.address.country
        self.dateOfBirth = identity.dateOfBirth
        self.notes = identity.notes
        self.tags = identity.tags
        self.favorite = identity.favorite
        self.customFields = identity.customFields.map { ExportableCustomField(from: $0) }
        self.createdAt = identity.createdAt
        self.modifiedAt = identity.modifiedAt
    }

    func toVaultItem() -> Identity {
        var identity = Identity(
            title: title,
            firstName: firstName,
            lastName: lastName
        )
        identity.middleName = middleName
        identity.email = email
        identity.phone = phone
        identity.address = Address(
            street: street,
            city: city,
            state: state,
            postalCode: postalCode,
            country: country
        )
        identity.dateOfBirth = dateOfBirth
        identity.notes = notes
        identity.tags = tags
        identity.favorite = favorite
        identity.customFields = customFields.map { $0.toCustomField() }
        return identity
    }
}

struct ExportableCustomField: Codable {
    let id: UUID
    let label: String
    let value: String
    let fieldType: String
    let isHidden: Bool

    init(from field: CustomField) {
        self.id = field.id
        self.label = field.label
        self.value = field.value
        self.fieldType = field.fieldType.rawValue
        self.isHidden = field.isHidden
    }

    func toCustomField() -> CustomField {
        CustomField(
            label: label,
            value: value,
            fieldType: FieldType(rawValue: fieldType) ?? .text,
            isHidden: isHidden
        )
    }
}
