import Foundation
import LocalAuthentication

/// Service for handling biometric authentication (Touch ID).
final class BiometricAuth {
    // MARK: - Errors

    enum BiometricError: LocalizedError {
        case notAvailable
        case notEnrolled
        case cancelled
        case failed(underlying: Error?)
        case lockout
        case passcodeNotSet

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Biometric authentication is not available on this device"
            case .notEnrolled:
                return "No biometric data enrolled. Please set up Touch ID in System Settings"
            case .cancelled:
                return "Authentication was cancelled"
            case .failed(let error):
                return "Authentication failed: \(error?.localizedDescription ?? "Unknown error")"
            case .lockout:
                return "Too many failed attempts. Please try again later"
            case .passcodeNotSet:
                return "Device passcode is not set"
            }
        }
    }

    // MARK: - Properties

    private let context: LAContext

    /// The type of biometrics available on this device.
    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// A human-readable name for the biometry type.
    var biometryTypeName: String {
        switch biometryType {
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometrics"
        @unknown default:
            return "Biometrics"
        }
    }

    /// Whether biometric authentication is available.
    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return available
    }

    /// Whether biometric authentication is enrolled.
    var isEnrolled: Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if let error = error {
            switch error.code {
            case LAError.biometryNotEnrolled.rawValue:
                return false
            default:
                break
            }
        }

        return canEvaluate
    }

    // MARK: - Initialization

    init() {
        self.context = LAContext()
    }

    // MARK: - Authentication

    /// Authenticates the user with biometrics.
    /// - Parameter reason: The reason shown to the user.
    /// - Throws: `BiometricError` if authentication fails.
    func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter password"
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw mapError(error)
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                AuditLogger.shared.log("Biometric authentication successful", category: .auth)
            } else {
                throw BiometricError.failed(underlying: nil)
            }
        } catch let error as LAError {
            throw mapLAError(error)
        } catch let error as BiometricError {
            throw error
        } catch {
            throw BiometricError.failed(underlying: error)
        }
    }

    /// Authenticates the user with biometrics or device passcode.
    /// - Parameter reason: The reason shown to the user.
    /// - Throws: `BiometricError` if authentication fails.
    func authenticateWithFallback(reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "Use passcode"
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw mapError(error)
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            if success {
                AuditLogger.shared.log("Device authentication successful", category: .auth)
            } else {
                throw BiometricError.failed(underlying: nil)
            }
        } catch let error as LAError {
            throw mapLAError(error)
        } catch let error as BiometricError {
            throw error
        } catch {
            throw BiometricError.failed(underlying: error)
        }
    }

    /// Invalidates the current authentication context.
    func invalidate() {
        context.invalidate()
    }

    // MARK: - Error Mapping

    private func mapError(_ error: NSError?) -> BiometricError {
        guard let error = error else {
            return .notAvailable
        }

        switch error.code {
        case LAError.biometryNotAvailable.rawValue:
            return .notAvailable
        case LAError.biometryNotEnrolled.rawValue:
            return .notEnrolled
        case LAError.passcodeNotSet.rawValue:
            return .passcodeNotSet
        case LAError.biometryLockout.rawValue:
            return .lockout
        default:
            return .failed(underlying: error)
        }
    }

    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryLockout:
            return .lockout
        case .userCancel, .appCancel, .systemCancel:
            return .cancelled
        case .authenticationFailed:
            return .failed(underlying: error)
        default:
            return .failed(underlying: error)
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension BiometricAuth {
    /// Creates a mock BiometricAuth for previews.
    static var preview: BiometricAuth {
        BiometricAuth()
    }
}
#endif
