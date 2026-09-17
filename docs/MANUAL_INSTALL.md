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
- [ ] **CrystalFetch** - Descarga de archivos ISO

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
- [ ] **Handy** - <https://handy.computer>

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
- [ ] **Arduino IDE** - <https://www.arduino.cc/en/software>
- [ ] **Unity Hub** - <https://unity.com/download>

### IA & Coding Agents

- [ ] **LM Studio** - <https://lmstudio.ai>

### Browsers

- [ ] **Google Chrome** - <https://www.google.com/chrome>
- [ ] **Firefox** - <https://www.mozilla.org/en-US/firefox/new>

### Productividad

- [ ] **Raycast** - <https://www.raycast.com>
- [ ] **Obsidian** - <https://obsidian.md/download>
- [ ] **Spotify** - <https://open.spotify.com/download>
- [ ] **Discord** - <https://discord.com/download>
- [ ] **Teams** - <https://www.microsoft.com/en-us/microsoft-teams/download-app>

### Media & Content

- [ ] **IINA** - <https://iina.io>
- [ ] **Affinity** - <https://www.affinity.studio>
- [ ] **qBittorrent** - <https://www.qbittorrent.org/download.php>
- [ ] **4k Video Downloader+** - <https://www.4kdownload.com/downloads/34>
- [ ] **Audacity** - <https://www.audacityteam.org/download/mac>
- [ ] **OBS Studio** - <https://obsproject.com/download>
- [ ] **Blender** - <https://www.blender.org/download>

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
npm config set min-release-age 3
npm install --global --ignore-scripts @fission-ai/openspec@latest
npm install --global --ignore-scripts vercel@latest
npm install --global --ignore-scripts @playwright/cli@latest
```

### Python (con pyenv)

```bash
pyenv install 3.11.16
pyenv global 3.11.16
```

### instalar Sail

```bash
php artisan sail:install
```

### Gentle-AI

```bash
# Runtimes sin config propia en este repo:
gentle-ai install \
  --scope global \
  --preset full-gentleman \
  --persona gentleman \
  --agents opencode,cursor,codex,antigravity,vscode-copilot,kilocode

# Claude Code: correr DESPUÉS de ./install.sh, para que la capa de gentle-ai
# quede sobre la base versionada por este repo. El instalador la re-sincroniza
# en cada corrida con `gentle-ai sync --agent claude-code`.
gentle-ai install --agent claude-code
```

### Settings Apps

```bash
vercel login
gh auth login
engram cloud status   # verificar la sincronización de la memoria cloud
```

---
