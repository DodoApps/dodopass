import SwiftUI

/// A search bar component.
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(DodoColors.textSecondary)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(DodoColors.textSecondary))
                .textFieldStyle(.plain)
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    withAnimation(Theme.Animation.fast) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DodoColors.textSecondary)
                }
                .buttonStyle(.plain)
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

// MARK: - Toolbar Search Field

/// A search field styled for the toolbar.
struct ToolbarSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(DodoColors.textSecondary)

            TextField("", text: $text, prompt: Text("Search").foregroundColor(DodoColors.textSecondary))
                .textFieldStyle(.plain)
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textPrimary)
                .frame(width: 150)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DodoColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(DodoColors.backgroundTertiary)
        .cornerRadius(Theme.Radius.sm)
    }
}

// MARK: - Keyboard Shortcut

extension View {
    /// Adds a keyboard shortcut for focusing the search field.
    func searchFocusable(isFocused: FocusState<Bool>.Binding) -> some View {
        self.modifier(SearchFocusModifier(isFocused: isFocused))
    }
}

struct SearchFocusModifier: ViewModifier {
    @FocusState.Binding var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
                        isFocused = true
                        return nil
                    }
                    return event
                }
            }
    }
}

// MARK: - Preview

#if DEBUG
struct SearchBar_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var text = ""

        var body: some View {
            VStack(spacing: 20) {
                SearchBar(text: $text)
                SearchBar(text: .constant("search query"))
                ToolbarSearchField(text: $text)
            }
            .padding()
            .frame(width: 300)
            .background(DodoColors.background)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
