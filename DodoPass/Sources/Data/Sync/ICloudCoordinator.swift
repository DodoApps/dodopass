import Foundation
import Combine

/// Coordinates iCloud Drive sync for the vault file.
final class ICloudCoordinator: ObservableObject {
    // MARK: - Singleton

    static let shared = ICloudCoordinator()

    // MARK: - Published State

    @Published private(set) var syncStatus: SyncStatus = .disabled
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var hasConflict = false

    // MARK: - Types

    struct SyncError: Error, LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    // MARK: - Private State

    private let containerID = "iCloud.com.dodopass.vault"
    private var metadataQuery: NSMetadataQuery?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var iCloudContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: containerID)
    }

    var iCloudVaultURL: URL? {
        iCloudContainerURL?.appendingPathComponent("Documents/DodoPass.vaultdb")
    }

    var isICloudAvailable: Bool {
        iCloudContainerURL != nil
    }

    // MARK: - Properties for VaultManager Integration

    private var localStorage: VaultStorage?
    private var iCloudStorage: VaultStorage?

    // MARK: - Initialization

    private init() {
        setupMetadataQuery()
    }

    /// Initializer for VaultManager integration.
    init(localStorage: VaultStorage, iCloudStorage: VaultStorage) {
        self.localStorage = localStorage
        self.iCloudStorage = iCloudStorage
        setupMetadataQuery()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public API

    /// Enable iCloud sync.
    func enable() async throws {
        guard isICloudAvailable else {
            throw SyncError(message: "iCloud is not available")
        }

        // Create Documents directory if needed
        if let containerURL = iCloudContainerURL {
            let documentsURL = containerURL.appendingPathComponent("Documents")
            try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        }

        await MainActor.run {
            syncStatus = .idle
        }

        startMonitoring()
        AuditLogger.shared.log("iCloud sync enabled", category: .sync)
    }

    /// Disable iCloud sync.
    func disable() {
        stopMonitoring()

        Task { @MainActor in
            syncStatus = .disabled
        }

        AuditLogger.shared.log("iCloud sync disabled", category: .sync)
    }

    /// Sync the local vault to iCloud.
    func syncToCloud(localData: Data) async throws {
        guard let cloudURL = iCloudVaultURL else {
            throw SyncError(message: "iCloud URL not available")
        }

        await MainActor.run {
            syncStatus = .syncing
        }

        AuditLogger.shared.syncStarted()

        do {
            // Use file coordinator for atomic write
            var coordinatorError: NSError?
            var writeError: Error?

            let coordinator = NSFileCoordinator()
            coordinator.coordinate(
                writingItemAt: cloudURL,
                options: .forReplacing,
                error: &coordinatorError
            ) { url in
                do {
                    try localData.write(to: url, options: .atomic)
                } catch {
                    writeError = error
                }
            }

            if let error = coordinatorError ?? writeError {
                throw error
            }

            await MainActor.run {
                syncStatus = .idle
                lastSyncDate = Date()
            }

            AuditLogger.shared.syncCompleted()

        } catch {
            await MainActor.run {
                syncStatus = .error(message: error.localizedDescription)
            }

            AuditLogger.shared.syncFailed(error: error.localizedDescription)
            throw error
        }
    }

    /// Sync from iCloud to local.
    func syncFromCloud() async throws -> Data? {
        guard let cloudURL = iCloudVaultURL else {
            throw SyncError(message: "iCloud URL not available")
        }

        guard FileManager.default.fileExists(atPath: cloudURL.path) else {
            return nil
        }

        await MainActor.run {
            syncStatus = .syncing
        }

        var coordinatorError: NSError?
        var resultData: Data?
        var readError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: cloudURL,
            options: .withoutChanges,
            error: &coordinatorError
        ) { url in
            do {
                resultData = try Data(contentsOf: url)
            } catch {
                readError = error
            }
        }

        if let error = coordinatorError ?? readError {
            await MainActor.run {
                syncStatus = .error(message: error.localizedDescription)
            }
            throw error
        }

        await MainActor.run {
            syncStatus = .idle
            lastSyncDate = Date()
        }

        return resultData
    }

    /// Check for conflicts.
    func checkForConflicts() async throws -> Bool {
        guard let cloudURL = iCloudVaultURL else { return false }

        var hasConflict = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var coordinatorError: NSError?

            let coordinator = NSFileCoordinator()
            coordinator.coordinate(
                readingItemAt: cloudURL,
                options: [],
                error: &coordinatorError
            ) { url in
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemHasUnresolvedConflictsKey])
                    hasConflict = resourceValues.ubiquitousItemHasUnresolvedConflicts ?? false
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error = coordinatorError {
                continuation.resume(throwing: error)
            }
        }

        await MainActor.run {
            self.hasConflict = hasConflict
        }

        if hasConflict {
            AuditLogger.shared.conflictDetected()
        }

        return hasConflict
    }

    /// Get conflict versions.
    func getConflictVersions() -> [NSFileVersion] {
        guard let cloudURL = iCloudVaultURL else { return [] }

        return NSFileVersion.unresolvedConflictVersionsOfItem(at: cloudURL) ?? []
    }

    /// Resolve conflict by keeping a specific version.
    func resolveConflict(keepVersion: NSFileVersion? = nil, resolution: ConflictResolution) async throws {
        guard let cloudURL = iCloudVaultURL else { return }

        let conflicts = getConflictVersions()

        if let keepVersion = keepVersion {
            // Replace current with kept version
            try keepVersion.replaceItem(at: cloudURL, options: [])
        }

        // Mark all conflict versions as resolved
        for version in conflicts {
            version.isResolved = true
        }

        // Remove conflict versions
        try NSFileVersion.removeOtherVersionsOfItem(at: cloudURL)

        await MainActor.run {
            hasConflict = false
        }

        AuditLogger.shared.conflictResolved(resolution: resolution.rawValue)
    }

    // MARK: - VaultManager Integration

    /// Starts syncing between local and iCloud storage.
    func startSync() async throws {
        try await enable()
    }

    /// Stops syncing.
    func stopSync() async {
        disable()
    }

    /// Performs a sync operation.
    func sync() async throws {
        guard let localStorage = localStorage else { return }
        let localData = try localStorage.readVaultData()
        try await syncToCloud(localData: localData)
    }

    // MARK: - Monitoring

    private func setupMetadataQuery() {
        metadataQuery = NSMetadataQuery()
        metadataQuery?.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery?.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.vaultdb")

        NotificationCenter.default.publisher(for: .NSMetadataQueryDidUpdate, object: metadataQuery)
            .sink { [weak self] _ in
                self?.handleMetadataUpdate()
            }
            .store(in: &cancellables)
    }

    private func startMonitoring() {
        metadataQuery?.start()
    }

    private func stopMonitoring() {
        metadataQuery?.stop()
    }

    private func handleMetadataUpdate() {
        guard let query = metadataQuery else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        for item in query.results {
            guard let metadataItem = item as? NSMetadataItem else { continue }

            // Check download status
            if let downloadStatus = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent {
                    Task { @MainActor in
                        syncStatus = .idle
                    }
                } else if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusDownloaded {
                    Task { @MainActor in
                        syncStatus = .idle
                    }
                }
            }

            // Check upload status
            if let isUploading = metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool,
               isUploading {
                Task { @MainActor in
                    syncStatus = .syncing
                }
            }

            // Check for errors
            if let error = metadataItem.value(forAttribute: NSMetadataUbiquitousItemUploadingErrorKey) as? NSError {
                Task { @MainActor in
                    syncStatus = .error(message: error.localizedDescription)
                }
            }

            // Check for conflicts
            if let hasConflicts = metadataItem.value(forAttribute: NSMetadataUbiquitousItemHasUnresolvedConflictsKey) as? Bool,
               hasConflicts {
                Task { @MainActor in
                    self.hasConflict = true
                }
            }
        }
    }
}

// ConflictResolution is defined in SyncServiceProtocol.swift
