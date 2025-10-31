# 📱 Instalación Manual

Apps que deben instalarse manualmente desde la App Store o fuentes externas.

## 🍎 App Store

Estas apps se instalan desde la App Store de macOS:

### Productividad

- [ ] **Xcode** - IDE de Apple
- [ ] **Microsoft Office Suite**:
  - [ ] Outlook
  - [ ] PowerPoint
  - [ ] Word
  - [ ] Excel
  - [ ] OneDrive

### Utilidades

- [ ] **CleanMyMac** - Limpieza del sistema
- [ ] **Amphetamine** - Prevenir que Mac se duerma
- [ ] **Hidden Bar** - Organizar iconos de la barra de menú
- [ ] **PPTControl Desktop** - Control remoto para PowerPoint
- [ ] **DaVinci Resolve** - Edición de video profesional

### Comunicación

- [ ] **WhatsApp** - Mensajería

### Safari Extensions

- [ ] **1Blocker** - Bloqueador de anuncios
- [ ] **Dark Reader** - Modo oscuro para sitios web

---

## 🌐 Instalación Externa

### Drivers & Hardware

- [ ] **Epson L3210 Drivers** - <https://epson.com/Support/Printers/>
- [ ] **DisplayLink Manager** - <https://www.displaylink.com/downloads/macos>

### Herramientas Especiales

- [ ] **AIDente** - <https://aidente.com/>
- [ ] **Parsec** - <https://parsecgaming.com/downloads/>
- [ ] **AppCleaner** - <https://freemacsoft.net/appcleaner/>

### AI Tools

- [ ] **Claude Desktop** - <https://www.claude.com/download>

### Terminal & Development

- [ ] **Warp Terminal** - <https://www.warp.dev/>
- [ ] **Visual Studio Code** - <https://code.visualstudio.com/>
- [ ] **Docker** - <https://www.docker.com/products/docker-desktop/>
- [ ] **Android Studio** - <https://developer.android.com/studio>
- [ ] **TablePlus** - <https://tableplus.com/>
- [ ] **Cyberduck** - <https://cyberduck.io/>
- [ ] **UTM** - <https://mac.getutm.app/>

### Browsers

- [ ] **Brave** - <https://brave.com/>

### Productivity

- [ ] **Raycast** - <https://www.raycast.com/>
- [ ] **Google Drive** - <https://www.google.com/drive/download/>
- [ ] **Dropbox** - <https://www.dropbox.com/install>

### Media & Content

- [ ] **VLC Media Player** - <https://www.videolan.org/vlc/download-macosx.html>

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
pyenv install 3.14.0 # Ultima versión
pyenv global 3.14.0
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

### IA

Instalar inteligencias artificiales IA:

```bash
npm install -g @github/copilot
npm install -g @google/gemini-cli
npm install -g @anthropic-ai/claude-code
```

---
