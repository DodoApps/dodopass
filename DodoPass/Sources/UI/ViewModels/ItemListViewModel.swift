import SwiftUI
import Combine

/// ViewModel for item list view.
@MainActor
final class ItemListViewModel: ObservableObject {
    // MARK: - Published State

    @Published var searchQuery = ""
    @Published var sortOrder: SortOrder = .modifiedDate
    @Published var sortAscending = false
    @Published private(set) var filteredItems: [any VaultItem] = []

    // MARK: - Private

    private let vaultManager: VaultManager
    private let category: SidebarCategory
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(category: SidebarCategory, vaultManager: VaultManager = .shared) {
        self.category = category
        self.vaultManager = vaultManager
        setupBindings()
    }

    private func setupBindings() {
        // Update filtered items when vault items or search query changes
        Publishers.CombineLatest3(
            vaultManager.$items,
            $searchQuery,
            $sortOrder
        )
        .combineLatest($sortAscending)
        .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _ in
            self?.updateFilteredItems()
        }
        .store(in: &cancellables)
    }

    private func updateFilteredItems() {
        var items: [any VaultItem]

        // Filter by category
        switch category {
        case .all:
            items = vaultManager.items.allItems
        case .favorites:
            items = vaultManager.items.favorites
        case .category(let cat):
            items = vaultManager.items.items(in: cat)
        case .tag(let tag):
            items = vaultManager.items.items(withTag: tag)
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            items = items.filter { $0.searchableText().contains(searchQuery.lowercased()) }
        }

        // Sort
        items = items.sorted { lhs, rhs in
            let comparison: Bool
            switch sortOrder {
            case .title:
                comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .modifiedDate:
                comparison = lhs.modifiedAt > rhs.modifiedAt
            case .createdDate:
                comparison = lhs.createdAt > rhs.createdAt
            }
            return sortAscending ? !comparison : comparison
        }

        filteredItems = items
    }

    // MARK: - Actions

    func deleteItem(_ item: any VaultItem) async throws {
        try await vaultManager.deleteItem(id: item.id)
    }

    func toggleFavorite(_ item: any VaultItem) async throws {
        var mutableItem = item
        mutableItem.favorite.toggle()
        try await vaultManager.updateItem(mutableItem)
    }
}
