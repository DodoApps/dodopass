import SwiftUI
import AuthenticationServices

// MARK: - AutoFill Unlock View

/// View for unlocking the vault in the AutoFill extension.
struct AutoFillUnlockView: View {
    let onComplete: (Bool) -> Void

    @State private var password = ""
    @State private var isUnlocking = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Unlock DodoPass")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter your master password to autofill credentials.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Password field
            SecureField("Master password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onComplete(false)
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    unlock()
                } label: {
                    if isUnlocking {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Unlock")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty || isUnlocking)
            }

            // Touch ID button
            if BiometricAuth.shared.isAvailable {
                Button {
                    unlockWithTouchID()
                } label: {
                    HStack {
                        Image(systemName: "touchid")
                        Text("Use Touch ID")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }

    private func unlock() {
        isUnlocking = true
        error = nil

        Task {
            do {
                try await VaultManager.shared.unlock(password: password)
                onComplete(true)
            } catch {
                self.error = "Incorrect password"
                isUnlocking = false
            }
        }
    }

    private func unlockWithTouchID() {
        Task {
            do {
                try await VaultManager.shared.unlockWithBiometrics()
                onComplete(true)
            } catch {
                self.error = "Touch ID failed"
            }
        }
    }
}

// MARK: - Credential Picker View

/// View for selecting a credential in the AutoFill extension.
struct AutoFillCredentialPickerView: View {
    let serviceIdentifiers: [ASCredentialServiceIdentifier]
    let onSelect: (ASPasswordCredential) -> Void
    let onCancel: () -> Void

    @State private var searchQuery = ""
    @State private var credentials: [LoginItem] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }

                Spacer()

                Text("Choose a login")
                    .font(.headline)

                Spacer()

                // Placeholder for symmetry
                Button("Cancel") {
                    onCancel()
                }
                .opacity(0)
            }
            .padding()

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding()

            // Credential list
            List(filteredCredentials, id: \.id) { credential in
                CredentialRow(credential: credential) {
                    let passwordCredential = ASPasswordCredential(
                        user: credential.username,
                        password: credential.password
                    )
                    onSelect(passwordCredential)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .onAppear {
            loadCredentials()
        }
    }

    private var filteredCredentials: [LoginItem] {
        if searchQuery.isEmpty {
            return credentials
        }
        return credentials.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.username.localizedCaseInsensitiveContains(searchQuery) ||
            $0.urls.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    private func loadCredentials() {
        // Filter credentials matching the service identifiers
        let allLogins = VaultManager.shared.items.logins

        let domains = serviceIdentifiers.compactMap { identifier -> String? in
            switch identifier.type {
            case .domain:
                return identifier.identifier
            case .URL:
                return URL(string: identifier.identifier)?.host
            @unknown default:
                return nil
            }
        }

        credentials = allLogins.filter { login in
            login.urls.contains { url in
                guard let host = URL(string: url)?.host else { return false }
                return domains.contains { domain in
                    host.hasSuffix(domain) || domain.hasSuffix(host)
                }
            }
        }
    }
}

// MARK: - Credential Row

private struct CredentialRow: View {
    let credential: LoginItem
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(credential.title)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(credential.username)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Configuration View

/// View for configuring the AutoFill extension.
struct AutoFillConfigurationView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("AutoFill is ready")
                .font(.title2)
                .fontWeight(.semibold)

            Text("DodoPass can now autofill your passwords in apps and websites.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Done") {
                onComplete()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }
}
