# 📱 Instalación Manual

Apps que deben instalarse manualmente desde la App Store o fuentes externas.

## 🍎 App Store

Estas apps se instalan desde la App Store de macOS:

### Productivity

- [ ] **Xcode** - IDE de Apple
- [ ] **Microsoft Office Suite**:
  - [ ] Outlook
  - [ ] PowerPoint
  - [ ] Word
  - [ ] Excel
  - [ ] OneDrive
- [ ] **Tailscale** - VPN fácil de usar
- [ ] **PPTControl Desktop** - Control remoto para PowerPoint
- [ ] **Dark Reader** - Modo oscuro para sitios web

### Utilities

- [ ] **CleanMyMac** - Limpieza del sistema
- [ ] **The Unarchiver** - Descompresor de archivos
- [ ] **uBlock Origin Lite** - Bloqueador de anuncios y rastreadores

---

## 🌐 Instalación Externa

### Drivers & Hardware

- [ ] **Logi Options+** - <https://support.logi.com/hc/es-ar/articles/31605553077783-Descargas-MX-Master-3S-BT-Edition>

### Herramientas Especiales

- [ ] **AlDente** - <https://apphousekitchen.com/aldente-overview>
- [ ] **Parsec** - <https://parsecgaming.com/downloads>
- [ ] **Bartender** - <https://www.macbartender.com>
- [ ] **CodexBar** - <https://codexbar.app>

### Terminal & Development

- [ ] **Ghostty** - <https://ghostty.org/download>
- [ ] **Visual Studio Code** - <https://code.visualstudio.com>
- [ ] **OrbStack** - <https://orbstack.dev/download>
- [ ] **Android Studio** - <https://developer.android.com/studio>
- [ ] **TablePlus** - <https://tableplus.com>
- [ ] **Tiny Shield** - <https://tinyshield.proxyman.com>
- [ ] **Laravel Herd** - <https://herd.laravel.com>

### Browsers

- [ ] **Google Chrome** - <https://www.google.com/chrome>

### Productividad

- [ ] **Raycast** - <https://www.raycast.com>
- [ ] **Spotify** - <https://open.spotify.com/download>
- [ ] **Vesktop** - <https://github.com/Vencord/Vesktop> (cliente Discord alternativo)
- [ ] **Teams** - <https://www.microsoft.com/en-us/microsoft-teams/download-app>

### Media & Content

- [ ] **IINA** - <https://iina.io>
- [ ] **OBS Studio** - <https://obsproject.com/download>

---

## ⚙️ Configuraciones Post-Instalación

### Node.js (con Laravel Herd)

```bash
nvm install 22
nvm install 24
node --version
npm --version
corepack enable pnpm
pnpm --version
npm config set ignore-scripts true
npm config set allow-git none
pnpm add --global --ignore-scripts vercel@59.25.4
pnpm add --global --ignore-scripts @playwright/cli@0.1.21
```

### Python (con pyenv)

```bash
pyenv install 3.13.17
pyenv install 3.11.16
pyenv global 3.11.16
pyenv exec python -m pip install -r config/claude/agent-tools/requirements.txt
```

### instalar Sail

```bash
php artisan sail:install
```

### Simuladores y emuladores

**iOS, watchOS y tvOS** (Xcode instalado desde App Store):

- Xcode > Settings > Platforms: instalar el runtime de iOS.
- Alternativa desde terminal: `xcodebuild -downloadPlatform iOS` (descarga pesada).
- Verificar: `xcrun simctl list runtimes`.

**Android** (Android Studio instalado):

- Android Studio > Settings > Languages & Frameworks > Android SDK: instalar SDK Platform, Build-Tools, Platform-Tools y Emulator.
- Device Manager: crear un AVD.
- `ANDROID_HOME` apunta a `~/Library/Android/sdk` (ver `.zshenv`).
- Verificar: `emulator -list-avds`.

### Herdr

```bash
herdr plugin install smarzban/herdr-file-viewer --yes
herdr plugin install persiyanov/herdr-reviewr --yes
herdr integration install codex
herdr integration install claude
herdr integration install opencode
herdr integration install antigravity-cli
herdr integration install copilot
```

### Settings Apps

```bash
vercel login
gh auth login
```

---
