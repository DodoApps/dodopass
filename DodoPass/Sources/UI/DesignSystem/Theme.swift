import SwiftUI

/// Theme configuration for DodoPass.
struct Theme {
    // MARK: - Spacing

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let full: CGFloat = 9999
    }

    // MARK: - Sizes

    enum Size {
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 24
        static let iconXLarge: CGFloat = 32

        static let buttonHeight: CGFloat = 34
        static let buttonHeightLarge: CGFloat = 44

        static let rowHeight: CGFloat = 44
        static let rowHeightCompact: CGFloat = 36

        static let sidebarWidth: CGFloat = 265
        static let listWidth: CGFloat = 300
        static let detailMinWidth: CGFloat = 400

        static let windowMinWidth: CGFloat = 900
        static let windowMinHeight: CGFloat = 600
    }

    // MARK: - Animation

    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Shadows

    enum Shadow {
        static func small(color: Color = .black.opacity(0.2)) -> some View {
            EmptyView()
                .shadow(color: color, radius: 2, x: 0, y: 1)
        }

        static func medium(color: Color = .black.opacity(0.2)) -> some View {
            EmptyView()
                .shadow(color: color, radius: 4, x: 0, y: 2)
        }

        static func large(color: Color = .black.opacity(0.2)) -> some View {
            EmptyView()
                .shadow(color: color, radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies a card-style background.
    func cardStyle() -> some View {
        self
            .background(DodoColors.backgroundSecondary)
            .cornerRadius(Theme.Radius.md)
    }

    /// Applies a rounded background with border.
    func roundedBorder(_ color: Color = DodoColors.border) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(color, lineWidth: 1)
            )
    }

    /// Applies hover effect.
    func hoverEffect() -> some View {
        self.modifier(HoverEffectModifier())
    }

    /// Applies a subtle shadow.
    func subtleShadow() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Hover Effect Modifier

struct HoverEffectModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(isHovering ? DodoColors.backgroundHover : Color.clear)
            .onHover { hovering in
                withAnimation(Theme.Animation.fast) {
                    isHovering = hovering
                }
            }
    }
}

// MARK: - Button Styles

struct DodoButtonStyle: ButtonStyle {
    let variant: Variant

    enum Variant {
        case primary
        case secondary
        case ghost
        case destructive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DodoTypography.label)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: Theme.Size.buttonHeight)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .cornerRadius(Theme.Radius.sm)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? DodoColors.accentPressed : DodoColors.accent
        case .secondary:
            return isPressed ? DodoColors.backgroundHover : DodoColors.backgroundTertiary
        case .ghost:
            return isPressed ? DodoColors.backgroundHover : Color.clear
        case .destructive:
            return isPressed ? DodoColors.error.opacity(0.8) : DodoColors.error
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary, .ghost:
            return DodoColors.textPrimary
        case .destructive:
            return .white
        }
    }
}

extension ButtonStyle where Self == DodoButtonStyle {
    static var dodoPrimary: DodoButtonStyle { DodoButtonStyle(variant: .primary) }
    static var dodoSecondary: DodoButtonStyle { DodoButtonStyle(variant: .secondary) }
    static var dodoGhost: DodoButtonStyle { DodoButtonStyle(variant: .ghost) }
    static var dodoDestructive: DodoButtonStyle { DodoButtonStyle(variant: .destructive) }
}

// MARK: - TextField Styles

struct DodoTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(DodoTypography.body)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: Theme.Size.buttonHeight)
            .background(DodoColors.backgroundTertiary)
            .foregroundColor(DodoColors.textPrimary)
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isFocused ? DodoColors.accent : DodoColors.border, lineWidth: 1)
            )
            .focused($isFocused)
    }
}

extension TextFieldStyle where Self == DodoTextFieldStyle {
    static var dodo: DodoTextFieldStyle { DodoTextFieldStyle() }
}
