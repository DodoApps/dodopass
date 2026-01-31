<p align="center">
  <img src="icon.png" alt="DodoPass" width="128" height="128">
</p>

<h1 align="center">DodoPass</h1>

<p align="center">
  Un gestionnaire de mots de passe natif pour macOS développé avec SwiftUI
  <br>
  <a href="#installation">Installation</a> •
  <a href="#fonctionnalités">Fonctionnalités</a> •
  <a href="#utilisation">Utilisation</a>
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

### Avec Homebrew (recommandé)

```bash
brew tap dodoapps/tap
brew install --cask dodopass
xattr -cr /Applications/DodoPass.app
```

### Installation Manuelle

1. Téléchargez `DodoPass-1.0.0.dmg` depuis la [page des versions](https://github.com/DodoApps/dodopass/releases)
2. Ouvrez le fichier DMG
3. Glissez DodoPass dans le dossier Applications
4. Exécutez la commande suivante pour supprimer la quarantaine :
   ```bash
   xattr -cr /Applications/DodoPass.app
   ```

### Compilation depuis les Sources

```bash
git clone https://github.com/DodoApps/dodopass.git
cd dodopass
open DodoPass.xcodeproj
```

## Fonctionnalités

- 🔐 **Chiffrement AES-256-GCM** avec dérivation de clé PBKDF2 (600 000 itérations)
- 🔑 **Déverrouillage Touch ID** pour un accès rapide et sécurisé
- ☁️ **Synchronisation iCloud optionnelle** avec résolution des conflits
- 🌙 **Interface thème sombre** inspirée des gestionnaires de mots de passe modernes
- 🔍 **Recherche rapide** avec indexation en mémoire
- 📋 **Presse-papiers intelligent** avec effacement automatique
- 🔒 **Verrouillage automatique** lors du verrouillage de l'écran, de la mise en veille et de l'inactivité
- 🌐 **Extension de navigateur** pour Chrome, Brave et Edge
- 📤 **Import/Export** formats CSV, JSON et chiffrés

## Configuration Requise

- macOS 14.0 (Sonoma) ou ultérieur
- Mac Apple Silicon ou Intel

## Utilisation

### Premier Lancement

1. Lancez DodoPass
2. Créez un mot de passe principal fort
3. Activez optionnellement Touch ID et la synchronisation iCloud
4. Votre coffre-fort est prêt !

### Raccourcis Clavier

| Action | Raccourci |
|--------|-----------|
| Nouvelle connexion | ⌘N |
| Nouvelle note sécurisée | ⌘⇧N |
| Sélecteur rapide | ⌘K |
| Rechercher | ⌘F |
| Verrouiller le coffre | ⌘⇧L |

## Sécurité

- **Architecture à connaissance nulle** : Votre mot de passe principal ne quitte jamais votre appareil
- **Dérivation de clé** : PBKDF2-SHA256 avec 600 000 itérations
- **Chiffrement** : AES-256-GCM via Apple CryptoKit
- **Stockage biométrique** : Clé du coffre stockée dans le Trousseau avec protection biométrique

## Licence

Licence MIT - Voir le fichier LICENSE pour plus de détails.

## Support

Pour les problèmes et les demandes de fonctionnalités, utilisez le [système de suivi GitHub](https://github.com/DodoApps/dodopass/issues).
