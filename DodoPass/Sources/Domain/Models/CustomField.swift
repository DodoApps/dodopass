import Foundation

/// A custom field that can be added to any vault item.
struct CustomField: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var label: String
    var value: String
    var fieldType: FieldType
    var isHidden: Bool

    init(
        id: UUID = UUID(),
        label: String,
        value: String,
        fieldType: FieldType = .text,
        isHidden: Bool = false
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.fieldType = fieldType
        self.isHidden = isHidden
    }

    /// Creates a text custom field.
    static func text(label: String, value: String) -> CustomField {
        CustomField(label: label, value: value, fieldType: .text)
    }

    /// Creates a hidden/password custom field.
    static func hidden(label: String, value: String) -> CustomField {
        CustomField(label: label, value: value, fieldType: .hidden, isHidden: true)
    }

    /// Creates a URL custom field.
    static func url(label: String, value: String) -> CustomField {
        CustomField(label: label, value: value, fieldType: .url)
    }

    /// Creates a date custom field.
    static func date(label: String, value: Date) -> CustomField {
        let formatter = ISO8601DateFormatter()
        return CustomField(label: label, value: formatter.string(from: value), fieldType: .date)
    }
}

// MARK: - Field Type

/// The type of a custom field.
enum FieldType: String, Codable, CaseIterable, Identifiable {
    case text
    case hidden
    case url
    case date
    case email
    case phone
    case number

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .hidden:
            return "Hidden"
        case .url:
            return "URL"
        case .date:
            return "Date"
        case .email:
            return "Email"
        case .phone:
            return "Phone"
        case .number:
            return "Number"
        }
    }

    var systemImage: String {
        switch self {
        case .text:
            return "textformat"
        case .hidden:
            return "eye.slash"
        case .url:
            return "link"
        case .date:
            return "calendar"
        case .email:
            return "envelope"
        case .phone:
            return "phone"
        case .number:
            return "number"
        }
    }
}
