import Foundation
import Combine
import AppKit

/// The main actor responsible for vault state and operations.
@MainActor
final class VaultManager: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var isLocked: Bool = true
    @Published private(set) var vaultExists: Bool = false
    @Published private(set) var items: VaultItems = VaultItems()
    @Published private(set) var metadata: VaultMetadata?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: VaultError?
    @Published private(set) var syncStatus: SyncStatus = .disabled

    // MARK: - Services

    private let cryptoService: CryptoService
    private let storage: VaultStorage
    private let keychainService: KeychainService
    private let biometricAuth: BiometricAuth
    private let searchIndex: SearchIndex
    private var iCloudCoordinator: ICloudCoordinator?
    private var backupManager: BackupManager

    // MARK: - Private State

    private var salt: Data?
    private var encryptedVerifier: Data?
    private var autoLockTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton

    static let shared = VaultManager()

    // MARK: - Initialization

    private init() {
        self.cryptoService = CryptoService()
        self.storage = VaultStorage()
        self.keychainService = KeychainService()
        self.biometricAuth = BiometricAuth()
        self.searchIndex = SearchIndex()
        self.backupManager = BackupManager(storage: storage)

        checkVaultExists()
        setupNotifications()
    }

    /// Initializer for testing with injected dependencies.
    init(
        cryptoService: CryptoService,
        storage: VaultStorage,
        keychainService: KeychainService,
        biometricAuth: BiometricAuth
    ) {
        self.cryptoService = cryptoService
        self.storage = storage
        self.keychainService = keychainService
        self.biometricAuth = biometricAuth
        self.searchIndex = SearchIndex()
        self.backupManager = BackupManager(storage: storage)

        checkVaultExists()
    }

    // MARK: - Setup

    private func checkVaultExists() {
        vaultExists = storage.vaultExists()
    }

    private func setupNotifications() {
        // Lock on sleep
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    await self.lock()
                }
            }
            .store(in: &cancellables)

        // Lock on screen lock
        DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.screenIsLocked"))
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    await self.lock()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Vault Lifecycle

    /// Creates a new vault with the given password.
    func createVault(password: String, name: String = "My Vault") async throws {
        guard !vaultExists else {
            throw VaultError.vaultAlreadyExists
        }

        guard password.count >= CryptoConstants.minimumPasswordLength else {
            throw VaultError.passwordTooWeak
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Generate salt and derive keys
            let newSalt = KeyDerivation.generateSalt()
            try await cryptoService.deriveKeys(from: password, salt: newSalt)

            // Create metadata
            var newMetadata = VaultMetadata(name: name)
            newMetadata.recordModification()

            // Create empty items
            let newItems = VaultItems()

            // Encrypt and save
            let encryptedVerifier = try await cryptoService.createPasswordVerifier()
            let encryptedMetadata = try await cryptoService.encrypt(VaultFormat.serializeMetadata(newMetadata))
            let encryptedItems = try await cryptoService.encrypt(VaultFormat.serializeItems(newItems))

            let container = VaultFormat.VaultContainer(
                version: CryptoConstants.currentFormatVersion,
                salt: newSalt,
                encryptedVerifier: encryptedVerifier,
                encryptedMetadata: encryptedMetadata,
                encryptedItems: encryptedItems
            )

            let vaultData = try VaultFormat.encode(container)
            try storage.writeVaultData(vaultData)

            // Store key in keychain for biometrics
            if let keyData = await cryptoService.getMasterKeyData() {
                do {
                    try keychainService.storeMasterKey(keyData)
                    AuditLogger.shared.log("Master key stored in keychain for biometrics", category: .security)
                } catch {
                    // Log but don't fail vault creation - biometrics can be set up later
                    AuditLogger.shared.log("Failed to store master key in keychain: \(error.localizedDescription)", category: .security, level: .warning)
                }
            }

            // Update state
            self.salt = newSalt
            self.encryptedVerifier = encryptedVerifier
            self.metadata = newMetadata
            self.items = newItems
            self.isLocked = false
            self.vaultExists = true

            // Index items for search
            searchIndex.indexItems(newItems.allItems)

            AuditLogger.shared.log( "Vault created successfully")
        } catch let error as VaultError {
            lastError = error
            throw error
        } catch {
            let vaultError = VaultError.storageFailed(underlying: error)
            lastError = vaultError
            throw vaultError
        }
    }

    /// Unlocks the vault with the master password.
    func unlock(password: String) async throws {
        guard vaultExists else {
            throw VaultError.vaultNotFound
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Read and decode vault
            let vaultData = try storage.readVaultData()
            let container = try VaultFormat.decode(vaultData)

            // Verify password
            let isValid = await cryptoService.verifyPassword(
                container.encryptedVerifier,
                password: password,
                salt: container.salt
            )

            guard isValid else {
                throw VaultError.invalidPassword
            }

            // Derive keys
            try await cryptoService.deriveKeys(from: password, salt: container.salt)

            // Decrypt data
            let metadataData = try await cryptoService.decrypt(container.encryptedMetadata)
            let itemsData = try await cryptoService.decrypt(container.encryptedItems)

            let decryptedMetadata = try VaultFormat.deserializeMetadata(metadataData)
            let decryptedItems = try VaultFormat.deserializeItems(itemsData)

            // Store key in keychain for biometrics
            if let keyData = await cryptoService.getMasterKeyData() {
                do {
                    try keychainService.storeMasterKey(keyData)
                    AuditLogger.shared.log("Master key stored in keychain for biometrics", category: .security)
                } catch {
                    // Log but don't fail unlock - biometrics can be set up later
                    AuditLogger.shared.log("Failed to store master key in keychain: \(error.localizedDescription)", category: .security, level: .warning)
                }
            }

            // Update state
            self.salt = container.salt
            self.encryptedVerifier = container.encryptedVerifier
            self.metadata = decryptedMetadata
            self.items = decryptedItems
            self.isLocked = false

            // Index items for search
            searchIndex.indexItems(decryptedItems.allItems)

            // Start auto-backup
            Task {
                await backupManager.startAutoBackup()
            }

            AuditLogger.shared.log( "Vault unlocked with password")
            resetAutoLockTimer()
        } catch let error as VaultError {
            lastError = error
            throw error
        } catch {
            let vaultError = VaultError.decryptionFailed(underlying: error)
            lastError = vaultError
            throw vaultError
        }
    }

    /// Unlocks the vault using biometric authentication.
    func unlockWithBiometrics() async throws {
        guard vaultExists else {
            throw VaultError.vaultNotFound
        }

        guard biometricAuth.isAvailable else {
            throw VaultError.biometricsNotAvailable
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Authenticate with Touch ID
            try await biometricAuth.authenticate(reason: "Unlock your vault")

            // Get key from keychain
            guard let keyData = try keychainService.retrieveMasterKey() else {
                // Key not found - user needs to unlock with password first to store the key
                throw VaultError.biometricsNotEnrolled
            }

            // Read and decode vault
            let vaultData = try storage.readVaultData()
            let container = try VaultFormat.decode(vaultData)

            // Set up crypto with keychain key
            await cryptoService.setMasterKey(keyData)

            // Decrypt data
            let metadataData = try await cryptoService.decrypt(container.encryptedMetadata)
            let itemsData = try await cryptoService.decrypt(container.encryptedItems)

            let decryptedMetadata = try VaultFormat.deserializeMetadata(metadataData)
            let decryptedItems = try VaultFormat.deserializeItems(itemsData)

            // Update state
            self.salt = container.salt
            self.encryptedVerifier = container.encryptedVerifier
            self.metadata = decryptedMetadata
            self.items = decryptedItems
            self.isLocked = false

            // Index items for search
            searchIndex.indexItems(decryptedItems.allItems)

            // Start auto-backup
            Task {
                await backupManager.startAutoBackup()
            }

            AuditLogger.shared.log( "Vault unlocked with biometrics")
            resetAutoLockTimer()
        } catch let error as VaultError {
            lastError = error
            throw error
        } catch {
            let vaultError = VaultError.biometricsFailed(underlying: error)
            lastError = vaultError
            throw vaultError
        }
    }

    /// Locks the vault and clears sensitive data.
    func lock() async {
        await cryptoService.clearKeys()
        searchIndex.clear()

        items = VaultItems()
        metadata = nil
        isLocked = true
        autoLockTimer?.invalidate()
        autoLockTimer = nil

        Task {
            await backupManager.stopAutoBackup()
        }

        AuditLogger.shared.log( "Vault locked")
    }

    // MARK: - Item Operations

    /// Adds a new item to the vault.
    func addItem(_ item: any VaultItem) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }

        items.addItem(item)
        searchIndex.indexItem(item)
        try await save()

        AuditLogger.shared.log( "Item added: \(item.category.rawValue)")
        resetAutoLockTimer()
    }

    /// Updates an existing item.
    func updateItem(_ item: any VaultItem) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }

        items.updateItem(item)
        searchIndex.updateItem(item)
        try await save()

        AuditLogger.shared.log( "Item updated: \(item.id)")
        resetAutoLockTimer()
    }

    /// Deletes an item by ID.
    func deleteItem(id: UUID) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }

        items.removeItem(withId: id)
        searchIndex.removeItem(id: id)
        try await save()

        AuditLogger.shared.log( "Item deleted: \(id)")
        resetAutoLockTimer()
    }

    /// Gets an item by ID.
    func getItem(id: UUID) -> (any VaultItem)? {
        items.item(withId: id)
    }

    // MARK: - Search

    /// Searches items by query.
    func search(query: String) -> [any VaultItem] {
        guard !isLocked else { return [] }
        return searchIndex.search(query: query)
    }

    // MARK: - Persistence

    /// Saves the current vault state.
    private func save() async throws {
        guard let salt = salt else {
            throw VaultError.vaultLocked
        }

        // Update metadata
        metadata?.recordModification()

        guard let metadata = metadata else {
            throw VaultError.vaultLocked
        }

        // Encrypt data
        let encryptedMetadata = try await cryptoService.encrypt(VaultFormat.serializeMetadata(metadata))
        let encryptedItems = try await cryptoService.encrypt(VaultFormat.serializeItems(items))
        let verifier: Data
        if let existingVerifier = encryptedVerifier {
            verifier = existingVerifier
        } else {
            verifier = try await cryptoService.createPasswordVerifier()
        }

        // Create container
        let container = VaultFormat.VaultContainer(
            version: CryptoConstants.currentFormatVersion,
            salt: salt,
            encryptedVerifier: verifier,
            encryptedMetadata: encryptedMetadata,
            encryptedItems: encryptedItems
        )

        // Write to disk
        let vaultData = try VaultFormat.encode(container)
        try storage.writeVaultData(vaultData)

        self.encryptedVerifier = verifier
    }

    // MARK: - Auto Lock

    /// Resets the auto-lock timer.
    private func resetAutoLockTimer() {
        autoLockTimer?.invalidate()
        autoLockTimer = Timer.scheduledTimer(
            withTimeInterval: CryptoConstants.defaultAutoLockTimeout,
            repeats: false
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.lock()
            }
        }
    }

    /// Called on user activity to reset the auto-lock timer.
    func userActivity() {
        guard !isLocked else { return }
        resetAutoLockTimer()
    }

    // MARK: - Password Change

    /// Changes the master password.
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }

        guard newPassword.count >= CryptoConstants.minimumPasswordLength else {
            throw VaultError.passwordTooWeak
        }

        isLoading = true
        defer { isLoading = false }

        // Verify current password
        guard let salt = salt, let verifier = encryptedVerifier else {
            throw VaultError.vaultLocked
        }

        let isValid = await cryptoService.verifyPassword(verifier, password: currentPassword, salt: salt)
        guard isValid else {
            throw VaultError.invalidPassword
        }

        // Generate new salt and derive new keys
        let newSalt = KeyDerivation.generateSalt()
        try await cryptoService.deriveKeys(from: newPassword, salt: newSalt)

        // Re-encrypt and save
        self.salt = newSalt
        self.encryptedVerifier = try await cryptoService.createPasswordVerifier()
        try await save()

        // Update keychain (don't fail password change if keychain update fails)
        if let keyData = await cryptoService.getMasterKeyData() {
            do {
                try keychainService.storeMasterKey(keyData)
                AuditLogger.shared.log("Master key updated in keychain", category: .security)
            } catch {
                // Log but don't fail - Touch ID can be re-enabled later by unlocking with password
                AuditLogger.shared.log("Failed to update master key in keychain: \(error.localizedDescription)", category: .security, level: .warning)
            }
        }

        AuditLogger.shared.log("Password changed successfully")
    }

    // MARK: - Statistics

    /// Gets vault statistics.
    func getStatistics() -> VaultStatistics {
        VaultStatistics(from: items)
    }

    // MARK: - Backup

    /// Creates a backup of the vault.
    @discardableResult
    func createBackup() async throws -> URL {
        try await backupManager.createBackup()
    }

    /// Lists available backups.
    func listBackups() async throws -> [BackupInfo] {
        try await backupManager.listBackups()
    }

    /// Restores from a backup.
    func restoreFromBackup(_ backup: BackupInfo) async throws {
        try await backupManager.restore(from: backup.url)
        // Need to unlock again after restore
        await lock()
    }

    // MARK: - iCloud Sync

    /// Enables iCloud sync.
    func enableICloudSync() async throws {
        guard iCloudCoordinator == nil else { return }

        guard let iCloudStorage = VaultStorage.iCloudStorage() else {
            throw VaultError.storageFailed(underlying: nil)
        }

        iCloudCoordinator = ICloudCoordinator(
            localStorage: storage,
            iCloudStorage: iCloudStorage
        )

        try await iCloudCoordinator?.startSync()
        syncStatus = .idle

        AuditLogger.shared.log( "iCloud sync enabled")
    }

    /// Disables iCloud sync.
    func disableICloudSync() async {
        await iCloudCoordinator?.stopSync()
        iCloudCoordinator = nil
        syncStatus = .disabled

        AuditLogger.shared.log( "iCloud sync disabled")
    }

    /// Triggers a manual sync.
    func syncNow() async throws {
        guard let coordinator = iCloudCoordinator else { return }

        syncStatus = .syncing
        do {
            try await coordinator.sync()
            syncStatus = .idle
        } catch {
            syncStatus = .error(message: error.localizedDescription)
            throw error
        }
    }

    // MARK: - Biometrics

    /// Enables biometric authentication.
    func enableBiometrics() async throws {
        guard biometricAuth.isAvailable else {
            throw VaultError.biometricsNotAvailable
        }

        // Key is already stored in keychain during unlock
        AuditLogger.shared.biometricEnrolled()
    }

    /// Checks if biometrics are available.
    var isBiometricsAvailable: Bool {
        biometricAuth.isAvailable
    }

    /// Checks if biometrics are enrolled.
    var isBiometricsEnrolled: Bool {
        biometricAuth.isEnrolled && keychainService.hasMasterKey()
    }
}
