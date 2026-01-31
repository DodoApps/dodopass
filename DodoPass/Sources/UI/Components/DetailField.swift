import SwiftUI

/// A field in the detail view with label, value, and actions.
struct DetailField: View {
    let label: String
    let value: String
    var isSecret: Bool = false
    var isMultiline: Bool = false
    var isEditing: Bool = false
    @Binding var editValue: String
    var onCopy: (() -> Void)?

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Label
            HStack {
                Text(label)
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                Spacer()

                if !isEditing {
                    HStack(spacing: Theme.Spacing.sm) {
                        if isSecret {
                            Button {
                                withAnimation(Theme.Animation.fast) {
                                    isRevealed.toggle()
                                }
                            } label: {
                                Image(systemName: isRevealed ? "eye.slash" : "eye")
                                    .font(.system(size: 12))
                                    .foregroundColor(DodoColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .help(isRevealed ? "Hide" : "Reveal")
                        }

                        if let onCopy = onCopy, !value.isEmpty {
                            Button {
                                onCopy()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(DodoColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copy")
                        }
                    }
                }
            }

            // Value
            if isEditing {
                if isMultiline {
                    TextEditor(text: $editValue)
                        .font(DodoTypography.body)
                        .foregroundColor(DodoColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(DodoColors.backgroundTertiary)
                        .frame(minHeight: 100)
                        .cornerRadius(Theme.Radius.sm)
                } else if isSecret {
                    DodoSecureField(label: "", text: $editValue)
                } else {
                    TextField("", text: $editValue)
                        .textFieldStyle(.dodo)
                }
            } else {
                if isMultiline {
                    Text(value.isEmpty ? "—" : value)
                        .font(DodoTypography.body)
                        .foregroundColor(value.isEmpty ? DodoColors.textTertiary : DodoColors.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(displayValue)
                        .font(isSecret ? DodoTypography.mono : DodoTypography.body)
                        .foregroundColor(value.isEmpty ? DodoColors.textTertiary : DodoColors.textPrimary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var displayValue: String {
        if value.isEmpty {
            return "—"
        }
        if isSecret && !isRevealed {
            return String(repeating: "•", count: min(value.count, 20))
        }
        return value
    }
}

// MARK: - Detail Section

/// A section in the detail view with a title and content.
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(DodoTypography.titleSmall)
                .foregroundColor(DodoColors.textPrimary)

            content()
        }
        .padding(Theme.Spacing.md)
        .background(DodoColors.backgroundSecondary)
        .cornerRadius(Theme.Radius.md)
    }
}

// MARK: - URL Field

/// A field that displays and opens a URL.
struct URLField: View {
    let label: String
    let url: String
    var isEditing: Bool = false
    @Binding var editValue: String
    var onCopy: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(label)
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                Spacer()

                if !isEditing && !url.isEmpty {
                    HStack(spacing: Theme.Spacing.sm) {
                        Button {
                            openURL()
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12))
                                .foregroundColor(DodoColors.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Open in browser")

                        if let onCopy = onCopy {
                            Button {
                                onCopy()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(DodoColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copy")
                        }
                    }
                }
            }

            if isEditing {
                TextField("https://example.com", text: $editValue)
                    .textFieldStyle(.dodo)
            } else {
                Text(url.isEmpty ? "—" : url)
                    .font(DodoTypography.body)
                    .foregroundColor(url.isEmpty ? DodoColors.textTertiary : DodoColors.accent)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func openURL() {
        guard let url = URL(string: url) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Tags Field

/// A field that displays and edits tags.
struct TagsField: View {
    let label: String
    @Binding var tags: [String]
    var isEditing: Bool = false

    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(DodoTypography.label)
                .foregroundColor(DodoColors.textSecondary)

            if tags.isEmpty && !isEditing {
                Text("No tags")
                    .font(DodoTypography.body)
                    .foregroundColor(DodoColors.textTertiary)
            } else {
                FlowLayout(spacing: Theme.Spacing.xs) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(tag: tag, isEditing: isEditing) {
                            if isEditing {
                                tags.removeAll { $0 == tag }
                            }
                        }
                    }

                    if isEditing {
                        AddTagButton { newTagName in
                            if !tags.contains(newTagName) {
                                tags.append(newTagName)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: String
    var isEditing: Bool = false
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Text(tag)
                .font(DodoTypography.label)
                .foregroundColor(DodoColors.accent)

            if isEditing {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DodoColors.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(DodoColors.accentSubtle)
        .cornerRadius(Theme.Radius.full)
    }
}

// MARK: - Add Tag Button

struct AddTagButton: View {
    var onAdd: (String) -> Void

    @State private var isAdding = false
    @State private var newTag = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isAdding {
            TextField("Tag name", text: $newTag)
                .font(DodoTypography.label)
                .textFieldStyle(.plain)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xxs)
                .frame(width: 100)
                .background(DodoColors.backgroundTertiary)
                .cornerRadius(Theme.Radius.full)
                .focused($isFocused)
                .onSubmit {
                    submitTag()
                }
                .onAppear {
                    isFocused = true
                }
        } else {
            Button {
                isAdding = true
            } label: {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add tag")
                        .font(DodoTypography.label)
                }
                .foregroundColor(DodoColors.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xxs)
                .background(DodoColors.backgroundTertiary)
                .cornerRadius(Theme.Radius.full)
            }
            .buttonStyle(.plain)
        }
    }

    private func submitTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onAdd(trimmed)
        }
        newTag = ""
        isAdding = false
    }
}

// MARK: - Flow Layout

/// A layout that flows content horizontally and wraps to new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func calculateLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        let width = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxWidth = max(maxWidth, currentX - spacing)
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Preview

#if DEBUG
struct DetailField_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var editValue = ""
        @State private var tags = ["work", "important"]

        var body: some View {
            VStack(spacing: 20) {
                DetailField(label: "Username", value: "user@example.com", editValue: $editValue)

                DetailField(label: "Password", value: "secret123", isSecret: true, editValue: $editValue) {
                    print("Copied!")
                }

                DetailSection(title: "Login details") {
                    DetailField(label: "Username", value: "user@example.com", editValue: $editValue)
                }

                TagsField(label: "Tags", tags: $tags, isEditing: true)
            }
            .padding()
            .background(DodoColors.background)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
