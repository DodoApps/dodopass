import SwiftUI

/// A password generator interface.
struct PasswordGeneratorView: View {
    @Binding var generatedPassword: String
    var onAccept: ((String) -> Void)?

    @State private var length: Double = 16
    @State private var includeUppercase = true
    @State private var includeLowercase = true
    @State private var includeNumbers = true
    @State private var includeSymbols = true
    @State private var excludeAmbiguous = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Generated password display
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Generated password")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                HStack(spacing: Theme.Spacing.sm) {
                    Text(generatedPassword)
                        .font(DodoTypography.monoLarge)
                        .foregroundColor(DodoColors.textPrimary)
                        .textSelection(.enabled)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        generatePassword()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(DodoColors.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Generate new")

                    IconCopyButton(content: generatedPassword)
                }
                .padding(Theme.Spacing.md)
                .background(DodoColors.backgroundTertiary)
                .cornerRadius(Theme.Radius.sm)

                PasswordStrengthIndicator(password: generatedPassword)
            }

            // Length slider
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("Length")
                        .font(DodoTypography.label)
                        .foregroundColor(DodoColors.textSecondary)

                    Spacer()

                    Text("\(Int(length))")
                        .font(DodoTypography.mono)
                        .foregroundColor(DodoColors.textPrimary)
                }

                Slider(value: $length, in: 8...64, step: 1)
                    .accentColor(DodoColors.accent)
                    .onChange(of: length) { _, _ in
                        generatePassword()
                    }
            }

            // Character options
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Character types")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                ToggleRow(title: "Uppercase (A-Z)", isOn: $includeUppercase)
                ToggleRow(title: "Lowercase (a-z)", isOn: $includeLowercase)
                ToggleRow(title: "Numbers (0-9)", isOn: $includeNumbers)
                ToggleRow(title: "Symbols (!@#$%...)", isOn: $includeSymbols)
                ToggleRow(title: "Exclude ambiguous (0, O, l, 1)", isOn: $excludeAmbiguous)
            }

            // Accept button
            if let onAccept = onAccept {
                Button {
                    onAccept(generatedPassword)
                } label: {
                    HStack {
                        Spacer()
                        Text("Use this password")
                        Spacer()
                    }
                }
                .buttonStyle(.dodoPrimary)
            }
        }
        .padding(Theme.Spacing.lg)
        .onAppear {
            generatePassword()
        }
    }

    private func generatePassword() {
        let config = PasswordGenerator.Configuration(
            length: Int(length),
            includeUppercase: includeUppercase,
            includeLowercase: includeLowercase,
            includeNumbers: includeNumbers,
            includeSymbols: includeSymbols,
            excludeAmbiguous: excludeAmbiguous
        )
        generatedPassword = PasswordGenerator.shared.generate(with: config)
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.switch)
            .font(DodoTypography.body)
            .foregroundColor(DodoColors.textPrimary)
            .tint(DodoColors.accent)
    }
}

// MARK: - Password Generator Popover

struct PasswordGeneratorPopover: View {
    @Binding var isPresented: Bool
    var onGenerated: (String) -> Void

    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Password generator")
                    .font(DodoTypography.title)
                    .foregroundColor(DodoColors.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(DodoColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.md)
            .background(DodoColors.backgroundSecondary)

            PasswordGeneratorView(generatedPassword: $password) { generated in
                onGenerated(generated)
                isPresented = false
            }
        }
        .frame(width: 350)
        .background(DodoColors.background)
        .cornerRadius(Theme.Radius.lg)
    }
}

// MARK: - Preview

#if DEBUG
struct PasswordGeneratorView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var password = ""

        var body: some View {
            PasswordGeneratorView(generatedPassword: $password) { generated in
                print("Accepted: \(generated)")
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .frame(width: 400)
            .background(DodoColors.background)
    }
}
#endif
