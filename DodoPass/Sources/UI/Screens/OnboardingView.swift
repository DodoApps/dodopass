import SwiftUI

/// First-run wizard for creating a new vault.
struct OnboardingView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var currentStep = 0
    @State private var vaultName = "My Vault"
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var enableTouchID = true
    @State private var enableICloud = false
    @State private var isCreating = false
    @State private var error: String?

    private let totalSteps = 3

    var body: some View {
        ZStack {
            DodoColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                    .padding(.top, Theme.Spacing.xl)

                Spacer()

                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        welcomeStep
                    case 1:
                        passwordStep
                    case 2:
                        optionsStep
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Navigation buttons
                navigationButtons
                    .padding(.bottom, Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .frame(maxWidth: 500)
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? DodoColors.accent : DodoColors.backgroundTertiary)
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundColor(DodoColors.accent)

            Text("Welcome to DodoPass")
                .font(DodoTypography.displayLarge)
                .foregroundColor(DodoColors.textPrimary)

            Text("Your secure password manager for macOS. Let's set up your encrypted vault.")
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                FeatureRow(icon: "lock.shield.fill", text: "AES-256 encryption")
                FeatureRow(icon: "touchid", text: "Touch ID unlock")
                FeatureRow(icon: "icloud.fill", text: "Optional iCloud sync")
                FeatureRow(icon: "eye.slash.fill", text: "Zero-knowledge architecture")
            }
            .padding(.top, Theme.Spacing.md)
        }
    }

    // MARK: - Password Step

    private var passwordStep: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(DodoColors.accent)

            Text("Create your master password")
                .font(DodoTypography.title)
                .foregroundColor(DodoColors.textPrimary)

            Text("This password protects all your data. Choose something strong and memorable—we can't recover it if you forget.")
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Vault name")
                        .font(DodoTypography.label)
                        .foregroundColor(DodoColors.textSecondary)

                    TextField("My Vault", text: $vaultName)
                        .textFieldStyle(.dodo)
                }

                DodoSecureField(
                    label: "Master password",
                    text: $password,
                    placeholder: "Enter a strong password"
                )

                PasswordStrengthIndicator(password: password)

                DodoSecureField(
                    label: "Confirm password",
                    text: $confirmPassword,
                    placeholder: "Confirm your password"
                )

                if !confirmPassword.isEmpty && password != confirmPassword {
                    Text("Passwords do not match")
                        .font(DodoTypography.caption)
                        .foregroundColor(DodoColors.error)
                }

                if let error = error {
                    Text(error)
                        .font(DodoTypography.caption)
                        .foregroundColor(DodoColors.error)
                }
            }
            .frame(maxWidth: 350)
        }
    }

    // MARK: - Options Step

    private var optionsStep: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundColor(DodoColors.accent)

            Text("Configure your vault")
                .font(DodoTypography.title)
                .foregroundColor(DodoColors.textPrimary)

            Text("Choose how you want to access and sync your vault.")
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: Theme.Spacing.md) {
                OptionToggle(
                    icon: "touchid",
                    title: "Enable Touch ID",
                    description: "Unlock your vault with Touch ID",
                    isOn: $enableTouchID
                )

                OptionToggle(
                    icon: "icloud.fill",
                    title: "Enable iCloud sync",
                    description: "Sync your vault across devices",
                    isOn: $enableICloud
                )
            }
            .frame(maxWidth: 350)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.dodoSecondary)
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button("Continue") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.dodoPrimary)
                .disabled(currentStep == 1 && !isPasswordValid)
            } else {
                Button {
                    createVault()
                } label: {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Create vault")
                    }
                }
                .buttonStyle(.dodoPrimary)
                .disabled(isCreating || !isPasswordValid)
            }
        }
    }

    // MARK: - Validation

    private var isPasswordValid: Bool {
        password.count >= 8 && password == confirmPassword
    }

    // MARK: - Actions

    private func createVault() {
        guard isPasswordValid else { return }

        isCreating = true
        error = nil

        Task {
            do {
                try await vaultManager.createVault(
                    password: password,
                    name: vaultName
                )

                // Enable optional features, but don't fail vault creation if they fail
                if enableTouchID {
                    do {
                        try await vaultManager.enableBiometrics()
                    } catch {
                        // Log but don't fail - Touch ID can be enabled later
                        AuditLogger.shared.log("Touch ID enrollment failed: \(error.localizedDescription)", category: .auth, level: .warning)
                    }
                }

                if enableICloud {
                    do {
                        try await ICloudCoordinator.shared.enable()
                    } catch {
                        // Log but don't fail - iCloud can be enabled later
                        AuditLogger.shared.log("iCloud sync failed to enable: \(error.localizedDescription)", category: .sync, level: .warning)
                    }
                }

                AuditLogger.shared.vaultCreated()

            } catch {
                self.error = error.localizedDescription
            }

            isCreating = false
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(DodoColors.accent)
                .frame(width: 24)

            Text(text)
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textPrimary)
        }
    }
}

// MARK: - Option Toggle

private struct OptionToggle: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(DodoColors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DodoTypography.title)
                    .foregroundColor(DodoColors.textPrimary)

                Text(description)
                    .font(DodoTypography.caption)
                    .foregroundColor(DodoColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(Theme.Spacing.md)
        .background(DodoColors.backgroundSecondary)
        .cornerRadius(Theme.Radius.md)
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
#endif
