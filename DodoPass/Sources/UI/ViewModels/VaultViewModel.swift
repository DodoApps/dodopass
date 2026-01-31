import SwiftUI
import Combine

/// Main ViewModel for vault state management.
@MainActor
final class VaultViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var isLocked: Bool = true
    @Published private(set) var items: VaultItems = VaultItems()
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: VaultError?

    // MARK: - Private

    private let vaultManager: VaultManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(vaultManager: VaultManager = .shared) {
        self.vaultManager = vaultManager
        setupBindings()
    }

    private func setupBindings() {
        vaultManager.$isLocked
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLocked)

        vaultManager.$items
            .receive(on: DispatchQueue.main)
            .assign(to: &$items)

        vaultManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        vaultManager.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }

    // MARK: - Actions

    func unlock(password: String) async throws {
        try await vaultManager.unlock(password: password)
    }

    func unlockWithBiometrics() async throws {
        try await vaultManager.unlockWithBiometrics()
    }

    func lock() async {
        await vaultManager.lock()
    }

    func addItem(_ item: any VaultItem) async throws {
        try await vaultManager.addItem(item)
    }

    func updateItem(_ item: any VaultItem) async throws {
        try await vaultManager.updateItem(item)
    }

    func deleteItem(id: UUID) async throws {
        try await vaultManager.deleteItem(id: id)
    }

    func search(query: String) -> [any VaultItem] {
        vaultManager.search(query: query)
    }
}
