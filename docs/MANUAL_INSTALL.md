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
- [ ] **DaVinci Resolve** - Edición de video profesional
- [ ] **The Unarchiver** - Descompresor de archivos
- [ ] **1Blocker** - Bloqueador de anuncios y rastreadores
- [ ] **TestFlight** - App para probar nuevas versiones de aplicaciones
- [ ] **Apple Developer** - App para desarrolladores de Apple

---

## 🌐 Instalación Externa

### Drivers & Hardware

- [ ] **Epson L3210 Drivers** - <https://epson.com/Support/Printers>
- [ ] **Logi Options+** - <https://support.logi.com/hc/es-ar/articles/31605553077783-Descargas-MX-Master-3S-BT-Edition>
- [ ] **Stream Deck** - <https://www.elgato.com/lm/es/s/downloads>
- [ ] **Nextcloud** - <https://nextcloud.com/install/#desktop-files>
- [ ] **Drive** - <https://workspace.google.com/products/drive>
- [ ] **Dropbox** - <https://www.dropbox.com/install>

### Herramientas Especiales

- [ ] **AlDente** - <https://apphousekitchen.com/aldente-overview>
- [ ] **Parsec** - <https://parsecgaming.com/downloads>
- [ ] **AppCleaner** - <https://freemacsoft.net/appcleaner>
- [ ] **Bartender** - <https://www.macbartender.com>
- [ ] **CodexBar** - <https://codexbar.app>
- [ ] **Flow** - <https://wisprflow.ai>

### Terminal & Development

- [ ] **Ghostty** - <https://ghostty.org/download>
- [ ] **Visual Studio Code** - <https://code.visualstudio.com>
- [ ] **OrbStack** - <https://orbstack.dev/download>
- [ ] **Android Studio** - <https://developer.android.com/studio>
- [ ] **TablePlus** - <https://tableplus.com>
- [ ] **Tiny Shield** - <https://tinyshield.proxyman.com>
- [ ] **Bruno** - <https://www.usebruno.com/downloads>
- [ ] **Laravel Herd** - <https://herd.laravel.com>
- [ ] **Cyberduck** - <https://cyberduck.io/download>
- [ ] **VMware Fusion** - <https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion>
- [ ] **Ollama** - <https://ollama.com/download/mac>

### IA & Coding Agents

- [ ] **Claude** - <https://claude.ai/api/desktop/darwin/universal/dmg/latest/redirect>

### Browsers

- [ ] **Google Chrome** - <https://www.google.com/chrome>
- [ ] **Zen** - <https://zen-browser.app/download>

### Productividad

- [ ] **Raycast** - <https://www.raycast.com>
- [ ] **Obsidian** - <https://obsidian.md/download>
- [ ] **Spotify** - <https://open.spotify.com/download>

### Media & Content

- [ ] **IINA** - <https://iina.io>
- [ ] **Affinity** - <https://www.affinity.studio>
- [ ] **qBittorrent** - <https://www.qbittorrent.org/download.php>
- [ ] **4k Video Downloader+** - <https://www.4kdownload.com/downloads/34>
- [ ] **Audacity** - <https://www.audacityteam.org/download/mac>
- [ ] **Meld Studio** - <https://meldstudio.co/download>

---

## ⚙️ Configuraciones Post-Instalación

### Node.js (con nvm)

```bash
nvm install 24
nvm install 22
nvm use 24
nvm alias default 24
corepack enable pnpm
pnpm --version
npm config set ignore-scripts true
npm config set allow-git none
npm config set min-release-age 3
npm install -g @fission-ai/openspec@latest
npm i -g vercel
npm install -g @playwright/cli@latest
```

### Python (con pyenv)

```bash
pyenv install 3.14.7
pyenv install 3.11.1
pyenv global 3.14.7
```

### instalar Sail

```bash
php artisan sail:install
```

### Configuracion de herdr

```bash
herdr integration install codex
herdr integration install claude
herdr integration install opencode
herdr integration install cursor
herdr integration install antigravity
herdr integration install copilot
herdr integration install kilo
```

### Gentle-AI

```bash
gentle-ai install \
  --scope global \
  --preset full-gentleman \
  --persona gentleman \
  --agents opencode,cursor,codex,antigravity,vscode-copilot,kilocode
```

---
