<p align="center">
  <img src="icon.png" alt="DodoPass" width="128" height="128">
</p>

<h1 align="center">DodoPass</h1>

<p align="center">
  Ein nativer macOS-Passwortmanager entwickelt mit SwiftUI
  <br>
  <a href="#installation">Installation</a> •
  <a href="#funktionen">Funktionen</a> •
  <a href="#verwendung">Verwendung</a>
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

### Mit Homebrew (empfohlen)

```bash
brew tap dodoapps/tap
brew install --cask dodopass
xattr -cr /Applications/DodoPass.app
```

### Manuelle Installation

1. Laden Sie `DodoPass-1.0.0.dmg` von der [Releases-Seite](https://github.com/DodoApps/dodopass/releases) herunter
2. Öffnen Sie die DMG-Datei
3. Ziehen Sie DodoPass in den Programme-Ordner
4. Führen Sie folgenden Befehl aus, um die Quarantäne zu entfernen:
   ```bash
   xattr -cr /Applications/DodoPass.app
   ```

### Aus dem Quellcode Kompilieren

```bash
git clone https://github.com/DodoApps/dodopass.git
cd dodopass
open DodoPass.xcodeproj
```

## Funktionen

- 🔐 **AES-256-GCM-Verschlüsselung** mit PBKDF2-Schlüsselableitung (600.000 Iterationen)
- 🔑 **Touch ID-Entsperrung** für schnellen und sicheren Zugriff
- ☁️ **Optionale iCloud-Synchronisation** mit Konfliktlösung
- 🌙 **Dunkles Design** inspiriert von modernen Passwortmanagern
- 🔍 **Schnelle Suche** mit In-Memory-Indizierung
- 📋 **Intelligente Zwischenablage** mit automatischer Löschung
- 🔒 **Automatische Sperrung** bei Bildschirmsperre, Ruhezustand und Inaktivität
- 🌐 **Browser-Erweiterung** für Chrome, Brave und Edge
- 📤 **Import/Export** CSV-, JSON- und verschlüsselte Formate

## Voraussetzungen

- macOS 14.0 (Sonoma) oder neuer
- Apple Silicon oder Intel Mac

## Verwendung

### Erster Start

1. Starten Sie DodoPass
2. Erstellen Sie ein starkes Master-Passwort
3. Aktivieren Sie optional Touch ID und iCloud-Synchronisation
4. Ihr Tresor ist bereit!

### Tastenkürzel

| Aktion | Tastenkürzel |
|--------|--------------|
| Neuer Login | ⌘N |
| Neue sichere Notiz | ⌘⇧N |
| Schnellauswahl | ⌘K |
| Suchen | ⌘F |
| Tresor sperren | ⌘⇧L |

## Sicherheit

- **Zero-Knowledge-Architektur**: Ihr Master-Passwort verlässt niemals Ihr Gerät
- **Schlüsselableitung**: PBKDF2-SHA256 mit 600.000 Iterationen
- **Verschlüsselung**: AES-256-GCM über Apple CryptoKit
- **Biometrische Speicherung**: Tresorschlüssel im Schlüsselbund mit biometrischem Schutz gespeichert

## Lizenz

MIT-Lizenz - Siehe LICENSE-Datei für Details.

## Support

Für Probleme und Funktionsanfragen nutzen Sie bitte den [GitHub Issue Tracker](https://github.com/DodoApps/dodopass/issues).
