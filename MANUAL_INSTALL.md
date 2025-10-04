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
- [ ] **AIDente** - Gestión de batería
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

### Gaming

- [ ] **League of Legends** - <https://www.leagueoflegends.com/>

### Herramientas Especiales

- [ ] **SysDVR-Client** - <https://github.com/exelix11/SysDVR>
- [ ] **Unity Hub** - <https://unity.com/download>
- [ ] **PSeInt** - <http://pseint.sourceforge.net/>

### AI Tools

- [ ] **ChatGPT Desktop** - <https://openai.com/chatgpt/download/>

### Web Apps

- [ ] **Photopea** - <https://www.photopea.com/> (Editor de imágenes en línea)

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
pyenv install 3.11.1
pyenv global 3.11.1
```

### Spicetify (Spotify Customization)

Después de instalar Spotify via Homebrew:

```bash
# Hacer backup y aplicar
spicetify backup apply

# Instalar temas y extensiones (opcional)
spicetify config current_theme Sleek
spicetify apply
```

### OBS Studio Plugins

Descargar e instalar manualmente desde OBS Forums:

- [ ] **Move Transition** - <https://obsproject.com/forum/resources/move.913/>
- [ ] **Zoom to Mouse (LUA Script)** - <https://obsproject.com/forum/resources/zoom-to-mouse.1258/>
- [ ] **Advanced Scene Switcher** - <https://obsproject.com/forum/resources/advanced-scene-switcher.395/>
- [ ] **StreamFX** - <https://obsproject.com/forum/resources/streamfx-for-obs-studio.578/>

### Discord (Vencord Mod)

Después de instalar Discord via Homebrew:

```bash
sh -c "$(curl -sS https://raw.githubusercontent.com/Vendicated/VencordInstaller/main/install.sh)"
```

**Nota:** Vencord es un mod de Discord. Úsalo bajo tu propio riesgo.

### Oh My Zsh con Warp

Warp ya viene con Oh My Zsh integrado. Si prefieres configurar Oh My Zsh manualmente:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

---

## 📋 Apps Instaladas via Homebrew

Las siguientes apps ya están incluidas en el `Brewfile` y se instalan automáticamente:

### Terminal & Development

- Warp, Visual Studio Code, Docker, Android Studio, Claude Code

### Browsers

- Google Chrome, Brave, Zen Browser

### Development Tools

- TablePlus, Cyberduck, Figma, Raycast

### Productivity

- Notion, Google Drive, Dropbox, Microsoft Teams

### Media & Content

- OBS Studio, VLC, Spotify, Audacity

### Utilities

- AppCleaner, The Unarchiver, UTM, Parsec, DisplayLink

### Communication

- Discord, Telegram

### Gaming

- Steam, Epic Games

### Streaming Hardware

- Elgato Stream Deck, Elgato Wave Link

### Data Science

- RStudio

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
