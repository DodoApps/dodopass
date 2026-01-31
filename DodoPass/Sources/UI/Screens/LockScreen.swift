import SwiftUI

/// The lock screen for unlocking the vault.
struct LockScreen: View {
    @ObservedObject var vaultManager: VaultManager
    var onUnlock: (() -> Void)?

    @State private var password = ""
    @State private var error: String?
    @State private var isLoading = false
    @State private var showBiometricPrompt = true

    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        ZStack {
            // Background
            DodoColors.background
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xxl) {
                Spacer()

                // Logo/Icon
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64))
                        .foregroundColor(DodoColors.accent)

                    Text("DodoPass")
                        .font(DodoTypography.displayLarge)
                        .foregroundColor(DodoColors.textPrimary)

                    Text(vaultManager.vaultExists ? "Enter your master password" : "Create your vault")
                        .font(DodoTypography.body)
                        .foregroundColor(DodoColors.textSecondary)
                }

                // Password field
                VStack(spacing: Theme.Spacing.md) {
                    DodoSecureField(
                        label: "Master password",
                        text: $password,
                        placeholder: "Enter your password",
                        externalFocus: $isPasswordFocused
                    )
                    .onSubmit {
                        unlock()
                    }

                    if !vaultManager.vaultExists {
                        PasswordStrengthIndicator(password: password)
                    }

                    if let error = error {
                        Text(error)
                            .font(DodoTypography.bodySmall)
                            .foregroundColor(DodoColors.error)
                    }
                }
                .frame(width: 300)

                // Buttons
                VStack(spacing: Theme.Spacing.md) {
                    Button {
                        unlock()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(vaultManager.vaultExists ? "Unlock" : "Create vault")
                        }
                        .frame(width: 200)
                    }
                    .buttonStyle(.dodoPrimary)
                    .disabled(password.isEmpty || isLoading)
                    .keyboardShortcut(.return, modifiers: [])

                    if vaultManager.vaultExists && BiometricAuth().isAvailable {
                        Button {
                            unlockWithBiometrics()
                        } label: {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "touchid")
                                Text("Use Touch ID")
                            }
                            .frame(width: 200)
                        }
                        .buttonStyle(.dodoSecondary)
                        .disabled(isLoading)
                    }
                }

                Spacer()

                // Footer
                Text("Your data is encrypted locally")
                    .font(DodoTypography.caption)
                    .foregroundColor(DodoColors.textTertiary)
                    .padding(.bottom, Theme.Spacing.lg)
            }
            .padding(Theme.Spacing.xxl)
        }
        .onAppear {
            isPasswordFocused = true

            // Auto-trigger biometric if available
            if vaultManager.vaultExists && showBiometricPrompt && BiometricAuth().isAvailable {
                showBiometricPrompt = false
                unlockWithBiometrics()
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }

        isLoading = true
        error = nil

        Task {
            do {
                if vaultManager.vaultExists {
                    try await vaultManager.unlock(password: password)
                } else {
                    try await vaultManager.createVault(password: password)
                }
                password = ""
                onUnlock?()
            } catch let vaultError as VaultError {
                error = vaultError.localizedDescription
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func unlockWithBiometrics() {
        isLoading = true
        error = nil

        Task {
            do {
                try await vaultManager.unlockWithBiometrics()
                onUnlock?()
            } catch let vaultError as VaultError {
                switch vaultError {
                case .biometricsFailed(let underlying):
                    // Check if user cancelled - LAError.userCancel or LAError.appCancel
                    if let laError = underlying as? NSError,
                       laError.domain == "com.apple.LocalAuthentication",
                       (laError.code == -2 || laError.code == -4) {
                        // User cancelled - don't show error
                    } else {
                        error = vaultError.localizedDescription
                    }
                case .biometricsNotAvailable:
                    error = "Touch ID is not available"
                default:
                    error = vaultError.localizedDescription
                }
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LockScreen_Previews: PreviewProvider {
    static var previews: some View {
        LockScreen(vaultManager: VaultManager.shared)
            .frame(width: 600, height: 500)
    }
}
#endif
