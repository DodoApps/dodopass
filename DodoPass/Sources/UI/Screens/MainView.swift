import SwiftUI

/// The main application view with NavigationSplitView layout.
struct MainView: View {
    @StateObject private var vaultManager = VaultManager.shared
    @StateObject private var toastManager = ToastManager()

    @State private var selectedCategory: SidebarCategory? = .all
    @State private var selectedItemId: UUID?
    @State private var searchQuery = ""
    @State private var showSettings = false
    @State private var showQuickSwitcher = false
    @State private var showNewItemSheet = false
    @State private var newItemType: ItemCategory?

    var body: some View {
        Group {
            if vaultManager.isLocked {
                LockScreen(vaultManager: vaultManager)
            } else {
                mainContent
            }
        }
        .environment(\.toastManager, toastManager)
        .overlay(alignment: .bottom) {
            ToastContainer(toastManager: toastManager)
        }
    }

    private var mainContent: some View {
        NavigationSplitView {
            SidebarView(
                selectedCategory: $selectedCategory,
                vaultManager: vaultManager
            )
            .frame(minWidth: Theme.Size.sidebarWidth)
        } content: {
            ItemListView(
                category: selectedCategory ?? .all,
                selectedItemId: $selectedItemId,
                searchQuery: $searchQuery,
                vaultManager: vaultManager
            )
            .frame(minWidth: Theme.Size.listWidth)
        } detail: {
            if let itemId = selectedItemId,
               let item = vaultManager.getItem(id: itemId) {
                ItemDetailView(
                    item: item,
                    vaultManager: vaultManager,
                    onDelete: {
                        selectedItemId = nil
                    }
                )
            } else {
                EmptyStateView(
                    icon: "hand.point.left.fill",
                    title: "Select an item",
                    message: "Choose an item from the list to view its details."
                )
            }
        }
        .frame(minWidth: Theme.Size.windowMinWidth, minHeight: Theme.Size.windowMinHeight)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showQuickSwitcher) {
            QuickSwitcher(
                vaultManager: vaultManager,
                onSelect: { item in
                    selectedItemId = item.id
                    showQuickSwitcher = false
                }
            )
        }
        .sheet(item: $newItemType) { category in
            ItemEditorView(
                category: category,
                vaultManager: vaultManager,
                onSave: { item in
                    selectedItemId = item.id
                    newItemType = nil
                },
                onCancel: {
                    newItemType = nil
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .lockVault)) { _ in
            Task {
                await vaultManager.lock()
            }
        }
        .handlesExternalEvents(preferring: [], allowing: [])
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                Task {
                    await vaultManager.lock()
                }
            } label: {
                Image(systemName: "lock.fill")
            }
            .help("Lock vault (⌘L)")
            .keyboardShortcut("l", modifiers: .command)
        }

        ToolbarItemGroup(placement: .automatic) {
            Menu {
                Button {
                    newItemType = .login
                } label: {
                    Label("Login", systemImage: ItemCategory.login.systemImage)
                }

                Button {
                    newItemType = .secureNote
                } label: {
                    Label("Secure note", systemImage: ItemCategory.secureNote.systemImage)
                }

                Button {
                    newItemType = .creditCard
                } label: {
                    Label("Credit card", systemImage: ItemCategory.creditCard.systemImage)
                }

                Button {
                    newItemType = .identity
                } label: {
                    Label("Identity", systemImage: ItemCategory.identity.systemImage)
                }
            } label: {
                Image(systemName: "plus")
            }
            .help("Add new item (⌘N)")
            .keyboardShortcut("n", modifiers: .command)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showQuickSwitcher = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("Quick switcher (⌘K)")
            .keyboardShortcut("k", modifiers: .command)
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let lockVault = Notification.Name("lockVault")
}

// ItemCategory already conforms to Identifiable in VaultItem.swift

// MARK: - Preview

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
#endif
