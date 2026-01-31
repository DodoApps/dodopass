import Foundation

/// Protocol defining high-level vault operations.
protocol VaultServiceProtocol {
    /// Whether a vault exists.
    var vaultExists: Bool { get async }

    /// Whether the vault is currently unlocked.
    var isUnlocked: Bool { get async }

    /// Creates a new vault with the given master password.
    func createVault(password: String, name: String) async throws

    /// Unlocks the vault with the master password.
    func unlock(password: String) async throws

    /// Unlocks the vault using biometric authentication.
    func unlockWithBiometrics() async throws

    /// Locks the vault and clears all keys.
    func lock() async

    /// Changes the master password.
    func changePassword(currentPassword: String, newPassword: String) async throws

    /// Gets all items in the vault.
    func getAllItems() async throws -> VaultItems

    /// Gets a specific item by ID.
    func getItem(id: UUID) async throws -> (any VaultItem)?

    /// Adds a new item to the vault.
    func addItem(_ item: any VaultItem) async throws

    /// Updates an existing item.
    func updateItem(_ item: any VaultItem) async throws

    /// Deletes an item by ID.
    func deleteItem(id: UUID) async throws

    /// Searches items by query.
    func search(query: String) async throws -> [any VaultItem]

    /// Gets vault statistics.
    func getStatistics() async throws -> VaultStatistics

    /// Exports the vault to an encrypted backup.
    func exportBackup(to url: URL, password: String) async throws

    /// Imports a vault from a backup.
    func importBackup(from url: URL, password: String) async throws
}

/// Errors that can occur during vault operations.
enum VaultError: LocalizedError {
    case vaultNotFound
    case vaultAlreadyExists
    case vaultLocked
    case invalidPassword
    case itemNotFound(id: UUID)
    case encryptionFailed(underlying: Error?)
    case decryptionFailed(underlying: Error?)
    case storageFailed(underlying: Error?)
    case corruptedData
    case migrationFailed(from: Int, to: Int)
    case biometricsFailed(underlying: Error?)
    case biometricsNotEnrolled
    case biometricsNotAvailable
    case passwordTooWeak
    case syncConflict

    var errorDescription: String? {
        switch self {
        case .vaultNotFound:
            return "No vault found. Please create a new vault."
        case .vaultAlreadyExists:
            return "A vault already exists. Please unlock it or delete it first."
        case .vaultLocked:
            return "The vault is locked. Please unlock it first."
        case .invalidPassword:
            return "Incorrect password. Please try again."
        case .itemNotFound(let id):
            return "Item not found: \(id)"
        case .encryptionFailed(let error):
            return "Failed to encrypt data: \(error?.localizedDescription ?? "Unknown error")"
        case .decryptionFailed(let error):
            return "Failed to decrypt data: \(error?.localizedDescription ?? "Unknown error")"
        case .storageFailed(let error):
            return "Storage error: \(error?.localizedDescription ?? "Unknown error")"
        case .corruptedData:
            return "The vault data is corrupted."
        case .migrationFailed(let from, let to):
            return "Failed to migrate vault from version \(from) to \(to)."
        case .biometricsFailed(let error):
            return "Biometric authentication failed: \(error?.localizedDescription ?? "Unknown error")"
        case .biometricsNotEnrolled:
            return "Touch ID not set up for this vault. Please unlock with your password first to enable Touch ID."
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device."
        case .passwordTooWeak:
            return "Password is too weak. Please use at least \(CryptoConstants.minimumPasswordLength) characters."
        case .syncConflict:
            return "A sync conflict was detected. Please resolve it before continuing."
        }
    }
}
