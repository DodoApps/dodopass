import SwiftUI

/// A pill-shaped status indicator.
struct StatusPill: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: status.systemImage)
                .font(.system(size: 12))

            Text(status.displayText)
                .font(DodoTypography.label)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(backgroundColor)
        .cornerRadius(Theme.Radius.full)
    }

    private var foregroundColor: Color {
        switch status {
        case .disabled:
            return DodoColors.textSecondary
        case .idle:
            return DodoColors.success
        case .syncing:
            return DodoColors.accent
        case .error:
            return DodoColors.error
        case .conflict:
            return DodoColors.warning
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .disabled:
            return DodoColors.backgroundTertiary
        case .idle:
            return DodoColors.successSubtle
        case .syncing:
            return DodoColors.accentSubtle
        case .error:
            return DodoColors.errorSubtle
        case .conflict:
            return DodoColors.warningSubtle
        }
    }
}

// MARK: - Connection Status

struct ConnectionStatusView: View {
    @ObservedObject var vaultManager: VaultManager

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            StatusPill(status: vaultManager.syncStatus)

            if vaultManager.syncStatus == .syncing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct StatusPill_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            StatusPill(status: .disabled)
            StatusPill(status: .idle)
            StatusPill(status: .syncing)
            StatusPill(status: .error(message: "Network error"))
            StatusPill(status: .conflict(localDate: Date(), remoteDate: Date()))
        }
        .padding()
        .background(DodoColors.background)
    }
}
#endif
