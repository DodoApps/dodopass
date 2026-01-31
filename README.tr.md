<p align="center">
  <img src="icon.png" alt="DodoPass" width="128" height="128">
</p>

<h1 align="center">DodoPass</h1>

<p align="center">
  SwiftUI ile geliştirilmiş yerel macOS şifre yöneticisi
  <br>
  <a href="#kurulum">Kurulum</a> •
  <a href="#özellikler">Özellikler</a> •
  <a href="#kullanım">Kullanım</a>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README.tr.md">Türkçe</a> •
  <a href="README.fr.md">Français</a> •
  <a href="README.es.md">Español</a> •
  <a href="README.de.md">Deutsch</a>
</p>

---

## Kurulum

### Homebrew ile (önerilen)

```bash
brew tap dodoapps/tap
brew install --cask dodopass
xattr -cr /Applications/DodoPass.app
```

### Manuel Kurulum

1. [Sürümler sayfasından](https://github.com/DodoApps/dodopass/releases) `DodoPass-1.0.0.dmg` dosyasını indirin
2. DMG dosyasını açın
3. DodoPass'ı Uygulamalar klasörüne sürükleyin
4. Karantinayı kaldırmak için aşağıdaki komutu çalıştırın:
   ```bash
   xattr -cr /Applications/DodoPass.app
   ```

### Kaynak Koddan Derleme

```bash
git clone https://github.com/DodoApps/dodopass.git
cd dodopass
open DodoPass.xcodeproj
```

## Özellikler

- 🔐 **AES-256-GCM şifreleme** ve PBKDF2 anahtar türetme (600.000 iterasyon)
- 🔑 **Touch ID ile kilit açma** hızlı ve güvenli erişim için
- ☁️ **İsteğe bağlı iCloud senkronizasyonu** çakışma çözümlemesi ile
- 🌙 **Koyu tema arayüzü** modern şifre yöneticilerinden ilham alınmış
- 🔍 **Hızlı arama** bellek içi indeksleme ile
- 📋 **Akıllı pano** otomatik temizleme ile
- 🔒 **Otomatik kilitleme** ekran kilidi, uyku ve hareketsizlikte
- 🌐 **Tarayıcı eklentisi** Chrome, Brave ve Edge için
- 📤 **İçe/Dışa aktarma** CSV, JSON ve şifreli formatlar

## Gereksinimler

- macOS 14.0 (Sonoma) veya üstü
- Apple Silicon veya Intel Mac

## Kullanım

### İlk Çalıştırma

1. DodoPass'ı başlatın
2. Güçlü bir ana şifre oluşturun
3. İsteğe bağlı olarak Touch ID ve iCloud senkronizasyonunu etkinleştirin
4. Kasanız hazır!

### Klavye Kısayolları

| İşlem | Kısayol |
|-------|---------|
| Yeni giriş | ⌘N |
| Yeni güvenli not | ⌘⇧N |
| Hızlı geçiş | ⌘K |
| Bul | ⌘F |
| Kasayı kilitle | ⌘⇧L |

## Güvenlik

- **Sıfır bilgi mimarisi**: Ana şifreniz cihazınızdan asla çıkmaz
- **Anahtar türetme**: 600.000 iterasyonlu PBKDF2-SHA256
- **Şifreleme**: Apple CryptoKit ile AES-256-GCM
- **Biyometrik depolama**: Kasa anahtarı biyometrik koruma ile Anahtar Zinciri'nde saklanır

## Lisans

MIT Lisansı - Detaylar için LICENSE dosyasına bakın.

## Destek

Sorunlar ve özellik istekleri için [GitHub sorun takipçisini](https://github.com/DodoApps/dodopass/issues) kullanın.
