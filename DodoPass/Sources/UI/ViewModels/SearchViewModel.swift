import SwiftUI
import Combine

/// ViewModel for search functionality.
@MainActor
final class SearchViewModel: ObservableObject {
    // MARK: - Published State

    @Published var searchQuery = ""
    @Published private(set) var searchResults: [any VaultItem] = []
    @Published private(set) var isSearching = false
    @Published var selectedItem: (any VaultItem)?

    // MARK: - Private

    private let vaultManager: VaultManager
    private let searchIndex: SearchIndex
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(vaultManager: VaultManager = .shared, searchIndex: SearchIndex = .shared) {
        self.vaultManager = vaultManager
        self.searchIndex = searchIndex
        setupBindings()
    }

    private func setupBindings() {
        // Debounce search queries
        $searchQuery
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)

        // Rebuild index when items change
        vaultManager.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.searchIndex.rebuildIndex(with: items.allItems)
            }
            .store(in: &cancellables)
    }

    // MARK: - Search

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchResults = searchIndex.search(query: query)
        isSearching = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        selectedItem = nil
    }

    // MARK: - Quick Actions

    func copyPassword(for item: any VaultItem) {
        guard let login = item as? LoginItem else { return }
        ClipboardManager.shared.copy(login.password)
    }

    func copyUsername(for item: any VaultItem) {
        guard let login = item as? LoginItem else { return }
        ClipboardManager.shared.copy(login.username, clearAfter: nil)
    }

    func openURL(for item: any VaultItem) {
        guard let login = item as? LoginItem,
              let urlString = login.urls.first,
              let url = URL(string: urlString) else { return }

        NSWorkspace.shared.open(url)
    }
}
