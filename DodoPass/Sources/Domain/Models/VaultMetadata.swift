import Foundation

/// Metadata about the vault, stored alongside the encrypted items.
struct VaultMetadata: Codable, Equatable {
    /// Schema version for migration purposes.
    let schemaVersion: Int

    /// When the vault was created.
    let createdAt: Date

    /// When the vault was last modified.
    var modifiedAt: Date

    /// When the vault was last synced (if using iCloud).
    var lastSyncedAt: Date?

    /// A unique identifier for this vault.
    let vaultId: UUID

    /// The name of the vault (user-customizable).
    var name: String

    /// Device identifier that last modified the vault.
    var lastModifiedBy: String

    /// Number of times the vault has been modified.
    var modificationCounter: UInt64

    /// Version counter for conflict resolution.
    var versionVector: [String: UInt64]

    init(
        name: String = "My Vault",
        schemaVersion: Int = VaultMetadata.currentSchemaVersion,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        lastSyncedAt: Date? = nil,
        vaultId: UUID = UUID(),
        lastModifiedBy: String = VaultMetadata.deviceIdentifier,
        modificationCounter: UInt64 = 0,
        versionVector: [String: UInt64]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lastSyncedAt = lastSyncedAt
        self.vaultId = vaultId
        self.name = name
        self.lastModifiedBy = lastModifiedBy
        self.modificationCounter = modificationCounter
        self.versionVector = versionVector ?? [lastModifiedBy: modificationCounter]
    }

    /// Current schema version.
    static let currentSchemaVersion = 1

    /// Gets a unique device identifier for conflict resolution.
    static var deviceIdentifier: String {
        #if os(macOS)
        if let serialNumber = getSerialNumber() {
            return serialNumber
        }
        #endif

        // Fallback to a generated identifier stored in UserDefaults
        let key = "com.dodopass.deviceIdentifier"
        if let stored = UserDefaults.standard.string(forKey: key) {
            return stored
        }

        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    #if os(macOS)
    /// Gets the Mac's serial number.
    private static func getSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { return nil }

        defer { IOObjectRelease(platformExpert) }

        guard let serialNumber = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return nil
        }

        return serialNumber
    }
    #endif

    /// Records a modification to the vault.
    mutating func recordModification() {
        modifiedAt = Date()
        modificationCounter += 1
        versionVector[lastModifiedBy] = modificationCounter
    }

    /// Checks if this metadata is newer than another.
    func isNewer(than other: VaultMetadata) -> Bool {
        modificationCounter > other.modificationCounter
    }

    /// Checks if there's a conflict with another vault.
    func hasConflict(with other: VaultMetadata) -> Bool {
        // Check if versions diverged
        guard let ourVersion = versionVector[lastModifiedBy],
              let theirVersion = other.versionVector[other.lastModifiedBy] else {
            return true
        }

        // If they modified from a version we don't know about, or vice versa
        if let theirKnownVersion = versionVector[other.lastModifiedBy],
           other.modificationCounter > theirKnownVersion {
            return true
        }

        if let ourKnownVersion = other.versionVector[lastModifiedBy],
           modificationCounter > ourKnownVersion {
            return true
        }

        return false
    }

    /// Merges version vectors after conflict resolution.
    mutating func mergeVersionVector(with other: VaultMetadata) {
        for (device, version) in other.versionVector {
            if let ourVersion = versionVector[device] {
                versionVector[device] = max(ourVersion, version)
            } else {
                versionVector[device] = version
            }
        }
        recordModification()
    }
}

// MARK: - Vault Statistics

/// Statistics about vault contents.
struct VaultStatistics: Equatable {
    var totalItems: Int
    var loginCount: Int
    var secureNoteCount: Int
    var creditCardCount: Int
    var identityCount: Int
    var favoriteCount: Int
    var tagCount: Int

    init(from items: VaultItems) {
        self.totalItems = items.count
        self.loginCount = items.logins.count
        self.secureNoteCount = items.secureNotes.count
        self.creditCardCount = items.creditCards.count
        self.identityCount = items.identities.count
        self.favoriteCount = items.favorites.count
        self.tagCount = items.allTags.count
    }

    static let empty = VaultStatistics(
        totalItems: 0,
        loginCount: 0,
        secureNoteCount: 0,
        creditCardCount: 0,
        identityCount: 0,
        favoriteCount: 0,
        tagCount: 0
    )

    private init(
        totalItems: Int,
        loginCount: Int,
        secureNoteCount: Int,
        creditCardCount: Int,
        identityCount: Int,
        favoriteCount: Int,
        tagCount: Int
    ) {
        self.totalItems = totalItems
        self.loginCount = loginCount
        self.secureNoteCount = secureNoteCount
        self.creditCardCount = creditCardCount
        self.identityCount = identityCount
        self.favoriteCount = favoriteCount
        self.tagCount = tagCount
    }
}

// MARK: - Import for IOKit

#if os(macOS)
import IOKit
#endif
