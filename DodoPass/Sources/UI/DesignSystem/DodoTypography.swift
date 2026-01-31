import SwiftUI

/// Typography styles for DodoPass.
enum DodoTypography {
    // MARK: - Display

    /// Large title for onboarding screens
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)

    /// Display title
    static let display = Font.system(size: 28, weight: .bold, design: .rounded)

    // MARK: - Titles

    /// Large title
    static let titleLarge = Font.system(size: 22, weight: .bold, design: .default)

    /// Regular title
    static let title = Font.system(size: 17, weight: .semibold, design: .default)

    /// Small title
    static let titleSmall = Font.system(size: 15, weight: .semibold, design: .default)

    // MARK: - Body

    /// Large body text
    static let bodyLarge = Font.system(size: 15, weight: .regular, design: .default)

    /// Regular body text
    static let body = Font.system(size: 13, weight: .regular, design: .default)

    /// Small body text
    static let bodySmall = Font.system(size: 11, weight: .regular, design: .default)

    // MARK: - Labels

    /// Large label
    static let labelLarge = Font.system(size: 13, weight: .medium, design: .default)

    /// Regular label
    static let label = Font.system(size: 11, weight: .medium, design: .default)

    /// Small label
    static let labelSmall = Font.system(size: 10, weight: .medium, design: .default)

    // MARK: - Monospace

    /// Monospace for passwords and codes
    static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)

    /// Large monospace
    static let monoLarge = Font.system(size: 15, weight: .medium, design: .monospaced)

    /// Small monospace
    static let monoSmall = Font.system(size: 11, weight: .regular, design: .monospaced)

    // MARK: - Caption

    /// Regular caption
    static let caption = Font.system(size: 10, weight: .regular, design: .default)

    /// Bold caption
    static let captionBold = Font.system(size: 10, weight: .semibold, design: .default)
}

// MARK: - Text Modifiers

extension View {
    /// Applies the display large typography style.
    func displayLargeStyle() -> some View {
        self
            .font(DodoTypography.displayLarge)
            .foregroundColor(DodoColors.textPrimary)
    }

    /// Applies the display typography style.
    func displayStyle() -> some View {
        self
            .font(DodoTypography.display)
            .foregroundColor(DodoColors.textPrimary)
    }

    /// Applies the title large typography style.
    func titleLargeStyle() -> some View {
        self
            .font(DodoTypography.titleLarge)
            .foregroundColor(DodoColors.textPrimary)
    }

    /// Applies the title typography style.
    func titleStyle() -> some View {
        self
            .font(DodoTypography.title)
            .foregroundColor(DodoColors.textPrimary)
    }

    /// Applies the title small typography style.
    func titleSmallStyle() -> some View {
        self
            .font(DodoTypography.titleSmall)
            .foregroundColor(DodoColors.textPrimary)
    }

    /// Applies the body large typography style.
    func bodyLargeStyle() -> some View {
        self
            .font(DodoTypography.bodyLarge)
            .foregroundColor(DodoColors.textPrimary)
    }

    /// Applies the body typography style.
    func bodyStyle() -> some View {
        self
            .font(DodoTypography.body)
            .foregroundColor(DodoColors.textPrimary)
    }

    /// Applies the secondary body typography style.
    func bodySecondaryStyle() -> some View {
        self
            .font(DodoTypography.body)
            .foregroundColor(DodoColors.textSecondary)
    }

    /// Applies the label typography style.
    func labelStyle() -> some View {
        self
            .font(DodoTypography.label)
            .foregroundColor(DodoColors.textSecondary)
    }

    /// Applies the mono typography style.
    func monoStyle() -> some View {
        self
            .font(DodoTypography.mono)
            .foregroundColor(DodoColors.textPrimary)
    }

    /// Applies the caption typography style.
    func captionStyle() -> some View {
        self
            .font(DodoTypography.caption)
            .foregroundColor(DodoColors.textTertiary)
    }
}
