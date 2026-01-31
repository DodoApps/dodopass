import SwiftUI
import UniformTypeIdentifiers

/// The settings/preferences view.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(DodoTypography.title)
                    .foregroundColor(DodoColors.textPrimary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.dodoPrimary)
            }
            .padding(Theme.Spacing.lg)
            .background(DodoColors.backgroundSecondary)

            Divider()

            // Settings content
            Form {
                // Security section
                Section("Security") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Toggle("Use Touch ID", isOn: $viewModel.useTouchID)
                            .toggleStyle(.switch)
                            .disabled(!VaultManager.shared.isBiometricsAvailable)

                        if let error = viewModel.touchIDError {
                            Text(error)
                                .font(DodoTypography.caption)
                                .foregroundColor(DodoColors.error)
                        } else if !VaultManager.shared.isBiometricsAvailable {
                            Text("Touch ID is not available on this device")
                                .font(DodoTypography.caption)
                                .foregroundColor(DodoColors.textSecondary)
                        }
                    }

                    Picker("Auto-lock", selection: $viewModel.autoLockTimeout) {
                        Text("1 minute").tag(60.0)
                        Text("5 minutes").tag(300.0)
                        Text("15 minutes").tag(900.0)
                        Text("1 hour").tag(3600.0)
                        Text("Never").tag(0.0)
                    }

                    Picker("Clear clipboard", selection: $viewModel.clipboardClearTimeout) {
                        Text("10 seconds").tag(10.0)
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("Never").tag(0.0)
                    }
                }

                // Sync section
                Section("Sync") {
                    Toggle("iCloud sync", isOn: $viewModel.iCloudSyncEnabled)
                        .toggleStyle(.switch)

                    if viewModel.iCloudSyncEnabled {
                        HStack {
                            Text("Last synced")
                            Spacer()
                            if let date = viewModel.lastSyncDate {
                                Text(date.formatted())
                                    .foregroundColor(DodoColors.textSecondary)
                            } else {
                                Text("Never")
                                    .foregroundColor(DodoColors.textSecondary)
                            }
                        }

                        Button("Sync now") {
                            viewModel.syncNow()
                        }
                        .disabled(viewModel.isSyncing)
                    }
                }

                // Backup section
                Section("Backup") {
                    Toggle("Automatic backups", isOn: $viewModel.autoBackupEnabled)
                        .toggleStyle(.switch)

                    Button("Create backup now") {
                        viewModel.createBackup()
                    }

                    Button("Export vault...") {
                        viewModel.exportVault()
                    }

                    Button("Import vault...") {
                        viewModel.importVault()
                    }
                }

                // Appearance section
                Section("Appearance") {
                    Toggle("Show in menu bar", isOn: $viewModel.showInMenuBar)
                        .toggleStyle(.switch)

                    Toggle("Start at login", isOn: $viewModel.startAtLogin)
                        .toggleStyle(.switch)
                }

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(DodoColors.textSecondary)
                    }

                    Link("Privacy policy", destination: URL(string: "https://dodopass.com/privacy")!)

                    Link("Help & support", destination: URL(string: "https://dodopass.com/support")!)
                }

                // Danger zone
                Section {
                    Button("Change master password...") {
                        viewModel.showChangePassword = true
                    }

                    Button("Delete vault", role: .destructive) {
                        viewModel.showDeleteConfirmation = true
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DodoColors.background)
        }
        .frame(width: 500, height: 600)
        .background(DodoColors.background)
        .sheet(isPresented: $viewModel.showChangePassword) {
            ChangePasswordSheet()
        }
        .confirmationDialog("Delete vault?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteVault()
            }
        } message: {
            Text("This will permanently delete all your data. This action cannot be undone.")
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            ExportSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showImportSheet) {
            ImportSheet(viewModel: viewModel)
        }
        .alert("Success", isPresented: .init(
            get: { viewModel.importExportSuccess != nil },
            set: { if !$0 { viewModel.importExportSuccess = nil } }
        )) {
            Button("OK") { viewModel.importExportSuccess = nil }
        } message: {
            Text(viewModel.importExportSuccess ?? "")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.importExportError != nil },
            set: { if !$0 { viewModel.importExportError = nil } }
        )) {
            Button("OK") { viewModel.importExportError = nil }
        } message: {
            Text(viewModel.importExportError ?? "")
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ImportExportService.ExportFormat = .dodopassEncrypted
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Export vault")
                .font(DodoTypography.title)
                .foregroundColor(DodoColors.textPrimary)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Export format")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                Picker("Format", selection: $selectedFormat) {
                    ForEach(ImportExportService.ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            if selectedFormat == .dodopassEncrypted {
                VStack(spacing: Theme.Spacing.md) {
                    DodoSecureField(
                        label: "Encryption password",
                        text: $password,
                        placeholder: "Enter password to encrypt export"
                    )

                    DodoSecureField(
                        label: "Confirm password",
                        text: $confirmPassword,
                        placeholder: "Confirm password"
                    )

                    if !password.isEmpty {
                        PasswordStrengthIndicator(password: password)
                    }
                }
            }

            if selectedFormat == .csv {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DodoColors.warning)
                    Text("CSV export is unencrypted and contains sensitive data.")
                        .font(DodoTypography.caption)
                        .foregroundColor(DodoColors.warning)
                }
                .padding(Theme.Spacing.sm)
                .background(DodoColors.warning.opacity(0.1))
                .cornerRadius(Theme.Radius.sm)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.dodoSecondary)

                Spacer()

                Button("Export") {
                    viewModel.performExport(format: selectedFormat, password: password.isEmpty ? nil : password)
                    dismiss()
                }
                .buttonStyle(.dodoPrimary)
                .disabled(!isValid)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 400)
        .background(DodoColors.background)
    }

    private var isValid: Bool {
        switch selectedFormat {
        case .dodopassEncrypted:
            return password.count >= 8 && password == confirmPassword
        case .dodopassJSON, .csv:
            return true
        }
    }
}

// MARK: - Import Sheet

struct ImportSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ImportExportService.ImportFormat = .genericCSV
    @State private var selectedFileURL: URL?
    @State private var password = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Import data")
                .font(DodoTypography.title)
                .foregroundColor(DodoColors.textPrimary)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Import format")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                Picker("Format", selection: $selectedFormat) {
                    ForEach(ImportExportService.ImportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            // File selection
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("File")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                HStack {
                    Text(selectedFileURL?.lastPathComponent ?? "No file selected")
                        .font(DodoTypography.body)
                        .foregroundColor(selectedFileURL == nil ? DodoColors.textSecondary : DodoColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Button("Choose file...") {
                        selectFile()
                    }
                    .buttonStyle(.dodoSecondary)
                }
            }

            if selectedFormat == .dodopassEncrypted {
                DodoSecureField(
                    label: "Decryption password",
                    text: $password,
                    placeholder: "Enter password for encrypted backup"
                )
            }

            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundColor(DodoColors.accent)
                Text("Imported items will be added to your existing vault.")
                    .font(DodoTypography.caption)
                    .foregroundColor(DodoColors.textSecondary)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.dodoSecondary)

                Spacer()

                Button("Import") {
                    if let url = selectedFileURL {
                        viewModel.performImport(format: selectedFormat, fileURL: url, password: password.isEmpty ? nil : password)
                        dismiss()
                    }
                }
                .buttonStyle(.dodoPrimary)
                .disabled(!isValid)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 450)
        .background(DodoColors.background)
    }

    private var isValid: Bool {
        guard selectedFileURL != nil else { return false }

        if selectedFormat == .dodopassEncrypted {
            return !password.isEmpty
        }

        return true
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        let extensions = selectedFormat.supportedExtensions
        panel.allowedContentTypes = extensions.compactMap { ext in
            UTType(filenameExtension: ext)
        }

        if panel.runModal() == .OK {
            selectedFileURL = panel.url
        }
    }
}

// MARK: - Change Password Sheet

struct ChangePasswordSheet: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var error: String?
    @State private var isLoading = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Change master password")
                .font(DodoTypography.title)
                .foregroundColor(DodoColors.textPrimary)

            VStack(spacing: Theme.Spacing.md) {
                DodoSecureField(
                    label: "Current password",
                    text: $currentPassword,
                    placeholder: "Enter current password"
                )

                DodoSecureField(
                    label: "New password",
                    text: $newPassword,
                    placeholder: "Enter new password"
                )

                PasswordStrengthIndicator(password: newPassword)

                DodoSecureField(
                    label: "Confirm new password",
                    text: $confirmPassword,
                    placeholder: "Confirm new password"
                )

                if let error = error {
                    Text(error)
                        .font(DodoTypography.bodySmall)
                        .foregroundColor(DodoColors.error)
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.dodoSecondary)

                Spacer()

                Button {
                    changePassword()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Change password")
                    }
                }
                .buttonStyle(.dodoPrimary)
                .disabled(!isValid || isLoading)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 400)
        .background(DodoColors.background)
    }

    private var isValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= CryptoConstants.minimumPasswordLength &&
        newPassword == confirmPassword
    }

    private func changePassword() {
        guard isValid else { return }

        isLoading = true
        error = nil

        Task {
            do {
                try await VaultManager.shared.changePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
