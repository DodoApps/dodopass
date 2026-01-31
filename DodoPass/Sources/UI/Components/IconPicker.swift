import SwiftUI

/// A picker for selecting an item icon - shows icons and colors immediately.
struct IconPicker: View {
    @Binding var selectedIcon: ItemIcon

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Symbol picker with scroll
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Symbol")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 6), count: 6), spacing: 6) {
                        ForEach(ItemIcon.availableSymbols, id: \.self) { symbol in
                            Button {
                                selectedIcon.symbolName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 18))
                                    .foregroundColor(
                                        selectedIcon.symbolName == symbol
                                        ? DodoColors.accent
                                        : DodoColors.textSecondary
                                    )
                                    .frame(width: 40, height: 40)
                                    .background(
                                        selectedIcon.symbolName == symbol
                                        ? DodoColors.accentSubtle
                                        : DodoColors.backgroundTertiary
                                    )
                                    .cornerRadius(Theme.Radius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            Divider()

            // Color picker
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Color")
                    .font(DodoTypography.label)
                    .foregroundColor(DodoColors.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 6), spacing: 8) {
                    ForEach(ItemIcon.availableColors, id: \.self) { color in
                        Button {
                            selectedIcon.colorName = color
                        } label: {
                            Circle()
                                .fill(DodoColors.iconColor(for: color))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedIcon.colorName == color
                                            ? DodoColors.textPrimary
                                            : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(DodoColors.backgroundSecondary)
    }
}

// MARK: - Color Picker Grid

struct ColorPickerGrid: View {
    @Binding var selectedColor: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ItemIcon.availableColors, id: \.self) { color in
                Button {
                    selectedColor = color
                } label: {
                    Circle()
                        .fill(DodoColors.iconColor(for: color))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(
                                    selectedColor == color ? DodoColors.textPrimary : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct IconPicker_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var icon = ItemIcon.login

        var body: some View {
            IconPicker(selectedIcon: $icon)
                .padding()
                .frame(width: 400)
                .background(DodoColors.background)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
