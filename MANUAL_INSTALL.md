# 📱 Instalación Manual

Apps que deben instalarse manualmente desde la App Store o fuentes externas.

**Nota:** La mayoría de las apps están en el Brewfile y se instalan automáticamente con `brew bundle install`.

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
- [ ] **HEIC Converter** - Convertir imágenes HEIC
- [ ] **LocalSend** - Compartir archivos localmente
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
- [ ] **Elgato Stream Deck** - <https://www.elgato.com/en/gaming/downloads>
- [ ] **Elgato Wave Link** - <https://www.elgato.com/en/gaming/downloads>
- [ ] **DisplayLink Manager** - <https://www.displaylink.com/downloads/macos>

### Gaming

- [ ] **League of Legends** - <https://www.leagueoflegends.com/>
- [ ] **Steam** - <https://store.steampowered.com/about/>
- [ ] **Epic Games Launcher** - <https://www.epicgames.com/store/en-US/download>

### Herramientas Especiales

- [ ] **SysDVR-Client** - <https://github.com/exelix11/SysDVR>
- [ ] **AIDente** - <https://aidente.com/>
- [ ] **Parsec** - <https://parsecgaming.com/downloads/>
- [ ] **AppCleaner** - <https://freemacsoft.net/appcleaner/>
- [ ] **Cisco packet tracer** - <https://www.netacad.com/courses/packet-tracer>

### AI Tools

- [ ] **ChatGPT Desktop** - <https://openai.com/chatgpt/download/>

### Web Apps

- [ ] **Photopea** - <https://www.photopea.com/> (Editor de imágenes en línea)

### Terminal & Development

- [ ] **Warp Terminal** - <https://www.warp.dev/>
- [ ] **Visual Studio Code** - <https://code.visualstudio.com/>
- [ ] **Docker** - <https://www.docker.com/products/docker-desktop/>
- [ ] **Android Studio** - <https://developer.android.com/studio>
- [ ] **Unity Hub** - <https://unity.com/download>
- [ ] **PSeInt** - <http://pseint.sourceforge.net/>
- [ ] **TablePlus** - <https://tableplus.com/>
- [ ] **Cyberduck** - <https://cyberduck.io/>
- [ ] **Figma** - <https://www.figma.com/downloads/>
- [ ] **UTM** - <https://mac.getutm.app/>
- [ ] **RStudio** - <https://posit.co/download/rstudio-desktop/>
- [ ] **Arduino IDE** - <https://www.arduino.cc/en/software>
- [ ] **MAMP** - <https://www.mamp.info/en/downloads/>

### Browsers

- [ ] **Brave** - <https://brave.com/>
- [ ] **Zen Browser** - <https://zen-browser.app/>

### Productivity

- [ ] **Raycast** - <https://www.raycast.com/>
- [ ] **Notion** - <https://www.notion.so/desktop>
- [ ] **Google Drive** - <https://www.google.com/drive/download/>
- [ ] **Dropbox** - <https://www.dropbox.com/install>
- [ ] **Microsoft Teams** - <https://www.microsoft.com/en/microsoft-teams/download-app>
- [ ] **Telegram** - <https://desktop.telegram.org/>
- [ ] **Discord** - <https://discord.com/download>

### Media & Content

- [ ] **OBS Studio** - <https://obsproject.com/download>
- [ ] **VLC Media Player** - <https://www.videolan.org/vlc/download-macosx.html>
- [ ] **Spotify** - <https://www.spotify.com/download/mac/>
- [ ] **Audacity** - <https://www.audacityteam.org/download/mac/>

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
pyenv install 3.13.7 # Ultima versión
pyenv global 3.13.7
```

### Spicetify (Spotify Customization)

Después de instalar Spotify via Homebrew:

```bash
# Hacer backup y aplicar
spicetify backup apply
```

### OBS Studio Plugins

Descargar e instalar manualmente desde OBS Forums:

- [ ] **Move Transition** - <https://obsproject.com/forum/resources/move.913/>
- [ ] **Zoom to Mouse (LUA Script)** - <https://obsproject.com/forum/resources/zoom-to-mouse.1258/>
- [ ] **Advanced Scene Switcher** - <https://obsproject.com/forum/resources/advanced-scene-switcher.395/>
- [ ] **StreamFX** - <https://obsproject.com/forum/resources/streamfx-for-obs-studio.578/>

### Discord (Vencord Mod)

Después de instalar Discord:

```bash
sh -c "$(curl -sS https://raw.githubusercontent.com/Vendicated/VencordInstaller/main/install.sh)"
```

**Nota:** Vencord es un mod de Discord. Úsalo bajo tu propio riesgo.

### Oh My Zsh con Warp

Configurar Oh My Zsh manualmente:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

---

## 📋 Apps Instaladas via Homebrew

Las siguientes apps ya están incluidas en el `Brewfile` y se instalan automáticamente:

### Development

- Claude Code, Gemini Cli

---

## 📝 Notas

- Algunas apps están disponibles tanto en App Store como en Homebrew. Elige según tu preferencia.
- App Store puede tener mejor integración con macOS (actualizaciones automáticas, sandboxing)
- Homebrew permite gestionar todas las apps desde la terminal
- Verifica las versiones antes de instalar
- Mantén este documento actualizado con cada nueva instalación

---

## 🔗 Referencias

- Git Settings: <https://github.com/ColeCaccamise/dotfiles>
- Dock Auto-Hide: <https://colecaccamise.notion.site/Auto-Show-Hide-Dock-df299877627a4311a8aad8c7ba7dbc75>
- Raycast Extensions: <https://colecaccamise.com/stack/raycast> (ver `scripts/raycast-extensions.md`)
