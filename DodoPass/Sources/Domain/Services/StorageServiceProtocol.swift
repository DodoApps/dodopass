import Foundation

/// Protocol defining storage operations for the vault.
protocol StorageServiceProtocol {
    /// The URL where the vault is stored.
    var vaultURL: URL { get }

    /// Returns true if a vault exists at the storage location.
    func vaultExists() -> Bool

    /// Reads the raw vault data from storage.
    func readVaultData() throws -> Data

    /// Writes the raw vault data to storage.
    func writeVaultData(_ data: Data) throws

    /// Deletes the vault from storage.
    func deleteVault() throws

    /// Creates a backup of the current vault.
    func createBackup() throws -> URL

    /// Restores the vault from a backup.
    func restoreFromBackup(at url: URL) throws

    /// Lists all available backups.
    func listBackups() throws -> [BackupInfo]

    /// Deletes a specific backup.
    func deleteBackup(at url: URL) throws
}

/// Information about a vault backup.
struct BackupInfo: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let createdAt: Date
    let fileSize: UInt64

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}
