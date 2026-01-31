import AppKit
import SwiftUI

/// Application delegate handling app lifecycle and menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        AuditLogger.shared.appLaunched()

        // Setup menu bar - enabled by default
        // Users can disable in Settings if they prefer
        if UserDefaults.standard.object(forKey: "showInMenuBar") == nil {
            UserDefaults.standard.set(true, forKey: "showInMenuBar")
        }
        if UserDefaults.standard.bool(forKey: "showInMenuBar") {
            setupMenuBar()
        }

        // Register for notifications
        setupNotifications()

        // Configure appearance
        configureAppearance()

        // Start IPC server for browser extension
        IPCServer.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AuditLogger.shared.appTerminated()

        // Lock vault and clear sensitive data
        Task {
            await VaultManager.shared.lock()
        }

        // Clear clipboard
        ClipboardManager.shared.clear()

        // Clear search index
        SearchIndex.shared.clear()

        // Stop IPC server
        Task { @MainActor in
            IPCServer.shared.stop()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Reopen main window if all windows are closed
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // App became active
    }

    func applicationWillResignActive(_ notification: Notification) {
        // App will resign active - start auto-lock timer
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "DodoPass")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())

        // Monitor clicks outside popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.closePopover()
            }
        }
    }

    @objc private func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                closePopover()
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // Screen lock notification
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        // Screen unlock notification
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        // Sleep notification
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }

    @objc private func screenLocked() {
        // Lock vault when screen locks
        Task {
            await VaultManager.shared.lock()
            AuditLogger.shared.autoLockTriggered(reason: "screen_locked")
        }
    }

    @objc private func screenUnlocked() {
        // Just log for now, don't auto-unlock
    }

    @objc private func systemWillSleep() {
        // Lock vault before sleep
        Task {
            await VaultManager.shared.lock()
            AuditLogger.shared.autoLockTriggered(reason: "system_sleep")
        }
    }

    // MARK: - Appearance

    private func configureAppearance() {
        // Force dark appearance
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @StateObject private var vaultManager = VaultManager.shared
    @State private var searchQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundColor(DodoColors.accent)

                Text("DodoPass")
                    .font(DodoTypography.title)
                    .foregroundColor(DodoColors.textPrimary)

                Spacer()

                if vaultManager.isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(DodoColors.textSecondary)
                } else {
                    Image(systemName: "lock.open.fill")
                        .foregroundColor(DodoColors.success)
                }
            }
            .padding(Theme.Spacing.md)
            .background(DodoColors.backgroundSecondary)

            Divider()

            if vaultManager.isLocked {
                // Locked state
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(DodoColors.textSecondary)

                    Text("Vault is locked")
                        .font(DodoTypography.body)
                        .foregroundColor(DodoColors.textSecondary)

                    Button("Open DodoPass") {
                        NSApp.activate(ignoringOtherApps: true)
                        for window in NSApp.windows {
                            if window.canBecomeMain && !window.title.contains("Item") {
                                window.makeKeyAndOrderFront(nil)
                                window.orderFrontRegardless()
                                break
                            }
                        }
                    }
                    .buttonStyle(.dodoPrimary)
                }
                .padding(Theme.Spacing.xl)
            } else {
                // Unlocked state - show quick search
                VStack(spacing: 0) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DodoColors.textSecondary)

                        TextField("", text: $searchQuery, prompt: Text("Search...").foregroundColor(DodoColors.textSecondary))
                            .textFieldStyle(.plain)
                            .font(DodoTypography.body)
                            .foregroundColor(DodoColors.textPrimary)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(DodoColors.backgroundTertiary)
                    .cornerRadius(Theme.Radius.sm)
                    .padding(Theme.Spacing.md)

                    // Quick access items
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredItems.prefix(10), id: \.id) { item in
                                MenuBarItemRow(item: item)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                    }

                    Divider()

                    // Footer actions
                    HStack {
                        Button("Lock") {
                            Task {
                                await vaultManager.lock()
                            }
                        }
                        .buttonStyle(.dodoSecondary)

                        Spacer()

                        Button("Open App") {
                            NSApp.activate(ignoringOtherApps: true)
                            // Find and show the main window
                            for window in NSApp.windows {
                                if window.canBecomeMain && !window.title.contains("Item") {
                                    window.makeKeyAndOrderFront(nil)
                                    window.orderFrontRegardless()
                                    break
                                }
                            }
                        }
                        .buttonStyle(.dodoSecondary)
                    }
                    .padding(Theme.Spacing.sm)
                }
            }
        }
        .frame(width: 320, height: 400)
        .background(DodoColors.background)
    }

    private var filteredItems: [any VaultItem] {
        if searchQuery.isEmpty {
            // Show favorites and recent items
            return Array(vaultManager.items.favorites.prefix(5)) +
                   Array(vaultManager.items.recentlyModified.prefix(5))
        } else {
            return SearchIndex.shared.search(query: searchQuery, limit: 10)
        }
    }
}

// MARK: - Menu Bar Item Row

struct MenuBarItemRow: View {
    let item: any VaultItem

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ItemIconView(icon: item.icon, category: item.category, size: .small)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(DodoTypography.bodySmall)
                    .foregroundColor(DodoColors.textPrimary)
                    .lineLimit(1)

                if let login = item as? LoginItem, !login.username.isEmpty {
                    Text(login.username)
                        .font(DodoTypography.caption)
                        .foregroundColor(DodoColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Quick copy button
            if let login = item as? LoginItem {
                Button {
                    ClipboardManager.shared.copyWithFeedback(login.password, label: "Password")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(DodoColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Copy password")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if let login = item as? LoginItem {
                ClipboardManager.shared.copyWithFeedback(login.password, label: "Password")
            }
        }
    }
}
