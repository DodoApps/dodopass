import AuthenticationServices
import os.log

/// Credential provider view controller for AutoFill extension.
class CredentialProviderViewController: ASCredentialProviderViewController {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.dodopass.autofill", category: "CredentialProvider")

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    // MARK: - Credential Provider Methods

    /// Called when the user selects a credential from the QuickType bar.
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        logger.info("provideCredentialWithoutUserInteraction called")

        // Check if we can provide credentials without user interaction
        // This requires the vault to be unlocked and the key available
        guard let credential = fetchCredential(for: credentialIdentity) else {
            // Need user interaction to unlock
            extensionContext.cancelRequest(withError: NSError(
                domain: ASExtensionErrorDomain,
                code: ASExtensionError.userInteractionRequired.rawValue
            ))
            return
        }

        // Provide the credential
        extensionContext.completeRequest(withSelectedCredential: credential)
    }

    /// Called when user interaction is needed to provide credentials.
    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        logger.info("prepareInterfaceToProvideCredential called")

        // Show unlock UI if needed
        showUnlockInterface { [weak self] unlocked in
            if unlocked {
                if let credential = self?.fetchCredential(for: credentialIdentity) {
                    self?.extensionContext.completeRequest(withSelectedCredential: credential)
                } else {
                    self?.extensionContext.cancelRequest(withError: NSError(
                        domain: ASExtensionErrorDomain,
                        code: ASExtensionError.credentialIdentityNotFound.rawValue
                    ))
                }
            } else {
                self?.extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userCanceled.rawValue
                ))
            }
        }
    }

    /// Called to prepare the credential list UI.
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        logger.info("prepareCredentialList called for \(serviceIdentifiers.count) services")

        // Show the credential picker UI
        showCredentialPicker(for: serviceIdentifiers)
    }

    /// Called to prepare the interface for extension configuration.
    override func prepareInterfaceForExtensionConfiguration() {
        logger.info("prepareInterfaceForExtensionConfiguration called")

        // Show configuration UI
        showConfigurationInterface()
    }

    // MARK: - Private Methods

    private func fetchCredential(for identity: ASPasswordCredentialIdentity) -> ASPasswordCredential? {
        // TODO: Implement credential fetching from shared vault
        // This would:
        // 1. Access the shared Keychain to get the vault key
        // 2. Load and decrypt the vault
        // 3. Find the matching credential
        // 4. Return it

        // For now, return nil to indicate we need user interaction
        return nil
    }

    private func showUnlockInterface(completion: @escaping (Bool) -> Void) {
        // TODO: Implement unlock UI
        // This would show a password/Touch ID prompt

        // Create unlock view
        let unlockView = AutoFillUnlockView { success in
            completion(success)
        }

        // Add to view hierarchy
        let hostingView = NSHostingView(rootView: unlockView)
        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        view.addSubview(hostingView)
    }

    private func showCredentialPicker(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // TODO: Implement credential picker UI
        // This would:
        // 1. Load matching credentials for the service identifiers
        // 2. Display them in a list
        // 3. Let user select one

        let pickerView = AutoFillCredentialPickerView(
            serviceIdentifiers: serviceIdentifiers,
            onSelect: { [weak self] credential in
                self?.extensionContext.completeRequest(withSelectedCredential: credential)
            },
            onCancel: { [weak self] in
                self?.extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userCanceled.rawValue
                ))
            }
        )

        let hostingView = NSHostingView(rootView: pickerView)
        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        view.addSubview(hostingView)
    }

    private func showConfigurationInterface() {
        // TODO: Implement configuration UI
        // This would allow users to configure the extension

        let configView = AutoFillConfigurationView {
            // Configuration complete
        }

        let hostingView = NSHostingView(rootView: configView)
        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        view.addSubview(hostingView)
    }
}

// MARK: - SwiftUI Import

import SwiftUI
