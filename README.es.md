<p align="center">
  <img src="icon.png" alt="DodoPass" width="128" height="128">
</p>

<h1 align="center">DodoPass</h1>

<p align="center">
  Un gestor de contraseñas nativo para macOS desarrollado con SwiftUI
  <br>
  <a href="#instalación">Instalación</a> •
  <a href="#características">Características</a> •
  <a href="#uso">Uso</a>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README.tr.md">Türkçe</a> •
  <a href="README.fr.md">Français</a> •
  <a href="README.es.md">Español</a> •
  <a href="README.de.md">Deutsch</a>
</p>

---

## Instalación

### Usando Homebrew (recomendado)

```bash
brew tap dodoapps/tap
brew install --cask dodopass
xattr -cr /Applications/DodoPass.app
```

### Instalación Manual

1. Descarga `DodoPass-1.0.0.dmg` desde la [página de versiones](https://github.com/DodoApps/dodopass/releases)
2. Abre el archivo DMG
3. Arrastra DodoPass a la carpeta Aplicaciones
4. Ejecuta el siguiente comando para eliminar la cuarentena:
   ```bash
   xattr -cr /Applications/DodoPass.app
   ```

### Compilar desde el Código Fuente

```bash
git clone https://github.com/DodoApps/dodopass.git
cd dodopass
open DodoPass.xcodeproj
```

## Características

- 🔐 **Cifrado AES-256-GCM** con derivación de clave PBKDF2 (600.000 iteraciones)
- 🔑 **Desbloqueo con Touch ID** para acceso rápido y seguro
- ☁️ **Sincronización opcional con iCloud** con resolución de conflictos
- 🌙 **Interfaz con tema oscuro** inspirada en gestores de contraseñas modernos
- 🔍 **Búsqueda rápida** con indexación en memoria
- 📋 **Portapapeles inteligente** con limpieza automática
- 🔒 **Bloqueo automático** al bloquear pantalla, suspender e inactividad
- 🌐 **Extensión de navegador** para Chrome, Brave y Edge
- 📤 **Importar/Exportar** formatos CSV, JSON y cifrados

## Requisitos

- macOS 14.0 (Sonoma) o posterior
- Mac con Apple Silicon o Intel

## Uso

### Primera Ejecución

1. Inicia DodoPass
2. Crea una contraseña maestra fuerte
3. Opcionalmente activa Touch ID y sincronización con iCloud
4. ¡Tu bóveda está lista!

### Atajos de Teclado

| Acción | Atajo |
|--------|-------|
| Nuevo inicio de sesión | ⌘N |
| Nueva nota segura | ⌘⇧N |
| Selector rápido | ⌘K |
| Buscar | ⌘F |
| Bloquear bóveda | ⌘⇧L |

## Seguridad

- **Arquitectura de conocimiento cero**: Tu contraseña maestra nunca sale de tu dispositivo
- **Derivación de clave**: PBKDF2-SHA256 con 600.000 iteraciones
- **Cifrado**: AES-256-GCM via Apple CryptoKit
- **Almacenamiento biométrico**: Clave de la bóveda almacenada en el Llavero con protección biométrica

## Licencia

Licencia MIT - Ver archivo LICENSE para más detalles.

## Soporte

Para problemas y solicitudes de funciones, usa el [rastreador de problemas de GitHub](https://github.com/DodoApps/dodopass/issues).
