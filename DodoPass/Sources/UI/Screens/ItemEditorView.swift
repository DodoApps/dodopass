import SwiftUI

/// A view for creating or editing vault items.
struct ItemEditorView: View {
    let category: ItemCategory
    @ObservedObject var vaultManager: VaultManager
    var item: (any VaultItem)? = nil
    var onSave: ((any VaultItem) -> Void)?
    var onCancel: (() -> Void)?

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var urls: [String] = [""]
    @State private var notes = ""
    @State private var tags: [String] = []
    @State private var icon: ItemIcon

    // Credit card fields
    @State private var cardholderName = ""
    @State private var cardNumber = ""
    @State private var expirationMonth = 1
    @State private var expirationYear = Calendar.current.component(.year, from: Date())
    @State private var cvv = ""

    // Secure note fields
    @State private var noteContent = ""

    // Identity fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""

    @State private var showPasswordGenerator = false
    @State private var showIconPicker = false
    @State private var isLoading = false
    @State private var error: String?

    @Environment(\.dismiss) private var dismiss

    init(category: ItemCategory, vaultManager: VaultManager, item: (any VaultItem)? = nil, onSave: ((any VaultItem) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.category = category
        self.vaultManager = vaultManager
        self.item = item
        self.onSave = onSave
        self.onCancel = onCancel
        self._icon = State(initialValue: ItemIcon(symbolName: category.systemImage, colorName: "blue"))

        // Initialize from existing item if editing
        if let login = item as? LoginItem {
            _title = State(initialValue: login.title)
            _username = State(initialValue: login.username)
            _password = State(initialValue: login.password)
            _urls = State(initialValue: login.urls.isEmpty ? [""] : login.urls)
            _notes = State(initialValue: login.notes)
            _tags = State(initialValue: login.tags)
            _icon = State(initialValue: login.icon)
        } else if let note = item as? SecureNote {
            _title = State(initialValue: note.title)
            _noteContent = State(initialValue: note.content)
            _notes = State(initialValue: note.notes)
            _tags = State(initialValue: note.tags)
            _icon = State(initialValue: note.icon)
        } else if let card = item as? CreditCard {
            _title = State(initialValue: card.title)
            _cardholderName = State(initialValue: card.cardholderName)
            _cardNumber = State(initialValue: card.cardNumber)
            _expirationMonth = State(initialValue: card.expirationMonth)
            _expirationYear = State(initialValue: card.expirationYear)
            _cvv = State(initialValue: card.cvv)
            _notes = State(initialValue: card.notes)
            _tags = State(initialValue: card.tags)
            _icon = State(initialValue: card.icon)
        } else if let identity = item as? Identity {
            _title = State(initialValue: identity.title)
            _firstName = State(initialValue: identity.firstName)
            _lastName = State(initialValue: identity.lastName)
            _email = State(initialValue: identity.email)
            _phone = State(initialValue: identity.phone)
            _notes = State(initialValue: identity.notes)
            _tags = State(initialValue: identity.tags)
            _icon = State(initialValue: identity.icon)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Title & Icon
                    titleSection

                    Divider()

                    // Category-specific fields
                    switch category {
                    case .login:
                        loginFields
                    case .secureNote:
                        secureNoteFields
                    case .creditCard:
                        creditCardFields
                    case .identity:
                        identityFields
                    }

                    Divider()

                    // Tags
                    TagsField(label: "Tags", tags: $tags, isEditing: true)

                    // Notes
                    notesField

                    if let error = error {
                        Text(error)
                            .font(DodoTypography.bodySmall)
                            .foregroundColor(DodoColors.error)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .frame(width: 500, height: 600)
        .background(DodoColors.background)
        .sheet(isPresented: $showPasswordGenerator) {
            PasswordGeneratorPopover(isPresented: $showPasswordGenerator) { generated in
                password = generated
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Cancel") {
                onCancel?()
                dismiss()
            }
            .buttonStyle(.dodoSecondary)

            Spacer()

            Text(item == nil ? "New \(category.displayName.lowercased())" : "Edit \(category.displayName.lowercased())")
                .font(DodoTypography.title)
                .foregroundColor(DodoColors.textPrimary)

            Spacer()

            Button {
                save()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Save")
                }
            }
            .buttonStyle(.dodoPrimary)
            .disabled(!isValid || isLoading)
        }
        .padding(Theme.Spacing.md)
        .background(DodoColors.backgroundSecondary)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.lg) {
                ItemIconView(icon: icon, category: category, size: .large)
                    .onTapGesture {
                        showIconPicker = true
                    }
                    .popover(isPresented: $showIconPicker) {
                        IconPicker(selectedIcon: $icon)
                            .frame(width: 300, height: 350)
                    }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Title")
                        .font(DodoTypography.label)
                        .foregroundColor(DodoColors.textSecondary)

                    TextField("Enter title", text: $title)
                        .textFieldStyle(.dodo)
                }
            }
        }
    }

    // MARK: - Login Fields

    private var loginFields: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Username")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                TextField("Enter username or email", text: $username)
                    .textFieldStyle(.dodo)
            }

            DodoSecureField(
                label: "Password",
                text: $password,
                placeholder: "Enter password",
                showGenerateButton: true
            ) {
                showPasswordGenerator = true
            }

            PasswordStrengthIndicator(password: password)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Website URLs")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                ForEach(urls.indices, id: \.self) { index in
                    HStack {
                        TextField("https://", text: $urls[index])
                            .textFieldStyle(.dodo)

                        if urls.count > 1 {
                            Button {
                                urls.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(DodoColors.error)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    urls.append("")
                } label: {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Image(systemName: "plus")
                        Text("Add URL")
                    }
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Secure Note Fields

    private var secureNoteFields: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Content")
                .font(DodoTypography.label)
                .foregroundColor(DodoColors.textSecondary)

            TextEditor(text: $noteContent)
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textPrimary)
                .scrollContentBackground(.hidden)
                .background(DodoColors.backgroundTertiary)
                .frame(minHeight: 200)
                .cornerRadius(Theme.Radius.sm)
        }
    }

    // MARK: - Credit Card Fields

    private var creditCardFields: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Cardholder name")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                TextField("John Doe", text: $cardholderName)
                    .textFieldStyle(.dodo)
            }

            DodoSecureField(
                label: "Card number",
                text: $cardNumber,
                placeholder: "1234 5678 9012 3456"
            )

            HStack(spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Expiration")
                        .font(DodoTypography.label)
                        .foregroundColor(DodoColors.textSecondary)

                    HStack {
                        Picker("Month", selection: $expirationMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(String(format: "%02d", month)).tag(month)
                            }
                        }
                        .labelsHidden()

                        Text("/")
                            .foregroundColor(DodoColors.textSecondary)

                        Picker("Year", selection: $expirationYear) {
                            ForEach(currentYear...currentYear + 20, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .labelsHidden()
                    }
                }

                DodoSecureField(
                    label: "CVV",
                    text: $cvv,
                    placeholder: "123"
                )
            }
        }
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    // MARK: - Identity Fields

    private var identityFields: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("First name")
                        .font(DodoTypography.label)
                        .foregroundColor(DodoColors.textSecondary)

                    TextField("John", text: $firstName)
                        .textFieldStyle(.dodo)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Last name")
                        .font(DodoTypography.label)
                        .foregroundColor(DodoColors.textSecondary)

                    TextField("Doe", text: $lastName)
                        .textFieldStyle(.dodo)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Email")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                TextField("john@example.com", text: $email)
                    .textFieldStyle(.dodo)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Phone")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                TextField("+1 (555) 123-4567", text: $phone)
                    .textFieldStyle(.dodo)
            }
        }
    }

    // MARK: - Notes Field

    private var notesField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Notes")
                .font(DodoTypography.label)
                .foregroundColor(DodoColors.textSecondary)

            TextEditor(text: $notes)
                .font(DodoTypography.body)
                .scrollContentBackground(.hidden)
                .background(DodoColors.backgroundTertiary)
                .frame(minHeight: 80)
                .cornerRadius(Theme.Radius.sm)
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !title.isEmpty
    }

    // MARK: - Save

    private func save() {
        guard isValid else { return }

        isLoading = true
        error = nil

        Task {
            do {
                let newItem = buildItem()

                if item != nil {
                    try await vaultManager.updateItem(newItem)
                } else {
                    try await vaultManager.addItem(newItem)
                }

                onSave?(newItem)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func buildItem() -> any VaultItem {
        let filteredUrls = urls.filter { !$0.isEmpty }

        switch category {
        case .login:
            return LoginItem(
                id: (item as? LoginItem)?.id ?? UUID(),
                title: title,
                username: username,
                password: password,
                urls: filteredUrls,
                notes: notes,
                tags: tags,
                favorite: item?.favorite ?? false,
                createdAt: item?.createdAt ?? Date(),
                modifiedAt: Date(),
                icon: icon
            )
        case .secureNote:
            return SecureNote(
                id: (item as? SecureNote)?.id ?? UUID(),
                title: title,
                content: noteContent,
                notes: notes,
                tags: tags,
                favorite: item?.favorite ?? false,
                createdAt: item?.createdAt ?? Date(),
                modifiedAt: Date(),
                icon: icon
            )
        case .creditCard:
            return CreditCard(
                id: (item as? CreditCard)?.id ?? UUID(),
                title: title,
                cardholderName: cardholderName,
                cardNumber: cardNumber,
                expirationMonth: expirationMonth,
                expirationYear: expirationYear,
                cvv: cvv,
                notes: notes,
                tags: tags,
                favorite: item?.favorite ?? false,
                createdAt: item?.createdAt ?? Date(),
                modifiedAt: Date(),
                icon: icon
            )
        case .identity:
            return Identity(
                id: (item as? Identity)?.id ?? UUID(),
                title: title,
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phone,
                notes: notes,
                tags: tags,
                favorite: item?.favorite ?? false,
                createdAt: item?.createdAt ?? Date(),
                modifiedAt: Date(),
                icon: icon
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ItemEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ItemEditorView(
            category: .login,
            vaultManager: VaultManager.shared
        )
    }
}
#endif
