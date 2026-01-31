# DodoPass

A native macOS password manager built with SwiftUI, featuring local encryption with optional iCloud sync.

## Features

- 🔐 **AES-256-GCM encryption** with PBKDF2 key derivation (600,000 iterations)
- 🔑 **Touch ID unlock** for quick and secure access
- ☁️ **Optional iCloud sync** with conflict resolution
- 🌙 **Dark theme UI** inspired by modern password managers
- 🔍 **Fast search** with in-memory indexing
- 📋 **Smart clipboard** with automatic clearing
- 🔒 **Auto-lock** on screen lock, sleep, and inactivity
- 💻 **Menu bar companion** for quick access
- 🔑 **AutoFill extension** (scaffold) for browser integration

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Apple Developer account (for signing and iCloud)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/dodopass/dodopass.git
   cd dodopass
   ```

2. Open the project in Xcode:
   ```bash
   open DodoPass.xcodeproj
   ```

3. Configure signing:
   - Select the DodoPass target
   - Go to Signing & Capabilities
   - Select your development team
   - Update the bundle identifier if needed

4. Build and run:
   - Press ⌘R to build and run the app

## Project Structure

```
DodoPass/
├── DodoPass.xcodeproj/          # Xcode project
├── DodoPass/
│   ├── Sources/
│   │   ├── App/                 # App entry point, delegate, commands
│   │   ├── Domain/
│   │   │   ├── Models/          # Data models (VaultItem, LoginItem, etc.)
│   │   │   └── Services/        # Service protocols
│   │   ├── Data/
│   │   │   ├── Crypto/          # Encryption, key derivation
│   │   │   ├── Storage/         # File I/O, vault format
│   │   │   ├── Keychain/        # Keychain, biometrics
│   │   │   └── Sync/            # iCloud sync, conflict resolution
│   │   ├── UI/
│   │   │   ├── DesignSystem/    # Colors, typography, theme
│   │   │   ├── Components/      # Reusable UI components
│   │   │   ├── Screens/         # Main views
│   │   │   └── ViewModels/      # View state management
│   │   └── Managers/            # Singleton managers
│   └── Resources/               # Entitlements, Info.plist
├── AutoFillProvider/            # AutoFill extension
├── DodoPassTests/               # Unit tests
└── README.md
```

## Architecture

### Security Model

- **Zero-knowledge architecture**: Your master password never leaves your device
- **Key derivation**: PBKDF2-SHA256 with 600,000 iterations and 32-byte random salt
- **Encryption**: AES-256-GCM via Apple's CryptoKit
- **Key hierarchy**: Master key → HKDF → Purpose-specific keys (vault, search, backup)
- **Biometric storage**: Vault key stored in Keychain with `.biometryCurrentSet` protection

### Vault Format

Single encrypted file (`DodoPass.vaultdb`):
```
[4 bytes: magic "DODO"]
[4 bytes: format version]
[32 bytes: salt]
[32 bytes: encrypted verifier]
[variable: encrypted metadata JSON]
[variable: encrypted items blob]
[16 bytes: authentication tag]
```

### iCloud Sync

- Vault stored in `~/Library/Mobile Documents/iCloud~com~dodopass/Documents/`
- File coordination with `NSFileCoordinator` for atomic operations
- Conflict detection via modification timestamps and version vectors
- Resolution strategies: Last Write Wins, Keep Both

## Usage

### First Run

1. Launch DodoPass
2. Create a strong master password (minimum 8 characters recommended)
3. Optionally enable Touch ID and iCloud sync
4. Your vault is ready!

### Adding Items

- Press ⌘N for new login
- Press ⌘⇧N for new secure note
- Or use the + button in the toolbar

### Quick Switcher

Press ⌘K to open the quick switcher for fast item access.

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New login | ⌘N |
| New secure note | ⌘⇧N |
| Quick switcher | ⌘K |
| Find | ⌘F |
| Lock vault | ⌘⇧L |
| All items | ⌘1 |
| Favorites | ⌘2 |
| Logins | ⌘3 |
| Secure notes | ⌘4 |

## Development

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme DodoPass -destination 'platform=macOS'

# Or in Xcode
# Press ⌘U
```

### Code Style

- SwiftUI for all UI
- Swift concurrency (async/await) for async operations
- `@MainActor` for UI-bound classes
- Protocol-oriented design for testability

## Security Considerations

### What DodoPass Does

- Encrypts all vault data with AES-256-GCM
- Uses secure random number generation for all cryptographic operations
- Clears sensitive data from memory when locking
- Auto-clears clipboard after copying passwords
- Locks automatically on screen lock and sleep
- Never stores your master password

### What DodoPass Doesn't Do (v1)

- Hardware key (YubiKey) support
- Secure Enclave key storage
- Memory encryption / anti-debugging
- Two-factor authentication
- Password sharing / team features
- Browser extension (AutoFill is scaffold only)

## License

This project is provided for educational purposes. See LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## Acknowledgments

- Apple's CryptoKit for cryptographic primitives
- SwiftUI for the modern UI framework
- EFF's word list for passphrase generation

## Support

For issues and feature requests, please use the GitHub issue tracker.
