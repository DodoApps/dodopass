import Foundation
import SwiftUI

// MARK: - String Localization Extension

extension String {
    /// Returns the localized version of this string.
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized version of this string with arguments.
    func localized(_ args: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: args)
    }
}

// MARK: - Localized String Keys

/// Centralized localization keys for type-safe access.
enum L10n {
    // MARK: - General
    enum General {
        static let cancel = "general.cancel".localized
        static let save = "general.save".localized
        static let delete = "general.delete".localized
        static let edit = "general.edit".localized
        static let done = "general.done".localized
        static let close = "general.close".localized
        static let search = "general.search".localized
        static let copy = "general.copy".localized
        static let copied = "general.copied".localized
        static let show = "general.show".localized
        static let hide = "general.hide".localized
        static let add = "general.add".localized
        static let remove = "general.remove".localized
        static let settings = "general.settings".localized
        static let ok = "general.ok".localized
        static let error = "general.error".localized
        static let warning = "general.warning".localized
        static let success = "general.success".localized
    }
    
    // MARK: - Lock Screen
    enum Lock {
        static let title = "lock.title".localized
        static let subtitle = "lock.subtitle".localized
        static let passwordPlaceholder = "lock.password.placeholder".localized
        static let unlock = "lock.unlock".localized
        static let touchID = "lock.touchid".localized
        static let touchIDReason = "lock.touchid.reason".localized
        static let errorInvalid = "lock.error.invalid".localized
        static let errorTouchID = "lock.error.touchid".localized
    }
    
    // MARK: - Sidebar
    enum Sidebar {
        static let all = "sidebar.all".localized
        static let favorites = "sidebar.favorites".localized
        static let logins = "sidebar.logins".localized
        static let secureNotes = "sidebar.securenotes".localized
        static let creditCards = "sidebar.creditcards".localized
        static let identities = "sidebar.identities".localized
        static let tags = "sidebar.tags".localized
        static let trash = "sidebar.trash".localized
    }
    
    // MARK: - Item Types
    enum ItemType {
        static let login = "item.type.login".localized
        static let secureNote = "item.type.securenote".localized
        static let creditCard = "item.type.creditcard".localized
        static let identity = "item.type.identity".localized
    }
    
    // MARK: - Item List
    enum ItemList {
        static let emptyTitle = "itemlist.empty.title".localized
        static let emptySubtitle = "itemlist.empty.subtitle".localized
        static let searchPlaceholder = "itemlist.search.placeholder".localized
        static let noResults = "itemlist.search.noresults".localized
    }
    
    // MARK: - Item Detail
    enum ItemDetail {
        static let title = "itemdetail.title".localized
        static let username = "itemdetail.username".localized
        static let password = "itemdetail.password".localized
        static let website = "itemdetail.website".localized
        static let websites = "itemdetail.websites".localized
        static let notes = "itemdetail.notes".localized
        static let tags = "itemdetail.tags".localized
        static let created = "itemdetail.created".localized
        static let modified = "itemdetail.modified".localized
        static let favorite = "itemdetail.favorite".localized
        static let copyPassword = "itemdetail.copypassword".localized
        static let copyUsername = "itemdetail.copyusername".localized
        static let openURL = "itemdetail.openurl".localized
        static let passwordHistory = "itemdetail.passwordhistory".localized
        static func passwordHistoryCount(_ count: Int) -> String {
            "itemdetail.passwordhistory.count".localized(count)
        }
        static let otp = "itemdetail.otp".localized
    }
    
    // MARK: - Password Generator
    enum Generator {
        static let title = "generator.title".localized
        static let length = "generator.length".localized
        static let uppercase = "generator.uppercase".localized
        static let lowercase = "generator.lowercase".localized
        static let numbers = "generator.numbers".localized
        static let symbols = "generator.symbols".localized
        static let generate = "generator.generate".localized
        static let copy = "generator.copy".localized
        static let use = "generator.use".localized
    }
    
    // MARK: - Settings
    enum Settings {
        static let title = "settings.title".localized
        static let general = "settings.general".localized
        static let security = "settings.security".localized
        static let sync = "settings.sync".localized
        static let about = "settings.about".localized
    }
    
    // MARK: - Delete
    enum Delete {
        static let title = "delete.title".localized
        static let message = "delete.message".localized
        static let confirm = "delete.confirm".localized
    }
    
    // MARK: - Icon Picker
    enum IconPicker {
        static let symbol = "iconpicker.symbol".localized
        static let color = "iconpicker.color".localized
    }
    
    // MARK: - Clipboard
    enum Clipboard {
        static let cleared = "clipboard.cleared".localized
        static let copied = "clipboard.copied".localized
    }
}
