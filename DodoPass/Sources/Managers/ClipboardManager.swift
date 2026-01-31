import AppKit
import Foundation

/// Manages clipboard operations with automatic clearing for sensitive data.
@MainActor
final class ClipboardManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ClipboardManager()

    // MARK: - Published State

    @Published private(set) var lastCopiedLabel: String?
    @Published private(set) var countdown: Int = 0

    // MARK: - Private State

    private var clearTimer: Timer?
    private var countdownTimer: Timer?
    private let pasteboard = NSPasteboard.general

    // Identifier for tracking our own clipboard writes
    private var clipboardChangeCount: Int = 0

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Copies a value to the clipboard.
    /// - Parameters:
    ///   - value: The string to copy
    ///   - clearAfter: Optional duration after which to clear the clipboard.
    ///                 Pass `nil` to disable auto-clear.
    ///                 Defaults to `CryptoConstants.clipboardClearTimeout`.
    ///   - label: Optional label for UI feedback (e.g., "Password")
    func copy(_ value: String, clearAfter: TimeInterval? = CryptoConstants.clipboardClearTimeout, label: String? = nil) {
        // Cancel any existing timers
        clearTimer?.invalidate()
        countdownTimer?.invalidate()
        clearTimer = nil
        countdownTimer = nil

        // Copy to clipboard
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        clipboardChangeCount = pasteboard.changeCount

        // Update UI
        lastCopiedLabel = label

        // Set up auto-clear if specified
        if let timeout = clearAfter, timeout > 0 {
            countdown = Int(timeout)
            startCountdown(timeout: timeout)
        } else {
            countdown = 0
        }

        // Provide haptic feedback (if available)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    /// Copies sensitive data that should be cleared quickly.
    func copySecure(_ value: String, label: String? = nil) {
        copy(value, clearAfter: CryptoConstants.clipboardClearTimeout, label: label)
    }

    /// Clears the clipboard immediately if we still own it.
    func clear() {
        clearTimer?.invalidate()
        countdownTimer?.invalidate()
        clearTimer = nil
        countdownTimer = nil

        // Only clear if the clipboard hasn't been changed by another app
        if pasteboard.changeCount == clipboardChangeCount {
            pasteboard.clearContents()
        }

        lastCopiedLabel = nil
        countdown = 0
    }

    // MARK: - Private Helpers

    private func startCountdown(timeout: TimeInterval) {
        // Update countdown every second
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.countdown > 0 {
                    self.countdown -= 1
                }
            }
        }

        // Clear after timeout
        clearTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clear()
            }
        }
    }
}

// MARK: - Clipboard Copy Action

extension ClipboardManager {
    /// Convenience method for copying with toast notification.
    func copyWithFeedback(_ value: String, label: String, isSecure: Bool = true) {
        copy(value, clearAfter: isSecure ? CryptoConstants.clipboardClearTimeout : nil, label: label)
        ToastManager.shared.show(message: "\(label) copied", type: .success)
    }
}
