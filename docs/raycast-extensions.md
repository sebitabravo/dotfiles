# Raycast Extensions

## ✨ Extensiones Esenciales

### 🎵 Set Output Device

**Descripción:** Quickly swap your input/output audio devices
**Uso:** Cambiar rápidamente entre dispositivos de audio (AirPods, parlantes, etc.)

### 🎧 Coffee

**Descripción:** Prevent your Mac from going to sleep
**Uso:** Mantén tu Mac despierto mientras trabajas (Caffeinate status)

### 🔌 Port Manager

**Descripción:** View and close your open ports
**Uso:** Ver qué puertos están abiertos y cerrarlos (útil cuando algo queda corriendo)

### 👻 Lock Keyboard

**Descripción:** Lock your keyboard to clean it easily
**Uso:** Bloquea tu teclado rápidamente (útil para limpieza o pausas rápidas)

### 📂 Github

**Descripción:** Manage GitHub issues, pull requests, and repositories
**Uso:** Gestión rápida de issues y PRs en GitHub

### 🔴 Color Picker

**Descripción:** Pick colors and copy them to clipboard
**Uso:** Selector de colores rápido

### 📱 Simulator Manager

**Descripción:** Manage iOS Simulators from Raycast
**Uso:** Administrar simuladores de iOS directamente desde Raycast

---

## Display scripts (dual-monitor)

Script Commands deployed to `~/.raycast/scripts`. The Raycast app itself is a
manual install (see `docs/MANUAL_INSTALL.md:81`), intentionally not in the
Brewfile. `install.sh` deploys with
`copy_dir config/raycast/scripts "$HOME/.raycast/scripts"` (rsync copy, not a
symlink), so the repo copy under `config/raycast/scripts` is canonical. After
editing, re-run `./install.sh` or sync with `cp -p` + `chmod +x` and verify
with `diff -rq config/raycast/scripts ~/.raycast/scripts`.

| Script | Purpose | When to use |
| --- | --- | --- |
| `set-1440p.sh` | Applies dual 1440p layout in one atomic `displayplacer` call | Daily driver mode: MSI at full 2560x1440 |
| `set-1080p.sh` | Applies dual 1080p layout in one atomic call, then `killall WallpaperAgent \|\| true` to clear the stale wallpaper frame | Perf/compat mode or when 1440p causes issues |
| `reset-display-placement.sh` | Idempotent repair: reads `displayplacer list`, skips when a screen is disconnected, repairs drift, defaults unknown MSI resolutions to dual 1440p | Placement looks wrong after dock/undock or wake |
| `restart-elgato.sh` | Kills and relaunches the Elgato stack (Stream Deck + Wave Link), relaunching only apps that were running | Stream Deck or Wave Link frozen after sleep |

Expected dual layout (no internal display in snapshot):

- 1440p mode: MAIN 24" `1920x1080@120` at origin `(0,0)` (main) + MSI 27" `2560x1440@72` at origin `(1920,-180)` (top-aligned).
- 1080p mode: MAIN 24" `1920x1080@60` at origin `(0,0)` (main) + MSI 27" `1920x1080@60` at origin `(1920,0)` (same height, tops already align).

After every resolution change the scripts run:

```bash
open -g raycast://extensions/raycast/raycast/reset-raycast-window-position
```

The `-g` flag keeps Raycast in the background instead of stealing focus.

Note: `restart-elgato.sh` covers both `Elgato Stream Deck` and `Elgato Wave Link`.
