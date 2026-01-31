import XCTest
@testable import DodoPass

final class SearchIndexTests: XCTestCase {
    var searchIndex: SearchIndex!

    override func setUp() {
        super.setUp()
        searchIndex = SearchIndex.shared
        searchIndex.clear()
    }

    override func tearDown() {
        searchIndex.clear()
        super.tearDown()
    }

    // MARK: - Basic Search Tests

    func testBasicSearch() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        // Wait for async rebuild
        Thread.sleep(forTimeInterval: 0.1)

        let results = searchIndex.search(query: "github")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "GitHub")
    }

    func testSearchByUsername() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        let results = searchIndex.search(query: "john")
        XCTAssertTrue(results.contains { $0.title == "Gmail" })
    }

    func testSearchByTag() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        let results = searchIndex.search(query: "work")
        XCTAssertTrue(results.count >= 1)
    }

    func testPrefixSearch() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        // Should match "GitHub" with prefix "git"
        let results = searchIndex.search(query: "git")
        XCTAssertTrue(results.contains { $0.title == "GitHub" })
    }

    func testCaseInsensitiveSearch() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        let results1 = searchIndex.search(query: "GITHUB")
        let results2 = searchIndex.search(query: "github")
        let results3 = searchIndex.search(query: "GitHub")

        XCTAssertEqual(results1.count, results2.count)
        XCTAssertEqual(results2.count, results3.count)
    }

    func testEmptySearch() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        let results = searchIndex.search(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testNoMatchSearch() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        let results = searchIndex.search(query: "nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Multi-Token Search Tests

    func testMultiTokenSearch() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        // Search for items matching both tokens
        let results = searchIndex.search(query: "john gmail")
        XCTAssertTrue(results.contains { $0.title == "Gmail" })
    }

    // MARK: - Index Update Tests

    func testUpdateItem() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        // Create updated item
        var updatedItem = items[0] // GitHub login
        updatedItem.title = "New Title"

        searchIndex.updateItem(updatedItem)

        Thread.sleep(forTimeInterval: 0.1)

        // Old search should not find it
        let oldResults = searchIndex.search(query: "github")
        XCTAssertTrue(oldResults.isEmpty)

        // New search should find it
        let newResults = searchIndex.search(query: "new title")
        XCTAssertFalse(newResults.isEmpty)
    }

    func testRemoveItem() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        // Remove first item
        searchIndex.removeItem(id: items[0].id)

        Thread.sleep(forTimeInterval: 0.1)

        let results = searchIndex.search(query: "github")
        XCTAssertTrue(results.isEmpty)
    }

    func testClearIndex() {
        let items = createTestItems()
        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        searchIndex.clear()

        Thread.sleep(forTimeInterval: 0.1)

        let results = searchIndex.search(query: "github")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Scoring Tests

    func testFavoritesRankHigher() {
        let login1 = LoginItem(
            id: UUID(),
            title: "Test Login",
            username: "user",
            password: "pass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let login2 = LoginItem(
            id: UUID(),
            title: "Test Login Favorite",
            username: "user",
            password: "pass",
            urls: [],
            notes: "",
            tags: [],
            favorite: true,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        searchIndex.rebuildIndex(with: [login1, login2])

        Thread.sleep(forTimeInterval: 0.1)

        let results = searchIndex.search(query: "test login")

        // Favorite should be first
        if results.count >= 2 {
            XCTAssertTrue(results[0].favorite)
        }
    }

    func testSearchLimit() {
        // Create many items
        var items: [any VaultItem] = []
        for i in 0..<100 {
            items.append(LoginItem(
                id: UUID(),
                title: "Login \(i)",
                username: "user\(i)",
                password: "pass",
                urls: [],
                notes: "",
                tags: [],
                favorite: false,
                createdAt: Date(),
                modifiedAt: Date(),
                icon: ItemIcon(symbolName: "key", colorName: "blue")
            ))
        }

        searchIndex.rebuildIndex(with: items)

        Thread.sleep(forTimeInterval: 0.1)

        let results = searchIndex.search(query: "login", limit: 10)
        XCTAssertLessThanOrEqual(results.count, 10)
    }

    // MARK: - Helper Methods

    private func createTestItems() -> [any VaultItem] {
        [
            LoginItem(
                id: UUID(),
                title: "GitHub",
                username: "developer@example.com",
                password: "securePass123",
                urls: ["https://github.com"],
                notes: "Development account",
                tags: ["work", "development"],
                favorite: true,
                createdAt: Date(),
                modifiedAt: Date(),
                icon: ItemIcon(symbolName: "key", colorName: "blue")
            ),
            LoginItem(
                id: UUID(),
                title: "Gmail",
                username: "john.doe@gmail.com",
                password: "emailPass456",
                urls: ["https://mail.google.com"],
                notes: "Personal email",
                tags: ["personal"],
                favorite: false,
                createdAt: Date(),
                modifiedAt: Date(),
                icon: ItemIcon(symbolName: "key", colorName: "red")
            ),
            SecureNote(
                id: UUID(),
                title: "Secret Note",
                content: "This is a secret message",
                notes: "",
                tags: ["personal"],
                favorite: false,
                createdAt: Date(),
                modifiedAt: Date(),
                icon: ItemIcon(symbolName: "note", colorName: "yellow")
            )
        ]
    }
}
