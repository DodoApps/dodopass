import SwiftUI

/// A row displaying a vault item in a list.
struct ItemRow: View {
    let item: any VaultItem
    var isSelected: Bool = false
    var showCategory: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            ItemIconView(icon: item.icon, category: item.category)

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(item.title)
                        .font(DodoTypography.body)
                        .foregroundColor(DodoColors.textPrimary)
                        .lineLimit(1)

                    if item.favorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DodoColors.warning)
                    }
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DodoTypography.bodySmall)
                        .foregroundColor(DodoColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if showCategory {
                CategoryBadge(category: item.category)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.md)
        .background(isSelected ? DodoColors.backgroundSelected : Color.clear)
        .contentShape(Rectangle())
    }

    private var subtitle: String? {
        switch item.category {
        case .login:
            if let login = item as? LoginItem {
                return login.username.isEmpty ? login.domain : login.username
            }
        case .secureNote:
            if let note = item as? SecureNote {
                return note.contentPreview
            }
        case .creditCard:
            if let card = item as? CreditCard {
                return card.maskedCardNumber
            }
        case .identity:
            if let identity = item as? Identity {
                return identity.email.isEmpty ? identity.fullName : identity.email
            }
        }
        return nil
    }
}

// MARK: - Item Icon View

/// Displays an item's icon with category-based styling.
struct ItemIconView: View {
    let icon: ItemIcon
    var category: ItemCategory? = nil
    var size: IconSize = .medium

    enum IconSize {
        case small
        case medium
        case large

        var containerSize: CGFloat {
            switch self {
            case .small: return 28
            case .medium: return 36
            case .large: return 48
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 24
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .fill(iconColor.opacity(0.15))

            Image(systemName: icon.symbolName)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundColor(iconColor)
        }
        .frame(width: size.containerSize, height: size.containerSize)
    }

    private var iconColor: Color {
        if let category = category {
            return DodoColors.color(for: category)
        }
        return DodoColors.iconColor(for: icon.colorName)
    }
}

// MARK: - Category Badge

/// A small badge showing the item category.
struct CategoryBadge: View {
    let category: ItemCategory

    var body: some View {
        Text(category.displayName)
            .font(DodoTypography.captionBold)
            .foregroundColor(DodoColors.color(for: category))
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xxxs)
            .background(DodoColors.color(for: category).opacity(0.15))
            .cornerRadius(Theme.Radius.xs)
    }
}

// MARK: - Item List Section Header

/// A section header for grouped item lists.
struct ItemListSectionHeader: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(DodoTypography.labelSmall)
                .foregroundColor(DodoColors.textTertiary)
                .textCase(.uppercase)

            if let count = count {
                Text("(\(count))")
                    .font(DodoTypography.labelSmall)
                    .foregroundColor(DodoColors.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Preview

#if DEBUG
struct ItemRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            ItemRow(item: LoginItem.example, isSelected: false)
            ItemRow(item: LoginItem.example, isSelected: true)
            ItemRow(item: SecureNote.example, showCategory: true)
            ItemRow(item: CreditCard.example)
            ItemRow(item: Identity.example)
        }
        .frame(width: 350)
        .background(DodoColors.backgroundSecondary)
    }
}
#endif
