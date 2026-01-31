import Foundation

/// Manages automatic backups of the vault.
actor BackupManager {
    // MARK: - Properties

    private let storage: VaultStorage
    private let maxBackups: Int
    private let autoBackupInterval: TimeInterval
    private var lastBackupDate: Date?
    private var autoBackupTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        storage: VaultStorage,
        maxBackups: Int = 10,
        autoBackupInterval: TimeInterval = 3600 // 1 hour
    ) {
        self.storage = storage
        self.maxBackups = maxBackups
        self.autoBackupInterval = autoBackupInterval
    }

    deinit {
        autoBackupTask?.cancel()
    }

    // MARK: - Auto Backup

    /// Starts automatic backup scheduling.
    func startAutoBackup() {
        stopAutoBackup()

        autoBackupTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(autoBackupInterval * 1_000_000_000))

                if Task.isCancelled { break }

                do {
                    try await createAutoBackup()
                } catch {
                    AuditLogger.shared.log("Auto backup failed: \(error.localizedDescription)", category: .vault, level: .warning)
                }
            }
        }

        AuditLogger.shared.log("Auto backup started", category: .vault)
    }

    /// Stops automatic backup scheduling.
    func stopAutoBackup() {
        autoBackupTask?.cancel()
        autoBackupTask = nil
        AuditLogger.shared.log("Auto backup stopped", category: .vault)
    }

    /// Creates an automatic backup if enough time has passed.
    private func createAutoBackup() async throws {
        if let lastBackup = lastBackupDate {
            let elapsed = Date().timeIntervalSince(lastBackup)
            guard elapsed >= autoBackupInterval else { return }
        }

        _ = try storage.createBackup()
        lastBackupDate = Date()
    }

    // MARK: - Manual Backup

    /// Creates a manual backup immediately.
    /// - Returns: The URL of the created backup.
    @discardableResult
    func createBackup() throws -> URL {
        let url = try storage.createBackup()
        lastBackupDate = Date()
        return url
    }

    /// Restores from a specific backup.
    /// - Parameter url: The backup URL to restore from.
    func restore(from url: URL) throws {
        try storage.restoreFromBackup(at: url)
    }

    /// Lists all available backups.
    /// - Returns: Array of backup information.
    func listBackups() throws -> [BackupInfo] {
        try storage.listBackups()
    }

    /// Deletes a specific backup.
    /// - Parameter url: The backup URL to delete.
    func deleteBackup(at url: URL) throws {
        try storage.deleteBackup(at: url)
    }

    /// Deletes all backups.
    func deleteAllBackups() throws {
        let backups = try listBackups()
        for backup in backups {
            try? storage.deleteBackup(at: backup.url)
        }
        AuditLogger.shared.log("All backups deleted", category: .vault)
    }

    // MARK: - Export/Import

    /// Exports the vault to a specified location with a custom password.
    /// - Parameters:
    ///   - destination: The destination URL.
    ///   - password: The password to encrypt the export.
    ///   - cryptoService: The crypto service for encryption.
    func exportVault(
        to destination: URL,
        password: String,
        cryptoService: CryptoService
    ) async throws {
        // Read current vault data
        let vaultData = try storage.readVaultData()

        // Decrypt with current keys
        let container = try VaultFormat.decode(vaultData)
        let metadataData = try await cryptoService.decrypt(container.encryptedMetadata)
        let itemsData = try await cryptoService.decrypt(container.encryptedItems)

        // Re-encrypt with export password
        let exportSalt = KeyDerivation.generateSalt()
        let exportKey = try KeyDerivation.deriveKey(from: password, salt: exportSalt)
        let exportVaultKey = KeyDerivation.deriveSubkey(from: exportKey, for: .vaultEncryption)

        let encryptedMetadata = try CryptoService.encrypt(metadataData, using: exportVaultKey)
        let encryptedItems = try CryptoService.encrypt(itemsData, using: exportVaultKey)

        // Create verifier for export password
        let verifierPlaintext = "DODOPASS_VERIFIER_V1".data(using: .utf8)!
        let encryptedVerifier = try CryptoService.encrypt(verifierPlaintext, using: exportVaultKey)

        // Package export
        let exportContainer = VaultFormat.VaultContainer(
            version: CryptoConstants.currentFormatVersion,
            salt: exportSalt,
            encryptedVerifier: encryptedVerifier,
            encryptedMetadata: encryptedMetadata,
            encryptedItems: encryptedItems
        )

        let exportData = try VaultFormat.encode(exportContainer)
        try exportData.write(to: destination, options: .atomic)

        AuditLogger.shared.log("Vault exported successfully", category: .vault)
    }

    /// Imports a vault from a specified location.
    /// - Parameters:
    ///   - source: The source URL.
    ///   - password: The password for the imported vault.
    ///   - newPassword: Optional new password for the imported vault.
    ///   - cryptoService: The crypto service for encryption.
    func importVault(
        from source: URL,
        password: String,
        newPassword: String? = nil,
        cryptoService: CryptoService
    ) async throws {
        // Read import file
        let importData = try Data(contentsOf: source)
        let container = try VaultFormat.decode(importData)

        // Derive import keys
        let importKey = try KeyDerivation.deriveKey(from: password, salt: container.salt)
        let importVaultKey = KeyDerivation.deriveSubkey(from: importKey, for: .vaultEncryption)

        // Verify password
        let verifierPlaintext = try CryptoService.decrypt(container.encryptedVerifier, using: importVaultKey)
        guard verifierPlaintext == "DODOPASS_VERIFIER_V1".data(using: .utf8) else {
            throw VaultError.invalidPassword
        }

        // Decrypt import data
        let metadataData = try CryptoService.decrypt(container.encryptedMetadata, using: importVaultKey)
        let itemsData = try CryptoService.decrypt(container.encryptedItems, using: importVaultKey)

        // Re-encrypt with new password if provided
        let finalPassword = newPassword ?? password
        let newSalt = KeyDerivation.generateSalt()
        try await cryptoService.deriveKeys(from: finalPassword, salt: newSalt)

        let encryptedMetadata = try await cryptoService.encrypt(metadataData)
        let encryptedItems = try await cryptoService.encrypt(itemsData)
        let encryptedVerifier = try await cryptoService.createPasswordVerifier()

        // Create new vault container
        let newContainer = VaultFormat.VaultContainer(
            version: CryptoConstants.currentFormatVersion,
            salt: newSalt,
            encryptedVerifier: encryptedVerifier,
            encryptedMetadata: encryptedMetadata,
            encryptedItems: encryptedItems
        )

        let vaultData = try VaultFormat.encode(newContainer)
        try storage.writeVaultData(vaultData)

        AuditLogger.shared.log("Vault imported successfully", category: .vault)
    }
}
