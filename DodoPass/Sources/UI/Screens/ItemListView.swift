import SwiftUI

/// A view showing a list of vault items.
struct ItemListView: View {
    let category: SidebarCategory
    @Binding var selectedItemId: UUID?
    @Binding var searchQuery: String
    @ObservedObject var vaultManager: VaultManager

    @State private var sortOrder: SortOrder = .modifiedDate
    @State private var sortAscending = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            header

            Divider()

            // Item list
            if filteredItems.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .background(DodoColors.backgroundSecondary)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text(category.title)
                    .font(DodoTypography.title)
                    .foregroundColor(DodoColors.textPrimary)

                Spacer()

                Menu {
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            HStack {
                                Text(order.rawValue)
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        sortAscending.toggle()
                    } label: {
                        HStack {
                            Text(sortAscending ? "Ascending" : "Descending")
                            Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14))
                        .foregroundColor(DodoColors.textSecondary)
                }
                .menuStyle(.borderlessButton)
            }

            SearchBar(text: $searchQuery, placeholder: "Search in \(category.title.lowercased())")
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Item List

    private var itemList: some View {
        List(selection: $selectedItemId) {
            ForEach(sortedItems, id: \.id) { item in
                ItemRow(item: item, isSelected: selectedItemId == item.id)
                    .tag(item.id)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Group {
            if !searchQuery.isEmpty {
                EmptyStateView.noSearchResults
            } else {
                switch category {
                case .all:
                    EmptyStateView.noItems
                case .favorites:
                    EmptyStateView.noFavorites
                case .category(let cat):
                    EmptyStateView.noItemsInCategory(cat)
                case .tag(let tag):
                    EmptyStateView(
                        icon: "tag",
                        title: "No items with tag",
                        message: "No items are tagged with \"\(tag)\"."
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func itemContextMenu(for item: any VaultItem) -> some View {
        Button {
            if let login = item as? LoginItem, !login.password.isEmpty {
                ClipboardManager.shared.copy(login.password)
            }
        } label: {
            Label("Copy password", systemImage: "doc.on.doc")
        }
        .disabled(!(item is LoginItem))

        Button {
            if let login = item as? LoginItem, !login.username.isEmpty {
                ClipboardManager.shared.copy(login.username, clearAfter: nil)
            }
        } label: {
            Label("Copy username", systemImage: "person.crop.circle")
        }
        .disabled(!(item is LoginItem))

        Divider()

        Button {
            toggleFavorite(item)
        } label: {
            Label(
                item.favorite ? "Remove from favorites" : "Add to favorites",
                systemImage: item.favorite ? "star.slash" : "star"
            )
        }

        Divider()

        Button(role: .destructive) {
            deleteItem(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Filtering & Sorting

    private var filteredItems: [any VaultItem] {
        var items: [any VaultItem]

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

        if !searchQuery.isEmpty {
            items = items.filter { $0.searchableText().contains(searchQuery.lowercased()) }
        }

        return items
    }

    private var sortedItems: [any VaultItem] {
        let sorted = filteredItems.sorted { lhs, rhs in
            switch sortOrder {
            case .title:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .modifiedDate:
                return lhs.modifiedAt > rhs.modifiedAt
            case .createdDate:
                return lhs.createdAt > rhs.createdAt
            }
        }

        return sortAscending ? sorted.reversed() : sorted
    }

    // MARK: - Actions

    private func toggleFavorite(_ item: any VaultItem) {
        var mutableItem = item
        mutableItem.favorite.toggle()
        Task {
            try? await vaultManager.updateItem(mutableItem)
        }
    }

    private func deleteItem(_ item: any VaultItem) {
        Task {
            try? await vaultManager.deleteItem(id: item.id)
            if selectedItemId == item.id {
                selectedItemId = nil
            }
        }
    }
}

// MARK: - Sort Order

enum SortOrder: String, CaseIterable, Identifiable {
    case title = "Title"
    case modifiedDate = "Modified date"
    case createdDate = "Created date"

    var id: String { rawValue }
}

// MARK: - Preview

#if DEBUG
struct ItemListView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var selectedId: UUID?
        @State private var searchQuery = ""

        var body: some View {
            ItemListView(
                category: .all,
                selectedItemId: $selectedId,
                searchQuery: $searchQuery,
                vaultManager: VaultManager.shared
            )
            .frame(width: 300, height: 500)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
