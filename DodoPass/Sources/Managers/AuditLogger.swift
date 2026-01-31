import Foundation
import os.log

/// Non-sensitive audit logging for security events.
/// Never logs secrets, passwords, or personal data.
final class AuditLogger: Sendable {
    // MARK: - Singleton

    static let shared = AuditLogger()

    // MARK: - Types

    enum Category: String, Sendable {
        case vault = "Vault"
        case auth = "Authentication"
        case sync = "Sync"
        case security = "Security"
        case app = "Application"
    }

    enum Level: String, Sendable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }

    struct LogEntry: Codable, Sendable {
        let timestamp: Date
        let category: String
        let level: String
        let message: String
        let metadata: [String: String]?
    }

    // MARK: - Private State

    private let logger = Logger(subsystem: "com.dodopass", category: "Audit")
    private let logQueue = DispatchQueue(label: "com.dodopass.auditlog", qos: .utility)
    private let maxLogEntries = 1000
    private var recentLogs: [LogEntry] = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Log a message with optional metadata.
    func log(
        _ message: String,
        category: Category = .app,
        level: Level = .info,
        metadata: [String: String]? = nil
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            category: category.rawValue,
            level: level.rawValue,
            message: message,
            metadata: metadata
        )

        // Log to system console
        logger.log(level: level.osLogType, "[\(category.rawValue)] \(message)")

        // Store recent logs
        logQueue.async { [weak self] in
            self?.storeEntry(entry)
        }
    }

    // MARK: - Convenience Methods

    func vaultUnlocked() {
        log("Vault unlocked", category: .vault, level: .info)
    }

    func vaultLocked() {
        log("Vault locked", category: .vault, level: .info)
    }

    func vaultCreated() {
        log("New vault created", category: .vault, level: .info)
    }

    func itemAdded(category: ItemCategory) {
        log("Item added", category: .vault, level: .info, metadata: ["type": category.rawValue])
    }

    func itemUpdated(category: ItemCategory) {
        log("Item updated", category: .vault, level: .info, metadata: ["type": category.rawValue])
    }

    func itemDeleted(category: ItemCategory) {
        log("Item deleted", category: .vault, level: .info, metadata: ["type": category.rawValue])
    }

    func authenticationFailed(method: String) {
        log("Authentication failed", category: .auth, level: .warning, metadata: ["method": method])
    }

    func authenticationSucceeded(method: String) {
        log("Authentication succeeded", category: .auth, level: .info, metadata: ["method": method])
    }

    func biometricEnrolled() {
        log("Biometric authentication enrolled", category: .auth, level: .info)
    }

    func syncStarted() {
        log("Sync started", category: .sync, level: .info)
    }

    func syncCompleted() {
        log("Sync completed", category: .sync, level: .info)
    }

    func syncFailed(error: String) {
        log("Sync failed", category: .sync, level: .error, metadata: ["error": error])
    }

    func conflictDetected() {
        log("Sync conflict detected", category: .sync, level: .warning)
    }

    func conflictResolved(resolution: String) {
        log("Sync conflict resolved", category: .sync, level: .info, metadata: ["resolution": resolution])
    }

    func backupCreated() {
        log("Backup created", category: .vault, level: .info)
    }

    func backupRestored() {
        log("Backup restored", category: .vault, level: .info)
    }

    func passwordChanged() {
        log("Master password changed", category: .security, level: .info)
    }

    func clipboardCopied(fieldType: String) {
        log("Value copied to clipboard", category: .security, level: .debug, metadata: ["field": fieldType])
    }

    func clipboardCleared() {
        log("Clipboard cleared", category: .security, level: .debug)
    }

    func autoLockTriggered(reason: String) {
        log("Auto-lock triggered", category: .security, level: .info, metadata: ["reason": reason])
    }

    func appLaunched() {
        log("Application launched", category: .app, level: .info)
    }

    func appTerminated() {
        log("Application terminated", category: .app, level: .info)
    }

    // MARK: - Export

    /// Export recent logs for debugging (excludes sensitive data).
    func exportLogs() -> String {
        var output = "DodoPass Audit Log\n"
        output += "==================\n\n"

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        var entries: [LogEntry] = []
        logQueue.sync {
            entries = self.recentLogs
        }

        for entry in entries {
            output += "[\(formatter.string(from: entry.timestamp))] "
            output += "[\(entry.level)] "
            output += "[\(entry.category)] "
            output += entry.message

            if let metadata = entry.metadata, !metadata.isEmpty {
                let metaString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                output += " (\(metaString))"
            }

            output += "\n"
        }

        return output
    }

    /// Clear all stored logs.
    func clearLogs() {
        logQueue.async { [weak self] in
            self?.recentLogs.removeAll()
        }
    }

    // MARK: - Private Helpers

    private func storeEntry(_ entry: LogEntry) {
        recentLogs.append(entry)

        // Trim if exceeds max
        if recentLogs.count > maxLogEntries {
            recentLogs.removeFirst(recentLogs.count - maxLogEntries)
        }
    }
}
