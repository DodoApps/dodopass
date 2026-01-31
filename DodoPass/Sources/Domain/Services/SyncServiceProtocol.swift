import Foundation

/// Protocol defining sync operations for iCloud sync.
protocol SyncServiceProtocol {
    /// Whether iCloud sync is enabled.
    var isSyncEnabled: Bool { get }

    /// The current sync status.
    var syncStatus: SyncStatus { get async }

    /// Enables iCloud sync.
    func enableSync() async throws

    /// Disables iCloud sync.
    func disableSync() async throws

    /// Triggers a manual sync.
    func sync() async throws

    /// Handles a detected conflict.
    func resolveConflict(keeping: ConflictResolution) async throws

    /// Gets the last sync date.
    var lastSyncDate: Date? { get async }
}

/// The current sync status.
enum SyncStatus: Equatable {
    case disabled
    case idle
    case syncing
    case error(message: String)
    case conflict(localDate: Date, remoteDate: Date)

    var displayText: String {
        switch self {
        case .disabled:
            return "Sync disabled"
        case .idle:
            return "Up to date"
        case .syncing:
            return "Syncing..."
        case .error(let message):
            return "Error: \(message)"
        case .conflict:
            return "Conflict detected"
        }
    }

    var systemImage: String {
        switch self {
        case .disabled:
            return "icloud.slash"
        case .idle:
            return "checkmark.icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .error:
            return "exclamationmark.icloud"
        case .conflict:
            return "exclamationmark.triangle"
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    var isConflict: Bool {
        if case .conflict = self {
            return true
        }
        return false
    }
}

/// Resolution choice for sync conflicts.
enum ConflictResolution: String {
    case keepLocal = "keepLocal"
    case keepRemote = "keepRemote"
    case merge = "merge"
    case keepBoth = "keepBoth"
}
