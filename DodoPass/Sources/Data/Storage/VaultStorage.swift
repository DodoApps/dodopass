import Foundation

/// Handles file I/O operations for the vault.
final class VaultStorage: StorageServiceProtocol {
    // MARK: - Properties

    let vaultURL: URL
    private let backupDirectory: URL
    private let fileManager: FileManager

    // MARK: - Initialization

    init(
        vaultURL: URL? = nil,
        backupDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        // Default vault location
        if let url = vaultURL {
            self.vaultURL = url
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dodoPassDir = appSupport.appendingPathComponent("DodoPass", isDirectory: true)
            self.vaultURL = dodoPassDir.appendingPathComponent(CryptoConstants.defaultVaultFilename)
        }

        // Default backup location
        if let backup = backupDirectory {
            self.backupDirectory = backup
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.backupDirectory = appSupport
                .appendingPathComponent("DodoPass", isDirectory: true)
                .appendingPathComponent("Backups", isDirectory: true)
        }

        // Ensure directories exist
        ensureDirectoriesExist()
    }

    /// Creates a storage instance for iCloud sync.
    static func iCloudStorage() -> VaultStorage? {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: "iCloud.com.dodopass.vault"
        ) else {
            return nil
        }

        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let vaultURL = documentsURL.appendingPathComponent(CryptoConstants.defaultVaultFilename)
        let backupDir = documentsURL.appendingPathComponent("Backups", isDirectory: true)

        return VaultStorage(vaultURL: vaultURL, backupDirectory: backupDir)
    }

    // MARK: - Directory Management

    private func ensureDirectoriesExist() {
        let vaultDir = vaultURL.deletingLastPathComponent()

        do {
            if !fileManager.fileExists(atPath: vaultDir.path) {
                try fileManager.createDirectory(at: vaultDir, withIntermediateDirectories: true)
            }

            if !fileManager.fileExists(atPath: backupDirectory.path) {
                try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            }
        } catch {
            AuditLogger.shared.log("Failed to create directories: \(error.localizedDescription)", category: .vault, level: .warning)
        }
    }

    // MARK: - StorageServiceProtocol

    func vaultExists() -> Bool {
        fileManager.fileExists(atPath: vaultURL.path)
    }

    func readVaultData() throws -> Data {
        guard vaultExists() else {
            throw StorageError.fileNotFound
        }

        do {
            return try Data(contentsOf: vaultURL)
        } catch {
            throw StorageError.readFailed(underlying: error)
        }
    }

    func writeVaultData(_ data: Data) throws {
        let directory = vaultURL.deletingLastPathComponent()

        // Ensure directory exists
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // Write atomically using a temporary file
        let tempURL = directory.appendingPathComponent(UUID().uuidString + ".tmp")

        do {
            try data.write(to: tempURL, options: .atomic)

            // If vault exists, remove it first
            if vaultExists() {
                try fileManager.removeItem(at: vaultURL)
            }

            // Rename temp file to vault
            try fileManager.moveItem(at: tempURL, to: vaultURL)

            AuditLogger.shared.log("Vault saved successfully", category: .vault)
        } catch {
            // Clean up temp file if it exists
            try? fileManager.removeItem(at: tempURL)
            throw StorageError.writeFailed(underlying: error)
        }
    }

    func deleteVault() throws {
        guard vaultExists() else { return }

        do {
            try fileManager.removeItem(at: vaultURL)
            AuditLogger.shared.log("Vault deleted", category: .vault)
        } catch {
            throw StorageError.deleteFailed(underlying: error)
        }
    }

    // MARK: - Backups

    func createBackup() throws -> URL {
        guard vaultExists() else {
            throw StorageError.fileNotFound
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupName = "DodoPass-Backup-\(timestamp).\(CryptoConstants.vaultFileExtension)"
        let backupURL = backupDirectory.appendingPathComponent(backupName)

        do {
            // Ensure backup directory exists
            if !fileManager.fileExists(atPath: backupDirectory.path) {
                try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            }

            try fileManager.copyItem(at: vaultURL, to: backupURL)
            AuditLogger.shared.log("Backup created: \(backupName)", category: .vault)

            // Rotate old backups (keep last 10)
            try rotateBackups(keepLast: 10)

            return backupURL
        } catch {
            throw StorageError.backupFailed(underlying: error)
        }
    }

    func restoreFromBackup(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw StorageError.fileNotFound
        }

        do {
            // Create a backup of current vault before restoring
            if vaultExists() {
                _ = try? createBackup()
                try fileManager.removeItem(at: vaultURL)
            }

            try fileManager.copyItem(at: url, to: vaultURL)
            AuditLogger.shared.log("Vault restored from backup", category: .vault)
        } catch {
            throw StorageError.restoreFailed(underlying: error)
        }
    }

    func listBackups() throws -> [BackupInfo] {
        guard fileManager.fileExists(atPath: backupDirectory.path) else {
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            return try contents
                .filter { $0.pathExtension == CryptoConstants.vaultFileExtension }
                .map { url in
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    let createdAt = attributes[.creationDate] as? Date ?? Date()
                    let fileSize = attributes[.size] as? UInt64 ?? 0

                    return BackupInfo(
                        id: UUID(),
                        url: url,
                        createdAt: createdAt,
                        fileSize: fileSize
                    )
                }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            throw StorageError.readFailed(underlying: error)
        }
    }

    func deleteBackup(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: url)
            AuditLogger.shared.log("Backup deleted", category: .vault)
        } catch {
            throw StorageError.deleteFailed(underlying: error)
        }
    }

    private func rotateBackups(keepLast count: Int) throws {
        let backups = try listBackups()
        let toDelete = backups.dropFirst(count)

        for backup in toDelete {
            try? deleteBackup(at: backup.url)
        }
    }

    // MARK: - File Coordination (for iCloud)

    /// Reads vault data with file coordination (for iCloud sync).
    func coordinatedRead() throws -> Data {
        var coordinatorError: NSError?
        var readError: Error?
        var result: Data?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: vaultURL,
            options: [],
            error: &coordinatorError
        ) { url in
            do {
                result = try Data(contentsOf: url)
            } catch {
                readError = error
            }
        }

        if let error = coordinatorError {
            throw StorageError.coordinationFailed(underlying: error)
        }

        if let error = readError {
            throw StorageError.readFailed(underlying: error)
        }

        guard let data = result else {
            throw StorageError.fileNotFound
        }

        return data
    }

    /// Writes vault data with file coordination (for iCloud sync).
    func coordinatedWrite(_ data: Data) throws {
        var coordinatorError: NSError?
        var writeError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: vaultURL,
            options: .forReplacing,
            error: &coordinatorError
        ) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }

        if let error = coordinatorError {
            throw StorageError.coordinationFailed(underlying: error)
        }

        if let error = writeError {
            throw StorageError.writeFailed(underlying: error)
        }
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case fileNotFound
    case readFailed(underlying: Error?)
    case writeFailed(underlying: Error?)
    case deleteFailed(underlying: Error?)
    case backupFailed(underlying: Error?)
    case restoreFailed(underlying: Error?)
    case coordinationFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Vault file not found"
        case .readFailed(let error):
            return "Failed to read vault: \(error?.localizedDescription ?? "Unknown error")"
        case .writeFailed(let error):
            return "Failed to write vault: \(error?.localizedDescription ?? "Unknown error")"
        case .deleteFailed(let error):
            return "Failed to delete vault: \(error?.localizedDescription ?? "Unknown error")"
        case .backupFailed(let error):
            return "Failed to create backup: \(error?.localizedDescription ?? "Unknown error")"
        case .restoreFailed(let error):
            return "Failed to restore from backup: \(error?.localizedDescription ?? "Unknown error")"
        case .coordinationFailed(let error):
            return "File coordination failed: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}
