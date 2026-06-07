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
- [ ] **Parallels Desktop** - Virtualización de sistemas operativos
- [ ] **1Blocker** - Bloqueador de anuncios y rastreadores
- [ ] **WhatsApp** - Cliente de mensajería
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

### Terminal & Development

- [ ] **Warp Terminal** - <https://www.warp.dev/>
- [ ] **Visual Studio Code** - <https://code.visualstudio.com/>
- [ ] **OrbStack** - <https://orbstack.dev/download/>
- [ ] **Android Studio** - <https://developer.android.com/studio/>
- [ ] **TablePlus** - <https://tableplus.com/>
- [ ] **Cyberduck** - <https://cyberduck.io/>
- [ ] **Tiny Shield** - <https://tinyshield.proxyman.com/>
- [ ] **Bruno** - <https://www.usebruno.com/downloads/>
- [ ] **Laravel Herd** - <https://herd.laravel.com/>
- [ ] **Unity** - <https://unity.com/download/>
- [ ] **Blender** - <https://www.blender.org/download/>

### IA & Coding Agents

- [ ] **GitHub Copilot App** - <https://github.com/github/app>
- [ ] **Codex** - <https://openai.com/es-419/codex/>
- [ ] **Cowork** - <https://claude.ai/api/desktop/darwin/universal/dmg/latest/redirect/>

### Browsers

- [ ] **Google Chrome** - <https://www.google.com/chrome/>

### Productividad

- [ ] **Raycast** - <https://www.raycast.com/>
- [ ] **Microsoft Teams** - <https://www.microsoft.com/en/microsoft-teams/download-app/>
- [ ] **Discord** - <https://discord.com/download/>
- [ ] **VoiceInk** - <https://tryvoiceink.com/> — Whisper small/base
- [ ] **Obsidian** - <https://obsidian.md/download>
- [ ] **Notion** - <https://www.notion.so/desktop>

### Media & Content

- [ ] **IINA** - <https://iina.io/>
- [ ] **Figma** - <https://www.figma.com/downloads/>
- [ ] **Affinity** - <https://www.affinity.studio/>
- [ ] **qBittorrent** - <https://www.qbittorrent.org/download.php>
- [ ] **Audacity** - <https://www.audacityteam.org/download/mac/>
- [ ] **Recordly** - <https://recordly.dev>
- [ ] **VoiceBox** - <https://voicebox.sh/download> — Qwen3-TTS 0.6B, Whisper Small, Qwen3 0.6B LLM
- [ ] **4k Video Downloader+** - <https://www.4kdownload.com/downloads/34/>

### Gaming

- [ ] **Steam** - <https://store.steampowered.com/about/> - Habilitar beta Update
- [ ] **Epic Games Launcher** - <https://www.epicgames.com/store/en-US/download/>
- [ ] **Prism Launcher** - <https://prismlauncher.org/>

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
```

### Python (con pyenv)

```bash
pyenv install 3.14.3
pyenv global 3.14.3
```

### Oh My Zsh con Warp

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

### IA

Instalar inteligencias artificiales IA:

- Configurar con ChatGPT.

```bash
curl -fsSL https://opencode.ai/install | bash
opencode auth login
```

```bash
pnpm add -g @openai/codex
pnpm add -g @google/gemini-cli
curl -fsSL https://claude.ai/install.sh | bash
```

---
