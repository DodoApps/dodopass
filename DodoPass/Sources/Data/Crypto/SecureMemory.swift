import Foundation
import CryptoKit

/// Utilities for secure memory handling.
enum SecureMemory {
    /// Securely wipes the contents of a Data object by overwriting with zeros.
    /// Note: Swift's Data is a value type and may have copies, so this is best-effort.
    /// - Parameter data: The data to wipe.
    static func wipe(_ data: inout Data) {
        data.withUnsafeMutableBytes { buffer in
            if let baseAddress = buffer.baseAddress {
                memset(baseAddress, 0, buffer.count)
            }
        }
        data = Data()
    }

    /// Securely wipes the contents of an array by overwriting with zeros.
    /// - Parameter array: The array to wipe.
    static func wipe(_ array: inout [UInt8]) {
        for i in 0..<array.count {
            array[i] = 0
        }
        array.removeAll()
    }

    /// Securely wipes a string by clearing its underlying storage.
    /// Note: This is best-effort due to Swift string internals and possible interning.
    /// - Parameter string: The string to wipe.
    static func wipe(_ string: inout String) {
        string = String(repeating: "\0", count: string.count)
        string = ""
    }
}

// MARK: - Secure Data Wrapper

/// A wrapper that automatically wipes data when deallocated.
/// Use this for sensitive data that should not persist in memory.
final class SecureData {
    private var _data: Data

    var data: Data {
        _data
    }

    var count: Int {
        _data.count
    }

    var isEmpty: Bool {
        _data.isEmpty
    }

    init(_ data: Data) {
        self._data = data
    }

    init(count: Int) {
        self._data = Data(count: count)
    }

    deinit {
        SecureMemory.wipe(&_data)
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try _data.withUnsafeBytes(body)
    }

    func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        try _data.withUnsafeMutableBytes(body)
    }
}

// MARK: - Secure Key Wrapper

/// A wrapper for SymmetricKey that attempts to clear memory on deallocation.
final class SecureKey {
    private var _key: SymmetricKey?

    var key: SymmetricKey? {
        _key
    }

    var isValid: Bool {
        _key != nil
    }

    init(_ key: SymmetricKey) {
        self._key = key
    }

    /// Invalidates and clears the key.
    func clear() {
        _key = nil
    }

    deinit {
        clear()
    }
}

// MARK: - Memory Lock (macOS)

#if os(macOS)
import Darwin

extension SecureMemory {
    /// Attempts to lock memory pages to prevent swapping.
    /// This is a best-effort security measure.
    /// - Parameter data: The data whose underlying memory should be locked.
    /// - Returns: true if successful, false otherwise.
    @discardableResult
    static func lockMemory(_ data: inout Data) -> Bool {
        return data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            return mlock(baseAddress, buffer.count) == 0
        }
    }

    /// Unlocks previously locked memory pages.
    /// - Parameter data: The data whose underlying memory should be unlocked.
    /// - Returns: true if successful, false otherwise.
    @discardableResult
    static func unlockMemory(_ data: inout Data) -> Bool {
        return data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            return munlock(baseAddress, buffer.count) == 0
        }
    }
}
#endif
