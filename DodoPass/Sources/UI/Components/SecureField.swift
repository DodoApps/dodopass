import SwiftUI

/// A secure text field with visibility toggle.
struct DodoSecureField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var showGenerateButton: Bool = false
    var onGenerate: (() -> Void)?
    var externalFocus: FocusState<Bool>.Binding?

    @State private var isRevealed = false
    @FocusState private var internalFocus: Bool

    private var isFocused: Bool {
        externalFocus?.wrappedValue ?? internalFocus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            if !label.isEmpty {
                Text(label)
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                            .font(DodoTypography.mono)
                    } else {
                        SecureField(placeholder, text: $text)
                            .font(DodoTypography.mono)
                    }
                }
                .textFieldStyle(.plain)
                .focused(externalFocus ?? $internalFocus)

                Button {
                    withAnimation(Theme.Animation.fast) {
                        isRevealed.toggle()
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundColor(DodoColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide password" : "Show password")

                if showGenerateButton {
                    Button {
                        onGenerate?()
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14))
                            .foregroundColor(DodoColors.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Generate password")
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: Theme.Size.buttonHeight)
            .background(DodoColors.backgroundTertiary)
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isFocused ? DodoColors.accent : DodoColors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Password Display

/// Displays a password with reveal toggle and copy button.
struct PasswordDisplay: View {
    let password: String
    var onCopy: (() -> Void)?

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(isRevealed ? password : maskedPassword)
                .font(DodoTypography.mono)
                .foregroundColor(DodoColors.textPrimary)
                .lineLimit(1)
                .textSelection(.enabled)

            Spacer()

            Button {
                withAnimation(Theme.Animation.fast) {
                    isRevealed.toggle()
                }
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.system(size: 14))
                    .foregroundColor(DodoColors.textSecondary)
            }
            .buttonStyle(.plain)
            .help(isRevealed ? "Hide" : "Reveal")

            if let onCopy = onCopy {
                Button {
                    onCopy()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(DodoColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Copy")
            }
        }
    }

    private var maskedPassword: String {
        String(repeating: "•", count: min(password.count, 20))
    }
}

// MARK: - Password Strength Indicator

/// Displays password strength as a colored bar.
struct PasswordStrengthIndicator: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DodoColors.backgroundTertiary)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(strengthColor)
                        .frame(width: geometry.size.width * strengthPercentage, height: 4)
                        .animation(.easeOut(duration: 0.2), value: strengthPercentage)
                }
            }
            .frame(height: 4)

            Text(strengthLabel)
                .font(DodoTypography.caption)
                .foregroundColor(strengthColor)
        }
    }

    private var strength: PasswordStrength {
        PasswordStrength.evaluate(password)
    }

    private var strengthPercentage: CGFloat {
        switch strength {
        case .veryWeak: return 0.2
        case .weak: return 0.4
        case .fair: return 0.6
        case .strong: return 0.8
        case .veryStrong: return 1.0
        }
    }

    private var strengthColor: Color {
        switch strength {
        case .veryWeak: return DodoColors.error
        case .weak: return DodoColors.warning
        case .fair: return DodoColors.warning
        case .strong: return DodoColors.success
        case .veryStrong: return DodoColors.success
        }
    }

    private var strengthLabel: String {
        switch strength {
        case .veryWeak: return "Very weak"
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .strong: return "Strong"
        case .veryStrong: return "Very strong"
        }
    }
}

// MARK: - Password Strength Evaluation

enum PasswordStrength {
    case veryWeak
    case weak
    case fair
    case strong
    case veryStrong

    static func evaluate(_ password: String) -> PasswordStrength {
        guard !password.isEmpty else { return .veryWeak }

        var score = 0

        // Length
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }

        // Character variety
        if password.contains(where: { $0.isLowercase }) { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;:',.<>?/`~".contains($0) }) { score += 1 }

        switch score {
        case 0...2: return .veryWeak
        case 3: return .weak
        case 4: return .fair
        case 5...6: return .strong
        default: return .veryStrong
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DodoSecureField_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var password = "secretpassword123"

        var body: some View {
            VStack(spacing: 20) {
                DodoSecureField(
                    label: "Password",
                    text: $password,
                    placeholder: "Enter password",
                    showGenerateButton: true
                ) {
                    password = "generated123!"
                }

                PasswordDisplay(password: password) {
                    print("Copied!")
                }

                PasswordStrengthIndicator(password: password)
            }
            .padding()
            .frame(width: 400)
            .background(DodoColors.background)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
