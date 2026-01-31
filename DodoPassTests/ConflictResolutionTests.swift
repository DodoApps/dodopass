import XCTest
@testable import DodoPass

final class ConflictResolutionTests: XCTestCase {
    let resolver = ConflictResolver.shared

    // MARK: - Conflict Detection Tests

    func testNoConflictWhenIdentical() {
        let now = Date()

        let item = LoginItem(
            id: UUID(),
            title: "Test",
            username: "user",
            password: "pass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now,
            modifiedAt: now,
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let metadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now,
            modifiedAt: now,
            schemaVersion: 1,
            versionVector: [:],
            itemCount: 1
        )

        let localItems = VaultItems(items: [item])
        let remoteItems = VaultItems(items: [item])

        let conflictInfo = resolver.detectConflicts(
            local: (metadata, localItems),
            remote: (metadata, remoteItems)
        )

        XCTAssertTrue(conflictInfo.conflictingItems.isEmpty)
    }

    func testDetectsModifiedBothConflict() {
        let now = Date()
        let id = UUID()

        let localItem = LoginItem(
            id: id,
            title: "Local Title",
            username: "user",
            password: "pass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let remoteItem = LoginItem(
            id: id,
            title: "Remote Title",
            username: "user",
            password: "pass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now.addingTimeInterval(10), // Different modification time
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let metadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            schemaVersion: 1,
            versionVector: [:],
            itemCount: 1
        )

        let localItems = VaultItems(items: [localItem])
        let remoteItems = VaultItems(items: [remoteItem])

        let conflictInfo = resolver.detectConflicts(
            local: (metadata, localItems),
            remote: (metadata, remoteItems)
        )

        XCTAssertEqual(conflictInfo.conflictingItems.count, 1)
        XCTAssertEqual(conflictInfo.conflictingItems.first?.conflictType, .modifiedBoth)
    }

    func testNoConflictForLocalOnlyAddition() {
        let now = Date()

        let localItem = LoginItem(
            id: UUID(),
            title: "New Local Item",
            username: "user",
            password: "pass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now,
            modifiedAt: now,
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let metadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            schemaVersion: 1,
            versionVector: [:],
            itemCount: 0
        )

        let localItems = VaultItems(items: [localItem])
        let remoteItems = VaultItems(items: [])

        let conflictInfo = resolver.detectConflicts(
            local: (metadata, localItems),
            remote: (metadata, remoteItems)
        )

        // New local additions should not be conflicts
        XCTAssertTrue(conflictInfo.conflictingItems.isEmpty)
    }

    // MARK: - Merge Strategy Tests

    func testLastWriteWinsMerge() {
        let now = Date()
        let id = UUID()

        let localItem = LoginItem(
            id: id,
            title: "Local Title",
            username: "user",
            password: "localPass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let remoteItem = LoginItem(
            id: id,
            title: "Remote Title",
            username: "user",
            password: "remotePass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now.addingTimeInterval(10), // Remote is newer
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let metadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            schemaVersion: 1,
            versionVector: [:],
            itemCount: 1
        )

        let localItems = VaultItems(items: [localItem])
        let remoteItems = VaultItems(items: [remoteItem])

        let result = resolver.mergeLastWriteWins(
            local: (metadata, localItems),
            remote: (metadata, remoteItems)
        )

        // Should keep remote (newer) item
        XCTAssertEqual(result.mergedItems.allItems.count, 1)
        XCTAssertEqual(result.mergedItems.allItems.first?.title, "Remote Title")
    }

    func testKeepBothMerge() {
        let now = Date()
        let id = UUID()

        let localItem = LoginItem(
            id: id,
            title: "Local Title",
            username: "user",
            password: "localPass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let remoteItem = LoginItem(
            id: id,
            title: "Remote Title",
            username: "user",
            password: "remotePass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now.addingTimeInterval(10),
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let metadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            schemaVersion: 1,
            versionVector: [:],
            itemCount: 1
        )

        let localItems = VaultItems(items: [localItem])
        let remoteItems = VaultItems(items: [remoteItem])

        let result = resolver.mergeKeepBoth(
            local: (metadata, localItems),
            remote: (metadata, remoteItems)
        )

        // Should keep both items
        XCTAssertEqual(result.mergedItems.allItems.count, 2)

        let titles = result.mergedItems.allItems.map(\.title)
        XCTAssertTrue(titles.contains("Local Title"))
        XCTAssertTrue(titles.contains { $0.contains("Conflict Copy") })
    }

    func testMergeNonConflictingItems() {
        let now = Date()

        let localItem = LoginItem(
            id: UUID(),
            title: "Local Only",
            username: "user",
            password: "pass",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now,
            modifiedAt: now,
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let remoteItem = LoginItem(
            id: UUID(),
            title: "Remote Only",
            username: "user2",
            password: "pass2",
            urls: [],
            notes: "",
            tags: [],
            favorite: false,
            createdAt: now,
            modifiedAt: now,
            icon: ItemIcon(symbolName: "key", colorName: "blue")
        )

        let metadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            schemaVersion: 1,
            versionVector: [:],
            itemCount: 1
        )

        let localItems = VaultItems(items: [localItem])
        let remoteItems = VaultItems(items: [remoteItem])

        let result = resolver.mergeLastWriteWins(
            local: (metadata, localItems),
            remote: (metadata, remoteItems)
        )

        // Should include both non-conflicting items
        XCTAssertEqual(result.mergedItems.allItems.count, 2)
    }

    // MARK: - Version Vector Tests

    func testVersionVectorMerge() {
        let now = Date()

        let localMetadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            schemaVersion: 1,
            versionVector: ["device1": 5, "device2": 3],
            itemCount: 1
        )

        let remoteMetadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            schemaVersion: 1,
            versionVector: ["device1": 3, "device2": 7, "device3": 2],
            itemCount: 1
        )

        let localItems = VaultItems(items: [])
        let remoteItems = VaultItems(items: [])

        let result = resolver.mergeLastWriteWins(
            local: (localMetadata, localItems),
            remote: (remoteMetadata, remoteItems)
        )

        // Merged version vector should have max of each
        XCTAssertEqual(result.mergedMetadata.versionVector["device1"], 5)
        XCTAssertEqual(result.mergedMetadata.versionVector["device2"], 7)
        XCTAssertEqual(result.mergedMetadata.versionVector["device3"], 2)
    }

    // MARK: - Schema Version Tests

    func testSchemaVersionTakesMax() {
        let now = Date()

        let localMetadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            schemaVersion: 1,
            versionVector: [:],
            itemCount: 0
        )

        let remoteMetadata = VaultMetadata(
            id: UUID(),
            name: "Test Vault",
            createdAt: now.addingTimeInterval(-100),
            modifiedAt: now,
            schemaVersion: 2,
            versionVector: [:],
            itemCount: 0
        )

        let localItems = VaultItems(items: [])
        let remoteItems = VaultItems(items: [])

        let result = resolver.mergeLastWriteWins(
            local: (localMetadata, localItems),
            remote: (remoteMetadata, remoteItems)
        )

        XCTAssertEqual(result.mergedMetadata.schemaVersion, 2)
    }
}
