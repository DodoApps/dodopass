import SwiftUI
import Combine
import UniformTypeIdentifiers

/// ViewModel for settings/preferences.
@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Security Settings

    @Published var useTouchID: Bool = false {
        didSet {
            if useTouchID != oldValue {
                toggleTouchID(enabled: useTouchID)
            }
        }
    }
    @AppStorage("autoLockTimeout") var autoLockTimeout: TimeInterval = 300
    @AppStorage("clipboardClearTimeout") var clipboardClearTimeout: TimeInterval = 30

    @Published var touchIDError: String?

    // MARK: - Sync Settings

    @Published var iCloudSyncEnabled = false
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false

    // MARK: - Backup Settings

    @AppStorage("autoBackupEnabled") var autoBackupEnabled = true

    // MARK: - Appearance Settings

    @AppStorage("showInMenuBar") var showInMenuBar = true
    @AppStorage("startAtLogin") var startAtLogin = false

    // MARK: - State

    @Published var showChangePassword = false
    @Published var showDeleteConfirmation = false
    @Published var showExportSheet = false
    @Published var showImportSheet = false
    @Published var importExportError: String?
    @Published var importExportSuccess: String?

    // MARK: - Initialization

    init() {
        // Load Touch ID state from VaultManager
        useTouchID = VaultManager.shared.isBiometricsEnrolled
        loadSyncSettings()
    }

    // MARK: - Touch ID

    private func toggleTouchID(enabled: Bool) {
        Task {
            if enabled {
                do {
                    try await VaultManager.shared.enableBiometrics()
                    touchIDError = nil
                    AuditLogger.shared.log("Touch ID enabled via settings", category: .security)
                } catch {
                    // Revert the toggle
                    useTouchID = false
                    touchIDError = error.localizedDescription
                    AuditLogger.shared.log("Failed to enable Touch ID: \(error.localizedDescription)", category: .security, level: .warning)
                }
            } else {
                // Disable Touch ID by removing key from keychain
                do {
                    let keychainService = KeychainService()
                    try keychainService.deleteMasterKey()
                    touchIDError = nil
                    AuditLogger.shared.log("Touch ID disabled via settings", category: .security)
                } catch {
                    touchIDError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Sync

    private func loadSyncSettings() {
        // Check if iCloud is enabled
        iCloudSyncEnabled = VaultStorage.iCloudStorage() != nil
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    func syncNow() {
        isSyncing = true

        Task {
            do {
                try await VaultManager.shared.syncNow()
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            } catch {
                // Handle error
                print("Sync error: \(error)")
            }
            isSyncing = false
        }
    }

    // MARK: - Backup

    func createBackup() {
        Task {
            do {
                _ = try await VaultManager.shared.createBackup()
            } catch {
                print("Backup error: \(error)")
            }
        }
    }

    func exportVault() {
        showExportSheet = true
    }

    func importVault() {
        showImportSheet = true
    }

    func performExport(format: ImportExportService.ExportFormat, password: String?) {
        Task {
            do {
                let items = VaultManager.shared.items
                let data = try ImportExportService.shared.export(items: items, format: format, password: password)

                // Show save panel
                let panel = NSSavePanel()
                panel.allowedContentTypes = [format.utType]
                panel.nameFieldStringValue = "DodoPass-Export-\(Date().formatted(.dateTime.year().month().day())).\(format.fileExtension)"

                guard panel.runModal() == .OK, let url = panel.url else { return }

                try data.write(to: url)
                importExportSuccess = "Exported \(items.allItems.count) items successfully"
                AuditLogger.shared.log("Exported vault with \(items.allItems.count) items", category: .vault)
            } catch {
                importExportError = error.localizedDescription
                AuditLogger.shared.log("Export failed: \(error.localizedDescription)", category: .vault, level: .error)
            }
        }
    }

    func performImport(format: ImportExportService.ImportFormat, fileURL: URL, password: String?) {
        Task {
            do {
                let data = try Data(contentsOf: fileURL)
                let (importedItems, result) = try ImportExportService.shared.importItems(from: data, format: format, password: password)

                // Add items to vault
                for item in importedItems {
                    try await VaultManager.shared.addItem(item)
                }

                importExportSuccess = "Imported \(result.itemsImported) items (\(result.itemsSkipped) skipped)"
                AuditLogger.shared.log("Imported \(result.itemsImported) items", category: .vault)
            } catch {
                importExportError = error.localizedDescription
                AuditLogger.shared.log("Import failed: \(error.localizedDescription)", category: .vault, level: .error)
            }
        }
    }

    // MARK: - Delete Vault

    func deleteVault() {
        Task {
            // Lock the vault first
            await VaultManager.shared.lock()

            // Delete the vault file
            let storage = VaultStorage()
            try? storage.deleteVault()

            // Restart app
            NSApplication.shared.terminate(nil)
        }
    }
}
