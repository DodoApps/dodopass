import Foundation
import Combine

/// Monitors and reports sync status.
@MainActor
final class SyncStatusMonitor: ObservableObject {
    // MARK: - Singleton

    static let shared = SyncStatusMonitor()

    // MARK: - Published State

    @Published private(set) var status: SyncStatus = .disabled
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var pendingChanges: Int = 0
    @Published private(set) var isOnline = true

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private let reachability = NetworkReachability()

    // MARK: - Initialization

    private init() {
        setupBindings()
    }

    private func setupBindings() {
        // Monitor iCloud coordinator status
        ICloudCoordinator.shared.$syncStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$status)

        ICloudCoordinator.shared.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastSyncTime)

        // Monitor network reachability
        reachability.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOnline)
    }

    // MARK: - Public API

    /// Format last sync time for display.
    var lastSyncDescription: String {
        guard let lastSync = lastSyncTime else {
            return "Never synced"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
    }

    /// Status message for display.
    var statusMessage: String {
        switch status {
        case .disabled:
            return "iCloud sync disabled"
        case .idle:
            return lastSyncDescription
        case .syncing:
            return "Syncing..."
        case .error(let message):
            return "Sync error: \(message)"
        case .conflict:
            return "Conflict detected"
        }
    }

    /// Check if sync is currently active.
    var isSyncing: Bool {
        if case .syncing = status {
            return true
        }
        return false
    }

    /// Check if there's a sync error.
    var hasError: Bool {
        if case .error = status {
            return true
        }
        return false
    }

    /// Increment pending changes counter.
    func markPendingChange() {
        pendingChanges += 1
    }

    /// Reset pending changes after sync.
    func clearPendingChanges() {
        pendingChanges = 0
    }

    /// Force update status from iCloud coordinator.
    func refresh() {
        Task {
            do {
                let hasConflict = try await ICloudCoordinator.shared.checkForConflicts()
                if hasConflict {
                    status = .conflict(localDate: Date(), remoteDate: Date())
                }
            } catch {
                // Ignore errors during refresh
            }
        }
    }
}

// MARK: - Network Reachability

private class NetworkReachability: ObservableObject {
    @Published var isConnected = true

    private var monitor: Any?

    init() {
        #if canImport(Network)
        setupNetworkMonitor()
        #endif
    }

    #if canImport(Network)
    private func setupNetworkMonitor() {
        // Use NWPathMonitor if available (macOS 10.14+)
        if #available(macOS 10.14, *) {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                DispatchQueue.main.async {
                    self?.isConnected = path.status == .satisfied
                }
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
            self.monitor = monitor
        }
    }
    #endif
}

#if canImport(Network)
import Network
#endif
