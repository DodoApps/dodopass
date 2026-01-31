import SwiftUI

/// Sidebar navigation categories.
enum SidebarCategory: Hashable, Identifiable {
    case all
    case favorites
    case category(ItemCategory)
    case tag(String)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .favorites:
            return "favorites"
        case .category(let cat):
            return "category-\(cat.rawValue)"
        case .tag(let tag):
            return "tag-\(tag)"
        }
    }

    var title: String {
        switch self {
        case .all:
            return "All items"
        case .favorites:
            return "Favorites"
        case .category(let cat):
            return cat.displayName
        case .tag(let tag):
            return tag
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "tray.full.fill"
        case .favorites:
            return "star.fill"
        case .category(let cat):
            return cat.systemImage
        case .tag:
            return "tag.fill"
        }
    }
}

/// The sidebar view showing categories and tags.
struct SidebarView: View {
    @Binding var selectedCategory: SidebarCategory?
    @ObservedObject var vaultManager: VaultManager
    var onSettingsTapped: (() -> Void)?

    @State private var isTagsExpanded = true
    @State private var showSettings = false

    var body: some View {
        List(selection: $selectedCategory) {
            // Main sections
            Section {
                SidebarRow(category: .all, count: vaultManager.items.count)
                SidebarRow(category: .favorites, count: vaultManager.items.favorites.count)
            }

            // Categories
            Section("Categories") {
                ForEach(ItemCategory.allCases) { category in
                    SidebarRow(
                        category: .category(category),
                        count: vaultManager.items.items(in: category).count
                    )
                }
            }

            // Tags
            if !vaultManager.items.allTags.isEmpty {
                Section("Tags") {
                    ForEach(Array(vaultManager.items.allTags).sorted(), id: \.self) { tag in
                        SidebarRow(
                            category: .tag(tag),
                            count: vaultManager.items.items(withTag: tag).count
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: Theme.Size.sidebarWidth)
        .background(DodoColors.backgroundSecondary)
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Divider()

            HStack {
                if let metadata = vaultManager.metadata {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metadata.name)
                            .font(DodoTypography.bodySmall)
                            .foregroundColor(DodoColors.textPrimary)

                        Text("\(vaultManager.items.count) items")
                            .font(DodoTypography.caption)
                            .foregroundColor(DodoColors.textSecondary)
                    }
                }

                Spacer()

                StatusPill(status: vaultManager.syncStatus)

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DodoColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .background(DodoColors.backgroundSecondary)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let category: SidebarCategory
    var count: Int = 0

    var body: some View {
        Label {
            HStack {
                Text(category.title)
                    .font(DodoTypography.body)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(DodoTypography.caption)
                        .foregroundColor(DodoColors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, Theme.Spacing.xxxs)
                        .background(DodoColors.backgroundTertiary)
                        .cornerRadius(Theme.Radius.xs)
                }
            }
        } icon: {
            Image(systemName: category.systemImage)
                .foregroundColor(iconColor)
        }
        .tag(category)
    }

    private var iconColor: Color {
        switch category {
        case .all:
            return DodoColors.accent
        case .favorites:
            return DodoColors.warning
        case .category(let cat):
            return DodoColors.color(for: cat)
        case .tag:
            return DodoColors.textSecondary
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SidebarView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var selected: SidebarCategory? = .all

        var body: some View {
            SidebarView(
                selectedCategory: $selected,
                vaultManager: VaultManager.shared
            )
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .frame(width: 250, height: 500)
    }
}
#endif
