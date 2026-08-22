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

- [ ] **Epson L3210 Drivers** - <https://epson.com/Support/Printers/>
- [ ] **Logi Options+** - <https://support.logi.com/hc/es-ar/articles/31605553077783-Descargas-MX-Master-3S-BT-Edition/>
- [ ] **Stream Deck** - <https://www.elgato.com/lm/es/s/downloads>

### Herramientas Especiales

- [ ] **AlDente** - <https://apphousekitchen.com/aldente-overview/>
- [ ] **Parsec** - <https://parsecgaming.com/downloads/>
- [ ] **AppCleaner** - <https://freemacsoft.net/appcleaner/>
- [ ] **Bartender** - <https://www.macbartender.com/>
- [ ] **CodexBar** - <https://codexbar.app/>
- [ ] **Flow** - <https://wisprflow.ai>

### Terminal & Development

- [ ] **Ghostty** - <https://ghostty.org/download>
- [ ] **Visual Studio Code** - <https://code.visualstudio.com/>
- [ ] **OrbStack** - <https://orbstack.dev/download/>
- [ ] **Android Studio** - <https://developer.android.com/studio/>
- [ ] **TablePlus** - <https://tableplus.com/>
- [ ] **Tiny Shield** - <https://tinyshield.proxyman.com/>
- [ ] **Bruno** - <https://www.usebruno.com/downloads/>
- [ ] **Laravel Herd** - <https://herd.laravel.com/>

### IA & Coding Agents

- [ ] **Claude** - <https://claude.ai/api/desktop/darwin/universal/dmg/latest/redirect/>

### Productividad

- [ ] **Raycast** - <https://www.raycast.com/>
- [ ] **Obsidian** - <https://obsidian.md/download>
- [ ] **Spotify** - <https://open.spotify.com/download>

### Media & Content

- [ ] **IINA** - <https://iina.io/>
- [ ] **Affinity** - <https://www.affinity.studio/>
- [ ] **qBittorrent** - <https://www.qbittorrent.org/download.php>
- [ ] **4k Video Downloader+** - <https://www.4kdownload.com/downloads/34/>

---

## ⚙️ Configuraciones Post-Instalación

### Node.js (con nvm)

```bash
nvm install 24
nvm use 24
nvm alias default 24
corepack enable pnpm
npm config set ignore-scripts true
npm config set allow-git none
npm config set min-release-age 3
npm install -g @fission-ai/openspec@latest
npm i -g vercel
npm install -g @playwright/cli@latest
```

### Python (con pyenv)

```bash
pyenv install 3.14.3
pyenv global 3.14.3
```

### Oh My Zsh

Configurar Oh My Zsh manualmente:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Powerlevel10k Theme

Configurar Powerlevel10k manualmente:

```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
```

### instalar Sail

```bash
php artisan sail:install
```

### Multi agents

```bash
curl -fsSL https://herdr.dev/install.sh | sh
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
```

### IA

Instalar inteligencias artificiales IA:

```bash
curl -fsSL https://opencode.ai/install | bash
opencode auth login
```

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
curl https://cursor.com/install -fsS | bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://gh.io/copilot-install | bash
curl -fsSL https://kilo.ai/cli/install | bash
curl -fsSL https://cli.kiro.dev/install | bash
```

---
