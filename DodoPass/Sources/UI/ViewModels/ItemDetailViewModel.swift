import SwiftUI
import Combine

/// ViewModel for item detail view.
@MainActor
final class ItemDetailViewModel: ObservableObject {
    // MARK: - Published State

    @Published var isEditing = false
    @Published var showDeleteConfirmation = false
    @Published var showPasswordHistory = false
    @Published var showPasswordGenerator = false
    @Published private(set) var error: String?

    // MARK: - Private

    private let vaultManager: VaultManager
    private(set) var item: any VaultItem

    // MARK: - Initialization

    init(item: any VaultItem, vaultManager: VaultManager = .shared) {
        self.item = item
        self.vaultManager = vaultManager
    }

    // MARK: - Actions

    func save(_ updatedItem: any VaultItem) async throws {
        try await vaultManager.updateItem(updatedItem)
        item = updatedItem
        isEditing = false
    }

    func delete() async throws {
        try await vaultManager.deleteItem(id: item.id)
    }

    func toggleFavorite() async throws {
        var mutableItem = item
        mutableItem.favorite.toggle()
        try await vaultManager.updateItem(mutableItem)
        item = mutableItem
    }

    func copyPassword() {
        guard let login = item as? LoginItem else { return }
        ClipboardManager.shared.copy(login.password)
    }

    func copyUsername() {
        guard let login = item as? LoginItem else { return }
        ClipboardManager.shared.copy(login.username, clearAfter: nil)
    }

    func copyField(_ value: String, isSecret: Bool = false) {
        ClipboardManager.shared.copy(
            value,
            clearAfter: isSecret ? CryptoConstants.clipboardClearTimeout : nil
        )
    }
}
