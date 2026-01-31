import Foundation

/// Handles vault schema migrations between versions.
enum VaultMigration {
    // MARK: - Errors

    enum MigrationError: LocalizedError {
        case unsupportedVersion(from: Int, to: Int)
        case migrationFailed(from: Int, to: Int, underlying: Error?)
        case dataCorruption

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let from, let to):
                return "Cannot migrate from version \(from) to \(to)"
            case .migrationFailed(let from, let to, let error):
                return "Migration from version \(from) to \(to) failed: \(error?.localizedDescription ?? "Unknown error")"
            case .dataCorruption:
                return "Data corruption detected during migration"
            }
        }
    }

    // MARK: - Migration

    /// Migrates vault data from one version to another.
    /// - Parameters:
    ///   - data: The raw vault data.
    ///   - fromVersion: The current version.
    ///   - toVersion: The target version.
    /// - Returns: The migrated data.
    static func migrate(
        _ data: Data,
        from fromVersion: Int,
        to toVersion: Int = Int(CryptoConstants.currentFormatVersion)
    ) throws -> Data {
        guard fromVersion < toVersion else {
            // No migration needed
            return data
        }

        var migratedData = data
        var currentVersion = fromVersion

        while currentVersion < toVersion {
            let nextVersion = currentVersion + 1
            migratedData = try migrateStep(migratedData, from: currentVersion, to: nextVersion)
            currentVersion = nextVersion
        }

        AuditLogger.shared.log("Vault migrated from version \(fromVersion) to \(toVersion)", category: .vault)
        return migratedData
    }

    /// Performs a single migration step.
    private static func migrateStep(_ data: Data, from: Int, to: Int) throws -> Data {
        switch (from, to) {
        // Add migration cases here as versions are added
        // case (1, 2):
        //     return try migrateV1toV2(data)
        default:
            // For version 1, no migrations needed yet
            if from == 0 && to == 1 {
                return data
            }
            throw MigrationError.unsupportedVersion(from: from, to: to)
        }
    }

    // MARK: - Version-Specific Migrations

    // Example migration (uncomment when needed):
    // private static func migrateV1toV2(_ data: Data) throws -> Data {
    //     // Decode v1 format
    //     // Transform to v2 format
    //     // Return encoded v2 data
    // }

    // MARK: - Validation

    /// Validates vault data integrity.
    /// - Parameter data: The raw vault data.
    /// - Returns: true if data is valid.
    static func validateData(_ data: Data) -> Bool {
        // Check minimum size
        guard data.count >= 40 else { // magic(4) + version(4) + salt(32)
            return false
        }

        // Check magic bytes
        let magic = data.prefix(4)
        guard magic == CryptoConstants.vaultMagic else {
            return false
        }

        return true
    }

    /// Checks if a migration is needed.
    /// - Parameter data: The raw vault data.
    /// - Returns: true if migration is needed.
    static func needsMigration(_ data: Data) -> Bool {
        guard data.count >= 8 else { return false }

        let versionBytes = data[4..<8]
        let version = versionBytes.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian

        return version < CryptoConstants.currentFormatVersion
    }

    /// Gets the version of a vault file.
    /// - Parameter data: The raw vault data.
    /// - Returns: The version number, or nil if invalid.
    static func getVersion(_ data: Data) -> UInt32? {
        guard data.count >= 8 else { return nil }

        let magic = data.prefix(4)
        guard magic == CryptoConstants.vaultMagic else {
            return nil
        }

        let versionBytes = data[4..<8]
        return versionBytes.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
    }
}
