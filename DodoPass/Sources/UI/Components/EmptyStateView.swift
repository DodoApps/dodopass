import SwiftUI

/// An empty state placeholder view.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(DodoColors.textTertiary)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(DodoTypography.title)
                    .foregroundColor(DodoColors.textPrimary)

                if let message = message {
                    Text(message)
                        .font(DodoTypography.body)
                        .foregroundColor(DodoColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.dodoPrimary)
            }
        }
        .padding(Theme.Spacing.xxl)
    }
}

// MARK: - Specific Empty States

extension EmptyStateView {
    static var noItems: EmptyStateView {
        EmptyStateView(
            icon: "lock.shield",
            title: "No items yet",
            message: "Add your first login, note, or card to get started.",
            actionTitle: "Add item"
        )
    }

    static var noSearchResults: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No results found",
            message: "Try a different search term."
        )
    }

    static var noFavorites: EmptyStateView {
        EmptyStateView(
            icon: "star",
            title: "No favorites",
            message: "Star items to add them to favorites."
        )
    }

    static func noItemsInCategory(_ category: ItemCategory) -> EmptyStateView {
        EmptyStateView(
            icon: category.systemImage,
            title: "No \(category.displayName.lowercased())s",
            message: "Add your first \(category.displayName.lowercased()) to get started."
        )
    }
}

// MARK: - Loading State

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)

            Text(message)
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textSecondary)
        }
    }
}

// MARK: - Error State

struct ErrorStateView: View {
    let error: Error
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(DodoColors.error)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Something went wrong")
                    .font(DodoTypography.title)
                    .foregroundColor(DodoColors.textPrimary)

                Text(error.localizedDescription)
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let retryAction = retryAction {
                Button("Try again", action: retryAction)
                    .buttonStyle(.dodoSecondary)
            }
        }
        .padding(Theme.Spacing.xxl)
    }
}

// MARK: - Preview

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            EmptyStateView.noItems

            EmptyStateView.noSearchResults

            LoadingView()

            ErrorStateView(error: VaultError.vaultLocked)
        }
        .frame(width: 400)
        .background(DodoColors.background)
    }
}
#endif
