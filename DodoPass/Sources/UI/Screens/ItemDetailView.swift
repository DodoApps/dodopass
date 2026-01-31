import SwiftUI

/// A view showing the details of a vault item.
struct ItemDetailView: View {
    let item: any VaultItem
    @ObservedObject var vaultManager: VaultManager
    var onDelete: (() -> Void)?

    @State private var showEditor = false
    @State private var showDeleteConfirmation = false
    @State private var showPasswordHistory = false
    @State private var showPasswordGenerator = false

    @StateObject private var toastManager = ToastManager()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Header
                headerView

                Divider()

                // Content based on item type
                switch item.category {
                case .login:
                    if let login = item as? LoginItem {
                        LoginDetailContent(login: login, isEditing: false)
                    }
                case .secureNote:
                    if let note = item as? SecureNote {
                        SecureNoteDetailContent(note: note, isEditing: false)
                    }
                case .creditCard:
                    if let card = item as? CreditCard {
                        CreditCardDetailContent(card: card, isEditing: false)
                    }
                case .identity:
                    if let identity = item as? Identity {
                        IdentityDetailContent(identity: identity, isEditing: false)
                    }
                }

                // Tags
                if !item.tags.isEmpty {
                    tagsSection
                }

                // Notes
                if !item.notes.isEmpty {
                    notesSection
                }

                // Metadata
                metadataSection

                Spacer()
            }
            .padding(Theme.Spacing.lg)
        }
        .background(DodoColors.background)
        .toolbar {
            toolbarContent
        }
        .confirmationDialog("Delete item?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showPasswordHistory) {
            if let login = item as? LoginItem {
                PasswordHistorySheet(history: login.passwordHistory)
            }
        }
        .sheet(isPresented: $showPasswordGenerator) {
            PasswordGeneratorPopover(isPresented: $showPasswordGenerator) { generated in
                // Copy generated password
                ClipboardManager.shared.copy(generated)
            }
        }
        .sheet(isPresented: $showEditor) {
            ItemEditorView(
                category: item.category,
                vaultManager: vaultManager,
                item: item
            )
        }
        .environment(\.toastManager, toastManager)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Theme.Spacing.md) {
            ItemIconView(icon: item.icon, category: item.category, size: .large)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                HStack {
                    Text(item.title)
                        .font(DodoTypography.titleLarge)
                        .foregroundColor(DodoColors.textPrimary)

                    if item.favorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DodoColors.warning)
                    }
                }

                Text(item.category.displayName)
                    .font(DodoTypography.bodySmall)
                    .foregroundColor(DodoColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        DetailSection(title: "Tags") {
            if item.tags.isEmpty {
                Text("No tags")
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textTertiary)
            } else {
                FlowLayout(spacing: Theme.Spacing.xs) {
                    ForEach(item.tags, id: \.self) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        DetailSection(title: "Notes") {
            if item.notes.isEmpty {
                Text("No notes")
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textTertiary)
            } else {
                Text(item.notes)
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textPrimary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("Created")
                    .font(DodoTypography.caption)
                    .foregroundColor(DodoColors.textTertiary)

                Spacer()

                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DodoTypography.caption)
                    .foregroundColor(DodoColors.textSecondary)
            }

            HStack {
                Text("Modified")
                    .font(DodoTypography.caption)
                    .foregroundColor(DodoColors.textTertiary)

                Spacer()

                Text(item.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DodoTypography.caption)
                    .foregroundColor(DodoColors.textSecondary)
            }
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                toggleFavorite()
            } label: {
                Image(systemName: item.favorite ? "star.fill" : "star")
                    .foregroundColor(item.favorite ? DodoColors.warning : DodoColors.textSecondary)
            }
            .help("Toggle favorite")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showEditor = true
            } label: {
                Image(systemName: "pencil")
            }
            .help("Edit")
        }

        ToolbarItem(placement: .destructiveAction) {
            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(DodoColors.error)
            }
            .help("Delete")
        }
    }

    // MARK: - Actions

    private func toggleFavorite() {
        var mutableItem = item
        mutableItem.favorite.toggle()
        Task {
            try? await vaultManager.updateItem(mutableItem)
        }
    }

    private func deleteItem() {
        Task {
            try? await vaultManager.deleteItem(id: item.id)
            onDelete?()
        }
    }
}

// MARK: - Login Detail Content

struct LoginDetailContent: View {
    let login: LoginItem
    var isEditing: Bool = false

    var body: some View {
        DetailSection(title: "Login details") {
            CopyField(label: "Username", value: login.username)

            CopyField(label: "Password", value: login.password, isSecret: true)

            if !login.urls.isEmpty {
                ForEach(login.urls.indices, id: \.self) { index in
                    URLField(
                        label: index == 0 ? "Website" : "Website \(index + 1)",
                        url: login.urls[index],
                        editValue: .constant("")
                    ) {
                        ClipboardManager.shared.copy(login.urls[index], clearAfter: nil)
                    }
                }
            }

            if login.totpSecret != nil {
                // TODO: TOTP display
                CopyField(label: "One-time password", value: "123456", isSecret: false)
            }
        }

        if !login.passwordHistory.isEmpty {
            DetailSection(title: "Password history") {
                Text("\(login.passwordHistory.count) previous passwords")
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textSecondary)
            }
        }
    }
}

// MARK: - Secure Note Detail Content

struct SecureNoteDetailContent: View {
    let note: SecureNote
    var isEditing: Bool = false

    var body: some View {
        DetailSection(title: "Note") {
            if note.content.isEmpty {
                Text("No content")
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textSecondary)
                    .italic()
            } else {
                Text(note.content)
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Credit Card Detail Content

struct CreditCardDetailContent: View {
    let card: CreditCard
    var isEditing: Bool = false

    var body: some View {
        DetailSection(title: "Card details") {
            CopyField(label: "Cardholder name", value: card.cardholderName)

            CopyField(label: "Card number", value: card.formattedCardNumber, isSecret: true)

            HStack(spacing: Theme.Spacing.lg) {
                CopyField(label: "Expiration", value: card.formattedExpiration)

                CopyField(label: "CVV", value: card.cvv, isSecret: true)
            }

            if !card.pin.isEmpty {
                CopyField(label: "PIN", value: card.pin, isSecret: true)
            }

            HStack {
                Text("Type")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                Spacer()

                Text(card.cardType.displayName)
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textPrimary)
            }
        }

        if let address = card.billingAddress, !address.isEmpty {
            DetailSection(title: "Billing address") {
                Text(address.formattedAddress)
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textPrimary)
            }
        }
    }
}

// MARK: - Identity Detail Content

struct IdentityDetailContent: View {
    let identity: Identity
    var isEditing: Bool = false

    var body: some View {
        DetailSection(title: "Personal information") {
            if !identity.fullName.isEmpty {
                CopyField(label: "Full name", value: identity.fullName)
            }

            if !identity.email.isEmpty {
                CopyField(label: "Email", value: identity.email)
            }

            if !identity.phone.isEmpty {
                CopyField(label: "Phone", value: identity.phone)
            }

            if let dob = identity.dateOfBirth {
                HStack {
                    Text("Date of birth")
                        .font(DodoTypography.label)
                        .foregroundColor(DodoColors.textSecondary)

                    Spacer()

                    Text(dob.formatted(date: .abbreviated, time: .omitted))
                        .font(DodoTypography.body)
                        .foregroundColor(DodoColors.textPrimary)
                }
            }
        }

        if !identity.ssn.isEmpty || !identity.passportNumber.isEmpty || !identity.driverLicense.isEmpty {
            DetailSection(title: "Identification") {
                if !identity.ssn.isEmpty {
                    CopyField(label: "SSN", value: identity.formattedSSN, isSecret: true)
                }

                if !identity.passportNumber.isEmpty {
                    CopyField(label: "Passport", value: identity.passportNumber, isSecret: true)
                }

                if !identity.driverLicense.isEmpty {
                    CopyField(label: "Driver's license", value: identity.driverLicense, isSecret: true)
                }
            }
        }

        if !identity.address.isEmpty {
            DetailSection(title: "Address") {
                Text(identity.address.formattedAddress)
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textPrimary)
            }
        }

        if !identity.company.isEmpty || !identity.jobTitle.isEmpty {
            DetailSection(title: "Employment") {
                if !identity.company.isEmpty {
                    CopyField(label: "Company", value: identity.company)
                }

                if !identity.jobTitle.isEmpty {
                    CopyField(label: "Job title", value: identity.jobTitle)
                }
            }
        }
    }
}

// MARK: - Password History Sheet

struct PasswordHistorySheet: View {
    let history: [PasswordHistoryEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Password history")
                    .font(DodoTypography.title)
                    .foregroundColor(DodoColors.textPrimary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.dodoSecondary)
            }
            .padding(Theme.Spacing.md)

            Divider()

            List(history) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        PasswordDisplay(password: entry.password) {
                            ClipboardManager.shared.copy(entry.password)
                        }

                        Text(entry.changedAt.formatted())
                            .font(DodoTypography.caption)
                            .foregroundColor(DodoColors.textTertiary)
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            .listStyle(.plain)
        }
        .frame(width: 400, height: 400)
        .background(DodoColors.background)
    }
}

// MARK: - Preview

#if DEBUG
struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ItemDetailView(
            item: LoginItem.example,
            vaultManager: VaultManager.shared
        )
        .frame(width: 500, height: 700)
    }
}
#endif
