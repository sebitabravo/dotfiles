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
- [ ] **TestFlight** - Probar apps beta de macOS
- [ ] **CrystalFetch** - Descarga ISOs de Windows ARM
- [ ] **Parallels Desktop** - Virtualización de sistemas operativos

---

## 🌐 Instalación Externa

### Drivers & Hardware

- [ ] **Epson L3210 Drivers** - <https://epson.com/Support/Printers/>
- [ ] **DisplayLink Manager** - <https://www.displaylink.com/downloads/macos>
- [ ] **Logitech Options+** - <https://www.logitech.com/es-ar/software/logi-options-plus.htmls>
- [ ] **VencordInstaller** - <https://vencord.dev/>
- [ ] **SysDVR-Client** - <https://github.com/exelix11/SysDVR>

### Herramientas Especiales

- [ ] **AlDente** - <https://apphousekitchen.com/aldente-overview/>
- [ ] **Parsec** - <https://parsecgaming.com/downloads/>
- [ ] **AppCleaner** - <https://freemacsoft.net/appcleaner/>
- [ ] **Bartender** - <https://www.macbartender.com/>
- [ ] **Elgato Stream Deck** - <https://www.elgato.com/lm/es/s/downloads>
- [ ] **Elgato Wave Link** - <https://www.elgato.com/ww/en/s/downloads>
- [ ] **DockDoor** - <https://dockdoor.net/>

### Terminal & Development

- [ ] **Warp Terminal** - <https://www.warp.dev/>
- [ ] **Visual Studio Code** - <https://code.visualstudio.com/>
- [ ] **OrbStack** - <https://orbstack.dev/download>
- [ ] **Android Studio** - <https://developer.android.com/studio>
- [ ] **TablePlus** - <https://tableplus.com/>
- [ ] **Cyberduck** - <https://cyberduck.io/>
- [ ] **Antigravity** - <https://antigravity.google/>
- [ ] **Trae** - <https://www.trae.ai/>
- [ ] **Tiny Shield** - <https://tinyshield.proxyman.com/>
- [ ] **Bruno** - <https://www.usebruno.com/downloads>

### Browsers

- [ ] **Brave** - <https://brave.com/>
- [ ] **Firefox** - <https://www.mozilla.org/en-US/firefox/new/>
- [ ] **Google Chrome** - <https://www.google.com/chrome/>
- [ ] **Comet** - <https://www.perplexity.ai/comet>

### Productividad

- [ ] **Raycast** - <https://www.raycast.com/>
- [ ] **Google Drive** - <https://www.google.com/drive/download/>
- [ ] **Dropbox** - <https://www.dropbox.com/install>
- [ ] **Microsoft Teams** - <https://www.microsoft.com/en/microsoft-teams/download-app>
- [ ] **Discord** - <https://discord.com/download>

### Media & Content

- [ ] **IINA** - <https://iina.io/>
- [ ] **Affinity** - <https://www.affinity.studio/>
- [ ] **qBittorrent** - <https://www.qbittorrent.org/download.php>
- [ ] **Meld Studio** - <https://meldstudio.co/>
- [ ] **Audacity** - <https://www.audacityteam.org/download/mac/>
- [ ] **4k Video Downloader+** - <https://www.4kdownload.com/downloads/34>

### Gaming

- [ ] **Steam** - <https://store.steampowered.com/about/> - Habilitar beta Update
- [ ] **Epic Games Launcher** - <https://www.epicgames.com/store/en-US/download>
- [ ] **Prism Launcher** - <https://prismlauncher.org/>
- [ ] **GOG GALAXY 2.0** - <https://www.gogalaxy.com/en/>

---

## ⚙️ Configuraciones Post-Instalación

### Node.js (con fnm)

```bash
fnm install 20
fnm use 20
fnm default 20
```

### Python (con pyenv)

```bash
pyenv install 3.11.1 # Versión desarrollo
pyenv install 3.14.2 # Ultima versión
pyenv global 3.14.2
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

### R Language

Instalar paquetes R esenciales:

```bash
R -e 'install.packages("languageserver", repos="https://cran.r-project.org")'
pipx install radian
```

### PHP

<https://php.new/?hl=es-US>

### IA

Instalar inteligencias artificiales IA:

- Configurar con copilot, gemini-cli y claude.

```bash
curl -fsSL https://opencode.ai/install | bash
opencode auth login
```

---
