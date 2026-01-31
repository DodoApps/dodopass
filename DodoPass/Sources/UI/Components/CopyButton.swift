import SwiftUI

/// A button that copies content and shows feedback.
struct CopyButton: View {
    let content: String
    var label: String? = nil
    var showFeedback: Bool = true
    var clearAfter: TimeInterval? = CryptoConstants.clipboardClearTimeout

    @State private var isCopied = false
    @Environment(\.toastManager) private var toastManager

    var body: some View {
        Button {
            copy()
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(isCopied ? DodoColors.success : DodoColors.textSecondary)

                if let label = label {
                    Text(isCopied ? "Copied!" : label)
                        .font(DodoTypography.label)
                        .foregroundColor(isCopied ? DodoColors.success : DodoColors.textSecondary)
                }
            }
            .animation(Theme.Animation.fast, value: isCopied)
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
    }

    private func copy() {
        ClipboardManager.shared.copy(content, clearAfter: clearAfter)

        if showFeedback {
            withAnimation {
                isCopied = true
            }

            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isCopied = false
                }
            }

            // Show toast
            if let clearAfter = clearAfter {
                toastManager?.show(
                    "Copied! Will clear in \(Int(clearAfter))s",
                    icon: "doc.on.doc.fill"
                )
            } else {
                toastManager?.show("Copied to clipboard", icon: "doc.on.doc.fill")
            }
        }
    }
}

// MARK: - Icon Copy Button

/// A compact icon-only copy button.
struct IconCopyButton: View {
    let content: String
    var clearAfter: TimeInterval? = CryptoConstants.clipboardClearTimeout

    @State private var isCopied = false

    var body: some View {
        Button {
            ClipboardManager.shared.copy(content, clearAfter: clearAfter)

            withAnimation(Theme.Animation.fast) {
                isCopied = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(Theme.Animation.fast) {
                    isCopied = false
                }
            }
        } label: {
            Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.system(size: 14))
                .foregroundColor(isCopied ? DodoColors.success : DodoColors.textSecondary)
        }
        .buttonStyle(.plain)
        .help("Copy")
    }
}

// MARK: - Copy Field

/// A field with label, value, and copy button.
struct CopyField: View {
    let label: String
    let value: String
    var isSecret: Bool = false
    var clearAfter: TimeInterval? = nil

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label)
                .font(DodoTypography.label)
                .foregroundColor(DodoColors.textSecondary)

            HStack(spacing: Theme.Spacing.sm) {
                if isSecret && !isRevealed {
                    Text(String(repeating: "•", count: min(value.count, 20)))
                        .font(DodoTypography.mono)
                        .foregroundColor(DodoColors.textPrimary)
                } else {
                    Text(value)
                        .font(isSecret ? DodoTypography.mono : DodoTypography.body)
                        .foregroundColor(DodoColors.textPrimary)
                        .textSelection(.enabled)
                }

                Spacer()

                if isSecret {
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
                }

                IconCopyButton(
                    content: value,
                    clearAfter: isSecret ? (clearAfter ?? CryptoConstants.clipboardClearTimeout) : clearAfter
                )
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Preview

#if DEBUG
struct CopyButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CopyButton(content: "secretpassword123", label: "Copy password")

            IconCopyButton(content: "test@example.com")

            CopyField(label: "Username", value: "user@example.com")

            CopyField(label: "Password", value: "secretpassword123", isSecret: true)
        }
        .padding()
        .frame(width: 400)
        .background(DodoColors.background)
    }
}
#endif
