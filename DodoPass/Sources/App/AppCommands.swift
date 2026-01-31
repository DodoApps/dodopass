import SwiftUI

/// Keyboard shortcuts and menu commands.
struct AppCommands: Commands {
    @ObservedObject var vaultManager: VaultManager

    var body: some Commands {
        // Replace default New commands
        CommandGroup(replacing: .newItem) {
            Button("New login") {
                NotificationCenter.default.post(
                    name: .createNewItem,
                    object: nil,
                    userInfo: ["category": ItemCategory.login]
                )
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(vaultManager.isLocked)

            Button("New secure note") {
                NotificationCenter.default.post(
                    name: .createNewItem,
                    object: nil,
                    userInfo: ["category": ItemCategory.secureNote]
                )
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(vaultManager.isLocked)

            Button("New credit card") {
                NotificationCenter.default.post(
                    name: .createNewItem,
                    object: nil,
                    userInfo: ["category": ItemCategory.creditCard]
                )
            }
            .disabled(vaultManager.isLocked)

            Button("New identity") {
                NotificationCenter.default.post(
                    name: .createNewItem,
                    object: nil,
                    userInfo: ["category": ItemCategory.identity]
                )
            }
            .disabled(vaultManager.isLocked)
        }

        // File menu additions
        CommandGroup(after: .newItem) {
            Divider()

            Button("Lock vault") {
                Task {
                    await vaultManager.lock()
                }
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(vaultManager.isLocked)
        }

        // Edit menu - search
        CommandGroup(after: .textEditing) {
            Divider()

            Button("Quick switcher") {
                NotificationCenter.default.post(name: .showQuickSwitcher, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command])
            .disabled(vaultManager.isLocked)

            Button("Find") {
                NotificationCenter.default.post(name: .focusSearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command])
            .disabled(vaultManager.isLocked)
        }

        // View menu
        CommandGroup(after: .sidebar) {
            Button("Show all items") {
                NotificationCenter.default.post(
                    name: .selectCategory,
                    object: nil,
                    userInfo: ["category": SidebarCategory.all]
                )
            }
            .keyboardShortcut("1", modifiers: [.command])
            .disabled(vaultManager.isLocked)

            Button("Show favorites") {
                NotificationCenter.default.post(
                    name: .selectCategory,
                    object: nil,
                    userInfo: ["category": SidebarCategory.favorites]
                )
            }
            .keyboardShortcut("2", modifiers: [.command])
            .disabled(vaultManager.isLocked)

            Button("Show logins") {
                NotificationCenter.default.post(
                    name: .selectCategory,
                    object: nil,
                    userInfo: ["category": SidebarCategory.category(.login)]
                )
            }
            .keyboardShortcut("3", modifiers: [.command])
            .disabled(vaultManager.isLocked)

            Button("Show secure notes") {
                NotificationCenter.default.post(
                    name: .selectCategory,
                    object: nil,
                    userInfo: ["category": SidebarCategory.category(.secureNote)]
                )
            }
            .keyboardShortcut("4", modifiers: [.command])
            .disabled(vaultManager.isLocked)
        }

        // Help menu
        CommandGroup(replacing: .help) {
            Button("DodoPass help") {
                if let url = URL(string: "https://dodopass.app/help") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button("Report an issue") {
                if let url = URL(string: "https://github.com/dodopass/dodopass/issues") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createNewItem = Notification.Name("createNewItem")
    static let showQuickSwitcher = Notification.Name("showQuickSwitcher")
    static let focusSearch = Notification.Name("focusSearch")
    static let selectCategory = Notification.Name("selectCategory")
    // lockVault is defined in MainView.swift
    static let unlockVault = Notification.Name("unlockVault")
}
