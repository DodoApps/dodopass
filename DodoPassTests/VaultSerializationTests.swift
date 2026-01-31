import XCTest
@testable import DodoPass

final class VaultSerializationTests: XCTestCase {
    // MARK: - Item Serialization Tests

    func testLoginItemSerialization() throws {
        let login = LoginItem(
            id: UUID(),
            title: "Test Login",
            username: "user@example.com",
            password: "securePassword123!",
            urls: ["https://example.com", "https://login.example.com"],
            notes: "Test notes",
            tags: ["work", "important"],
            favorite: true,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: ItemIcon(symbolName: "person.fill", colorName: "blue")
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(login)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LoginItem.self, from: data)

        XCTAssertEqual(login.id, decoded.id)
        XCTAssertEqual(login.title, decoded.title)
        XCTAssertEqual(login.username, decoded.username)
        XCTAssertEqual(login.password, decoded.password)
        XCTAssertEqual(login.urls, decoded.urls)
        XCTAssertEqual(login.notes, decoded.notes)
        XCTAssertEqual(login.tags, decoded.tags)
        XCTAssertEqual(login.favorite, decoded.favorite)
    }

    func testSecureNoteSerialization() throws {
        let note = SecureNote(
            id: UUID(),
            title: "Secret Note",
            content: "This is a secret message that needs to be encrypted.",
            notes: "Additional notes",
            tags: ["personal"],
            favorite: false,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: ItemIcon(symbolName: "note.text", colorName: "yellow")
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(note)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SecureNote.self, from: data)

        XCTAssertEqual(note.id, decoded.id)
        XCTAssertEqual(note.title, decoded.title)
        XCTAssertEqual(note.content, decoded.content)
    }

    func testCreditCardSerialization() throws {
        let card = CreditCard(
            id: UUID(),
            title: "Personal Visa",
            cardholderName: "John Doe",
            cardNumber: "4111111111111111",
            expirationMonth: 12,
            expirationYear: 2025,
            cvv: "123",
            pin: "1234",
            notes: "",
            tags: ["finance"],
            favorite: true,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: ItemIcon(symbolName: "creditcard", colorName: "green")
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(card)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CreditCard.self, from: data)

        XCTAssertEqual(card.id, decoded.id)
        XCTAssertEqual(card.cardholderName, decoded.cardholderName)
        XCTAssertEqual(card.cardNumber, decoded.cardNumber)
        XCTAssertEqual(card.expirationMonth, decoded.expirationMonth)
        XCTAssertEqual(card.expirationYear, decoded.expirationYear)
        XCTAssertEqual(card.cvv, decoded.cvv)
    }

    func testIdentitySerialization() throws {
        let identity = Identity(
            id: UUID(),
            title: "Personal ID",
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com",
            phone: "+1 555 123 4567",
            notes: "Primary identity",
            tags: [],
            favorite: false,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: ItemIcon(symbolName: "person.text.rectangle", colorName: "purple")
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(identity)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Identity.self, from: data)

        XCTAssertEqual(identity.id, decoded.id)
        XCTAssertEqual(identity.firstName, decoded.firstName)
        XCTAssertEqual(identity.lastName, decoded.lastName)
        XCTAssertEqual(identity.email, decoded.email)
    }

    // MARK: - Vault Format Tests

    func testVaultFormatEncoding() throws {
        let metadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: Date(),
            modifiedAt: Date(),
            schemaVersion: 1,
            versionVector: ["device1": 1],
            itemCount: 2
        )

        let items: [any VaultItem] = [
            LoginItem(
                id: UUID(),
                title: "Login 1",
                username: "user1",
                password: "pass1",
                urls: [],
                notes: "",
                tags: [],
                favorite: false,
                createdAt: Date(),
                modifiedAt: Date(),
                icon: ItemIcon(symbolName: "key", colorName: "blue")
            ),
            SecureNote(
                id: UUID(),
                title: "Note 1",
                content: "Content",
                notes: "",
                tags: [],
                favorite: false,
                createdAt: Date(),
                modifiedAt: Date(),
                icon: ItemIcon(symbolName: "note", colorName: "yellow")
            )
        ]

        let encryptedMetadata = Data(repeating: 0x01, count: 100)
        let encryptedItems = Data(repeating: 0x02, count: 200)
        let salt = Data(repeating: 0x03, count: 32)
        let verifier = Data(repeating: 0x04, count: 32)

        let encoded = try VaultFormat.encode(
            salt: salt,
            verifier: verifier,
            encryptedMetadata: encryptedMetadata,
            encryptedItems: encryptedItems
        )

        // Verify magic bytes
        XCTAssertEqual(encoded.prefix(4), Data([0x44, 0x4F, 0x44, 0x4F])) // "DODO"

        let decoded = try VaultFormat.decode(encoded)

        XCTAssertEqual(decoded.salt, salt)
        XCTAssertEqual(decoded.verifier, verifier)
        XCTAssertEqual(decoded.encryptedMetadata, encryptedMetadata)
        XCTAssertEqual(decoded.encryptedItems, encryptedItems)
    }

    func testInvalidMagicBytesThrows() {
        let invalidData = Data([0x00, 0x00, 0x00, 0x00]) + Data(repeating: 0x00, count: 100)

        XCTAssertThrowsError(try VaultFormat.decode(invalidData)) { error in
            // Should throw an error about invalid format
        }
    }

    func testUnsupportedVersionThrows() {
        var data = Data([0x44, 0x4F, 0x44, 0x4F]) // "DODO"
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF]) // Invalid version
        data.append(Data(repeating: 0x00, count: 100))

        XCTAssertThrowsError(try VaultFormat.decode(data)) { error in
            // Should throw an error about unsupported version
        }
    }

    // MARK: - VaultItems Collection Tests

    func testVaultItemsFiltering() {
        let login1 = LoginItem(
            id: UUID(),
            title: "Login 1",
            username: "user1",
            password: "pass1",
            urls: [],
            notes: "",
            tags: ["work"],
            favorite: true,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let login2 = LoginItem(
            id: UUID(),
            title: "Login 2",
            username: "user2",
            password: "pass2",
            urls: [],
            notes: "",
            tags: ["personal"],
            favorite: false,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let note = SecureNote(
            id: UUID(),
            title: "Note 1",
            content: "Content",
            notes: "",
            tags: ["work"],
            favorite: true,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: ItemIcon(symbolName: "note", colorName: "yellow")
        )

        let items = VaultItems(items: [login1, login2, note])

        // Test category filtering
        XCTAssertEqual(items.logins.count, 2)
        XCTAssertEqual(items.notes.count, 1)

        // Test favorites
        XCTAssertEqual(items.favorites.count, 2)

        // Test tag filtering
        XCTAssertEqual(items.items(withTag: "work").count, 2)
        XCTAssertEqual(items.items(withTag: "personal").count, 1)

        // Test all items
        XCTAssertEqual(items.allItems.count, 3)
    }

    // MARK: - Metadata Tests

    func testVaultMetadataSerialization() throws {
        let metadata = VaultMetadata(
            id: UUID(),
            name: "My Vault",
            createdAt: Date(),
            modifiedAt: Date(),
            schemaVersion: 1,
            versionVector: ["device1": 1, "device2": 2],
            itemCount: 10
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VaultMetadata.self, from: data)

        XCTAssertEqual(metadata.id, decoded.id)
        XCTAssertEqual(metadata.name, decoded.name)
        XCTAssertEqual(metadata.schemaVersion, decoded.schemaVersion)
        XCTAssertEqual(metadata.versionVector, decoded.versionVector)
        XCTAssertEqual(metadata.itemCount, decoded.itemCount)
    }
}
