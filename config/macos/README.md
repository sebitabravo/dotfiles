# macOS Defaults

Optimizaciones de macOS para developers. Cero dependencias. Verificado en
Sequoia 15.7.9, Tahoe 26.6.2 y Golden Gate 27.0 (arm64); los cambios entre
versiones viven detrás de guards. Reconciliado contra el estado real de la
máquina.

## Uso

```bash
chmod +x defaults.sh && ./defaults.sh --dry-run   # revisar antes de aplicar
./defaults.sh                                     # aplicar (idempotente)
../../.github/verify.sh                           # auditar drift (read-only)
```

| Marca | Significado |
|---|---|
| `[SET]` | El write tuvo éxito (no implica cambio de valor). |
| `[SKIP]` | Un guard decidió no ejecutar (versión, estado, ruta inexistente). |
| `[FAIL]` | El write no tuvo efecto (ej: TCC sin Full Disk Access). |
| `[WARN]` | Verificación de solo lectura con algo que revisar a mano. |
| `[--]` | Informativo, sin acción. |

| Flag | Efecto |
|---|---|
| `--dry-run` | Imprime sin ejecutar; no mata Dock/Finder ni pide sudo. |
| `--no-sudo` | Salta el Tier 2. |
| `--bonjour-off` | Opt-in: desactiva multicast Bonjour (rompe impresoras/DLNA/Home Assistant en LAN). |

## Qué hace

- **Tier 1 (usuario, sin sudo):** animaciones instantáneas, key repeat rápido,
  Finder para devs (extensiones, ruta, papelera sin warning), Dock auto-hide
  sin delay, Mission Control fijo, tap-to-click, región métrica ISO, Safari
  anti-tracking (~30 keys), telemetría y IDFA off, screensaver inmediato,
  Software Update diario, Xcode paralelo con duración de build, Reduce
  Transparency (desde 26.3).
- **Tier 2 (sudo, una sola sesión root, se salta con `--no-sudo`):** developer
  mode, Power Nap off, `womp` split (AC on / batería off), auto-restart off,
  SSH y NTP, banner de login, `RetriesUntilHint=0`, Touch ID para sudo
  (`sudo_local`), firewall + stealth + excepciones `rapportd`/`sharingd`, Low
  Power Mode solo en batería.
- **Tier 3 (sin sudo):** excluye de Spotlight y Time Machine las rutas de
  desarrollo que existan (`~/Developer`, `DerivedData`, `~/.cache`, `~/go/pkg`,
  contenedor de Docker). No crea directorios: si no existe, se salta.
- **Verificación de seguridad (siempre, read-only):** FileVault, firewall,
  stealth, SIP, Gatekeeper, bloqueo de pantalla, espacio libre, listeners
  (incluye AirPlay Receiver en 5000/7000) y destino de Time Machine.

## Después de formatear

Tres bloques se saltan solos en una Mac nueva y el orden importa:

1. `./install.sh` (bootstrap; no aplica defaults, es deliberado).
2. Full Disk Access a la terminal (si no, el bloque Safari se salta entero).
3. `./defaults.sh` (primera pasada).
4. Clonar repos y correr toolchains (crea `~/Developer`, `~/.cache`, `~/go/pkg`).
5. `./defaults.sh` (segunda pasada: ahora aplica el Tier 3).
6. `../../.github/verify.sh`.

Manual, ningún script lo cubre: FileVault, destino de Time Machine, AirPlay
Receiver en "Usuario actual" (mitiga la cadena AirBorne sin perder AirPlay), y
los toggles de telemetría de Ajustes que no tienen key pública (Spotlight,
Siri/Dictado, anuncios, Safari Buscar, Apple Intelligence).

Tras un upgrade de major: el instalador de macOS re-inscribe el ID de
publicidad; corre `./defaults.sh` y `verify.sh` de nuevo.

## Preferencias personales (sácalas si copias)

| Preferencia | Revertir |
|---|---|
| Scroll invertido | `defaults delete NSGlobalDomain com.apple.swipescrolldirection` |
| Barra de menú oculta | `defaults delete NSGlobalDomain _HIHideMenuBar` |
| Iconos de escritorio ocultos | `defaults delete com.apple.WindowManager HideDesktop` |
| Volúmenes externos ocultos | `defaults delete com.apple.finder ShowExternalHardDrivesOnDesktop` (+ `ShowRemovableMediaOnDesktop`) |

Después de cualquier `defaults delete`: `killall Finder Dock SystemUIServer
WindowManager`.

Opt-in fuera del script: `ApplePressAndHoldEnabled false` (repeat sin menú de
acentos), `com.apple.screencapture show-thumbnail false` (captura sin preview),
`brew autoupdate start 86400 --upgrade --cleanup`.

## Revertir

```bash
defaults delete <dominio> <key>          # un cambio puntual
defaults delete NSGlobalDomain && defaults delete com.apple.finder   # TODO (borra todas tus preferencias de esos dominios)
```

Ningún cambio rompe Handoff, Continuity, Find My ni AirDrop.
