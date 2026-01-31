import Foundation

/// An identity/personal information item stored in the vault.
struct Identity: VaultItem {
    let id: UUID
    var title: String

    // Personal information
    var firstName: String
    var middleName: String
    var lastName: String
    var dateOfBirth: Date?
    var gender: Gender?

    // Contact information
    var email: String
    var phone: String

    // Address
    var address: Address

    // Identification
    var ssn: String
    var passportNumber: String
    var driverLicense: String

    // Employment
    var company: String
    var jobTitle: String

    var notes: String
    var tags: [String]
    var favorite: Bool
    let createdAt: Date
    var modifiedAt: Date
    var icon: ItemIcon
    var customFields: [CustomField]

    var category: ItemCategory { .identity }

    init(
        id: UUID = UUID(),
        title: String,
        firstName: String = "",
        middleName: String = "",
        lastName: String = "",
        dateOfBirth: Date? = nil,
        gender: Gender? = nil,
        email: String = "",
        phone: String = "",
        address: Address = Address(),
        ssn: String = "",
        passportNumber: String = "",
        driverLicense: String = "",
        company: String = "",
        jobTitle: String = "",
        notes: String = "",
        tags: [String] = [],
        favorite: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        icon: ItemIcon = .identity,
        customFields: [CustomField] = []
    ) {
        self.id = id
        self.title = title
        self.firstName = firstName
        self.middleName = middleName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.email = email
        self.phone = phone
        self.address = address
        self.ssn = ssn
        self.passportNumber = passportNumber
        self.driverLicense = driverLicense
        self.company = company
        self.jobTitle = jobTitle
        self.notes = notes
        self.tags = tags
        self.favorite = favorite
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.icon = icon
        self.customFields = customFields
    }

    func searchableText() -> String {
        var text = [title, firstName, middleName, lastName, email, phone, company, jobTitle]
        text.append(contentsOf: tags)
        text.append(notes)
        text.append(contentsOf: customFields.map { "\($0.label) \($0.value)" })
        return text.joined(separator: " ").lowercased()
    }

    /// Returns the full name.
    var fullName: String {
        var parts: [String] = []
        if !firstName.isEmpty { parts.append(firstName) }
        if !middleName.isEmpty { parts.append(middleName) }
        if !lastName.isEmpty { parts.append(lastName) }
        return parts.joined(separator: " ")
    }

    /// Returns the masked SSN (shows only last 4 digits).
    var maskedSSN: String {
        guard ssn.count >= 4 else { return ssn }
        let lastFour = String(ssn.suffix(4))
        return "•••-••-\(lastFour)"
    }

    /// Returns formatted SSN (XXX-XX-XXXX).
    var formattedSSN: String {
        let digits = ssn.filter { $0.isNumber }
        guard digits.count == 9 else { return ssn }
        let area = String(digits.prefix(3))
        let group = String(digits.dropFirst(3).prefix(2))
        let serial = String(digits.suffix(4))
        return "\(area)-\(group)-\(serial)"
    }

    /// Returns the age based on date of birth.
    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dob, to: now)
        return ageComponents.year
    }
}

// MARK: - Gender

/// Gender options for identity.
enum Gender: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case other
    case preferNotToSay = "prefer_not_to_say"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .other:
            return "Other"
        case .preferNotToSay:
            return "Prefer not to say"
        }
    }
}

// MARK: - Sample Data

extension Identity {
    static let example = Identity(
        title: "Personal Identity",
        firstName: "John",
        middleName: "Michael",
        lastName: "Doe",
        dateOfBirth: Calendar.current.date(from: DateComponents(year: 1990, month: 5, day: 15)),
        gender: .male,
        email: "john.doe@email.com",
        phone: "+1 (555) 123-4567",
        address: Address(
            street: "123 Main Street",
            city: "New York",
            state: "NY",
            postalCode: "10001",
            country: "USA"
        ),
        company: "Tech Corp",
        jobTitle: "Software Engineer",
        favorite: true
    )

    static let examples: [Identity] = [
        Identity(
            title: "Work Identity",
            firstName: "Jane",
            lastName: "Smith",
            email: "jane.smith@company.com",
            phone: "+1 (555) 987-6543",
            company: "Acme Inc",
            jobTitle: "Product Manager",
            tags: ["work"],
            icon: ItemIcon(symbolName: "briefcase.fill", colorName: "blue")
        )
    ]
}
