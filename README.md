<p align="center">
  <img src="icon.png" alt="DodoPass" width="128" height="128">
</p>

<h1 align="center">DodoPass</h1>

<p align="center">
  A native macOS password manager built with SwiftUI
  <br>
  <a href="#installation">Installation</a> •
  <a href="#features">Features</a> •
  <a href="#usage">Usage</a> •
  <a href="#translations">Translations</a>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README.tr.md">Türkçe</a> •
  <a href="README.fr.md">Français</a> •
  <a href="README.es.md">Español</a> •
  <a href="README.de.md">Deutsch</a>
</p>

---

## Installation

### Using Homebrew (recommended)

```bash
brew tap dodoapps/tap
brew install --cask dodopass
xattr -cr /Applications/DodoPass.app
```

### Manual Installation

1. Download `DodoPass-1.0.0.dmg` from the [releases page](https://github.com/DodoApps/dodopass/releases)
2. Open the DMG file
3. Drag DodoPass to Applications folder
4. Run the following command to remove quarantine:
   ```bash
   xattr -cr /Applications/DodoPass.app
   ```

### Building from Source

```bash
git clone https://github.com/DodoApps/dodopass.git
cd dodopass
open DodoPass.xcodeproj
```

## Features

- 🔐 **AES-256-GCM encryption** with PBKDF2 key derivation (600,000 iterations)
- 🔑 **Touch ID unlock** for quick and secure access
- ☁️ **Optional iCloud sync** with conflict resolution
- 🌙 **Dark theme UI** inspired by modern password managers
- 🔍 **Fast search** with in-memory indexing
- 📋 **Smart clipboard** with automatic clearing
- 🔒 **Auto-lock** on screen lock, sleep, and inactivity
- 🌐 **Browser extension** for Chrome, Brave, and Edge
- 📤 **Import/Export** CSV, JSON, and encrypted formats

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

## Usage

### First Run

1. Launch DodoPass
2. Create a strong master password
3. Optionally enable Touch ID and iCloud sync
4. Your vault is ready!

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New login | ⌘N |
| New secure note | ⌘⇧N |
| Quick switcher | ⌘K |
| Find | ⌘F |
| Lock vault | ⌘⇧L |

## Security

- **Zero-knowledge architecture**: Your master password never leaves your device
- **Key derivation**: PBKDF2-SHA256 with 600,000 iterations
- **Encryption**: AES-256-GCM via Apple's CryptoKit
- **Biometric storage**: Vault key stored in Keychain with biometric protection

## License

MIT License - See LICENSE file for details.

## Support

For issues and feature requests, please use the [GitHub issue tracker](https://github.com/DodoApps/dodopass/issues).
