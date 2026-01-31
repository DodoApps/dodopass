import SwiftUI

/// Color palette for DodoPass, inspired by 1Password's dark theme.
enum DodoColors {
    // MARK: - Background Colors

    /// Primary background (darkest)
    static let background = Color(hex: "1A1A1A")

    /// Secondary background (sidebar, cards)
    static let backgroundSecondary = Color(hex: "242424")

    /// Tertiary background (elevated elements)
    static let backgroundTertiary = Color(hex: "2E2E2E")

    /// Hover state background
    static let backgroundHover = Color(hex: "383838")

    /// Selected state background
    static let backgroundSelected = Color(hex: "3D3D3D")

    // MARK: - Text Colors

    /// Primary text color
    static let textPrimary = Color(hex: "FFFFFF")

    /// Secondary text color
    static let textSecondary = Color(hex: "A0A0A0")

    /// Tertiary/muted text color
    static let textTertiary = Color(hex: "707070")

    /// Placeholder text color
    static let textPlaceholder = Color(hex: "606060")

    // MARK: - Accent Colors

    /// Primary accent (DodoPass blue)
    static let accent = Color(hex: "4A9FFF")

    /// Accent hover state
    static let accentHover = Color(hex: "6BB3FF")

    /// Accent pressed state
    static let accentPressed = Color(hex: "3388E8")

    /// Accent subtle (for backgrounds)
    static let accentSubtle = Color(hex: "4A9FFF").opacity(0.15)

    // MARK: - Semantic Colors

    /// Success/green color
    static let success = Color(hex: "34C759")

    /// Success subtle background
    static let successSubtle = Color(hex: "34C759").opacity(0.15)

    /// Warning/yellow color
    static let warning = Color(hex: "FFD60A")

    /// Warning subtle background
    static let warningSubtle = Color(hex: "FFD60A").opacity(0.15)

    /// Error/red color
    static let error = Color(hex: "FF453A")

    /// Error subtle background
    static let errorSubtle = Color(hex: "FF453A").opacity(0.15)

    /// Info/blue color
    static let info = Color(hex: "64D2FF")

    // MARK: - Border Colors

    /// Default border color
    static let border = Color(hex: "3A3A3A")

    /// Subtle border color
    static let borderSubtle = Color(hex: "2E2E2E")

    /// Focused border color
    static let borderFocused = accent

    // MARK: - Category Colors

    /// Login item color
    static let categoryLogin = Color(hex: "4A9FFF")

    /// Secure note color
    static let categorySecureNote = Color(hex: "AF52DE")

    /// Credit card color
    static let categoryCreditCard = Color(hex: "FF9F0A")

    /// Identity color
    static let categoryIdentity = Color(hex: "30D158")

    // MARK: - Icon Colors

    static func iconColor(for colorName: String) -> Color {
        switch colorName.lowercased() {
        case "blue":
            return Color(hex: "4A9FFF")
        case "purple":
            return Color(hex: "AF52DE")
        case "pink":
            return Color(hex: "FF2D55")
        case "red":
            return Color(hex: "FF453A")
        case "orange":
            return Color(hex: "FF9F0A")
        case "yellow":
            return Color(hex: "FFD60A")
        case "green":
            return Color(hex: "30D158")
        case "teal":
            return Color(hex: "64D2FF")
        case "cyan":
            return Color(hex: "5AC8FA")
        case "indigo":
            return Color(hex: "5856D6")
        case "gray", "grey":
            return Color(hex: "8E8E93")
        default:
            return Color(hex: "4A9FFF")
        }
    }

    // MARK: - Gradients

    /// Accent gradient for buttons
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "5AAFFF"), Color(hex: "4A9FFF")],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Sidebar background gradient
    static let sidebarGradient = LinearGradient(
        colors: [Color(hex: "242424"), Color(hex: "1A1A1A")],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Color Extension

extension Color {
    /// Creates a color from a hex string.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - ShapeStyle Conformance

extension DodoColors {
    /// Creates a color for the given category.
    static func color(for category: ItemCategory) -> Color {
        switch category {
        case .login:
            return categoryLogin
        case .secureNote:
            return categorySecureNote
        case .creditCard:
            return categoryCreditCard
        case .identity:
            return categoryIdentity
        }
    }
}
