import SwiftUI

/// A quick switcher (Cmd+K) for fast item access.
struct QuickSwitcher: View {
    @ObservedObject var vaultManager: VaultManager
    var onSelect: (any VaultItem) -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(DodoColors.textSecondary)

                TextField("Search items...", text: $query)
                    .textFieldStyle(.plain)
                    .font(DodoTypography.bodyLarge)
                    .foregroundColor(DodoColors.textPrimary)
                    .focused($isSearchFocused)
                    .onSubmit {
                        selectCurrent()
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DodoColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(DodoColors.backgroundSecondary)

            Divider()

            // Results
            if results.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .frame(width: 500, height: 400)
        .background(DodoColors.background)
        .cornerRadius(Theme.Radius.lg)
        .shadow(color: .black.opacity(0.3), radius: 20)
        .onAppear {
            isSearchFocused = true
        }
        .onExitCommand {
            dismiss()
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
    }

    private var results: [any VaultItem] {
        if query.isEmpty {
            // Show recent items
            return Array(vaultManager.items.allItems.prefix(10))
        }
        return vaultManager.search(query: query)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(DodoColors.textTertiary)

            Text("No results found")
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                    QuickSwitcherRow(
                        item: item,
                        isSelected: index == selectedIndex
                    )
                    .id(index)
                    .onTapGesture {
                        onSelect(item)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private func moveSelection(by offset: Int) {
        let newIndex = selectedIndex + offset
        if newIndex >= 0 && newIndex < results.count {
            selectedIndex = newIndex
        }
    }

    private func selectCurrent() {
        guard !results.isEmpty, selectedIndex < results.count else { return }
        onSelect(results[selectedIndex])
    }
}

// MARK: - Quick Switcher Row

struct QuickSwitcherRow: View {
    let item: any VaultItem
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ItemIconView(icon: item.icon, category: item.category)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                Text(item.title)
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textPrimary)

                Text(item.category.displayName)
                    .font(DodoTypography.caption)
                    .foregroundColor(DodoColors.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 12))
                    .foregroundColor(DodoColors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xxxs)
                    .background(DodoColors.backgroundTertiary)
                    .cornerRadius(Theme.Radius.xs)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(isSelected ? DodoColors.backgroundSelected : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#if DEBUG
struct QuickSwitcher_Previews: PreviewProvider {
    static var previews: some View {
        QuickSwitcher(vaultManager: VaultManager.shared) { item in
            print("Selected: \(item.title)")
        }
    }
}
#endif
