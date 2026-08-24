# macOS Defaults

Optimizaciones de macOS orientadas a developers. Cero dependencias externas.

Verificado en **Sequoia 15.7.9**. Tahoe 26.x no esta verificado: ahi Launchpad
ya no existe (lo absorbio Spotlight) y las keys `springboard-*` pasan a ser
no-op; el script lo detecta y avisa, pero no lo bloquea.

El script esta reconciliado contra el estado real de la maquina: los valores
reflejan como esta configurada hoy, no una propuesta teorica.

## Quick Start

```bash
chmod +x defaults.sh && ./defaults.sh --dry-run   # revisar antes de aplicar
./defaults.sh                                     # aplicar de verdad
./verify.sh                                       # auditar el resultado
```

`defaults.sh` reporta cada item como `[SET]` (se aplico), `[SKIP]` (ya estaba
asi), o `[FAIL]` (el write no tuvo efecto — no se miente con un `[OK]`
incondicional). `verify.sh` no escribe nada: compara el estado real contra lo
que el script promete y sale con `1` si hay drift.

### Flags

| Flag | Que hace |
|---|---|
| `--dry-run` | Imprime cada comando sin ejecutarlo. No mata Dock/Finder ni pide sudo. |
| `--no-sudo` | Salta el tier con sudo (DevToolsSecurity, Power Nap, auto-restart, SSH). |
| `--bonjour-off` | Opt-in: desactiva multicast de Bonjour. Rompe descubrimiento de impresoras, DLNA y Home Assistant en la LAN — no es default por eso. |
| `--help` | Ayuda corta. |

Si algo no te gusta despues de aplicar, volves atras sin consecuencias:
`defaults delete <dominio> <key>`. Ningun cambio rompe el ecosistema Apple
(Handoff, Continuity, Find My, AirDrop, etc.).

## Que hace — Tier 1 (usuario, sin sudo)

| Area | Que se optimiza |
|---|---|
| **Animaciones** | Ventanas instantaneas, sin rebote elastico, sin anillo de foco animado |
| **Teclado** | Key repeat rapido (2), delay corto (15), Tab navega todos los controles |
| **Finder** | Extensiones visibles, barra de ruta y de estado, panel de vista previa, carpetas primero al ordenar, spring-loading instantaneo, trash auto-clean >30 dias, sin warning al vaciar papelera, sin iconos de discos en el escritorio, sin .DS_Store en network |
| **Dock** | Auto-hide instantaneo (sin delay ni animacion), sin rebote al abrir apps, sin apps recientes, minimizar a slot propio, size 48px |
| **Mission Control** | Escritorios en orden fijo (sin reorden por uso), sin cambio automatico de escritorio, ventanas agrupadas por app |
| **Ventanas** | Doble clic en la barra de titulo = Fill, arrastrar con ctrl+cmd desde cualquier punto, Stage Manager off |
| **Menu Bar** | Clock digital 24h, barra minima (solo reloj + Control Center), icono Spotlight oculto, auto-hide de la barra completa (ver nota abajo) |
| **Desktop** | Iconos visibles en el Finder pero ocultos mientras trabajas (WindowManager) |
| **Trackpad** | Tap to click, click derecho con dos dedos, arrastre con tres dedos, swipes de espacios con cuatro dedos |
| **Region** | Metrico, Celsius, semana desde el lunes, fecha corta ISO (y-MM-dd) |
| **Safari / WebKit** | ~30 keys: sin tracking ni search suggestions, pop-ups bloqueados, fraudulent website warning, extensiones auto-update, thumbnail cache off, Debug menu, Web Inspector. **AutoFill esta ACTIVO** (incluye contrasenas y tarjetas) — es funcionalidad principal de macOS, no se toca. Se salta entero si la terminal no tiene Full Disk Access (ver mas abajo). |
| **Privacidad** | Siri analytics off, diagnostics off, apps anonymous usage off, IDFA desactivado |
| **Security** | Screensaver password immediate (idle 5 min), Terminal Secure Keyboard Entry |
| **Software Update** | Check diario, auto-descarga, auto-instalar updates criticos de seguridad y system data files |
| **App Store** | Debug menu, auto-update apps + auto-restart |
| **Activity Monitor** | Todos los procesos visibles, refresh 2s, sort por CPU |
| **Xcode** | Debug menu, file extensions, parallel build (max cores), numeric progress, no state restoration |
| **Terminal** | UTF-8 only, Secure Keyboard Entry, no line marks |
| **Accessibility** | Ctrl+Scroll = zoom de pantalla, navegacion completa por teclado (Tab llega a todos los controles) |
| **Sequoia** | Reduce Transparency (Liquid Glass GPU relief). Se salta en Tahoe 26.x — ahi el compositor puede dar artefactos con esta key. |
| **Mail** | Sin animaciones al responder/enviar, copy email sin nombre, texto plano por defecto, inline attachments off |

**Lo que NO se toca a proposito:** las animaciones de ventanas y apps quedan
en su comportamiento stock — este script es para developers que necesitan ver
las animaciones de las apps que construyen. AutoFill de Safari tampoco se
toca: es la funcionalidad principal, no bloat.

### Full Disk Access y el bloque Safari

Safari esta sandboxed: su plist real vive en
`~/Library/Containers/com.apple.Safari/...`, protegido por TCC. Sin Full Disk
Access para tu terminal, `defaults write com.apple.Safari` no falla — cae en
silencio a `~/Library/Preferences/com.apple.Safari.plist`, un archivo que
Safari sandboxed nunca lee. El script detecta esto con una key canario antes
de tocar las ~30 keys de Safari; si no hay FDA, saltea el bloque entero con
un `[SKIP]` en vez de reportar 30 `[SET]` falsos.

Para habilitarlo: **Ajustes > Privacidad y Seguridad > Acceso total al
disco**, agregar tu terminal, reabrirla.

### Menu bar auto-hide

La barra de menu se oculta hasta que pasas el mouse arriba. Mas espacio
vertical, pero desorienta al principio, y si usas un gestor de iconos como
Bartender revisa que no compita con el. Revertir:
`defaults delete NSGlobalDomain _HIHideMenuBar`.

### Opt-in deliberado (no estan en el tier 1 por defecto)

Estos dos rompen comportamiento esperado de macOS o funcionalidad que la
mayoria de los usuarios necesita, asi que quedan fuera del script:

```bash
# Key repeat sin menu de acentos: mantener tecla repite el caracter en vez de
# mostrar el menu de acentos. Util para developers, frustrante escribiendo en
# espanol (se pierde el menu de a, e, n).
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Screenshot sin thumbnail flotante: la captura se guarda directo a disco sin
# preview editable. Mas rapido, pero no podes editar ni compartir al instante.
defaults write com.apple.screencapture show-thumbnail -bool false
```

## Que hace — Tier 2 (requiere sudo)

Antes vivia como texto suelto en este README bajo "Recomendaciones con sudo"
y nunca se ejecutaba. Ahora esta dentro de `defaults.sh`: pide tu password
una vez (`sudo -v`) y aplica solo lo que tiene un revert claro. Se salta
completo con `--no-sudo`.

| Item | Aplica si... | Revertir |
|---|---|---|
| Developer mode | `DevToolsSecurity -status` dice disabled | `sudo DevToolsSecurity -disable` |
| Power Nap off | esta en 1 (AC o bateria) | `sudo pmset -a powernap 1` |
| Wake settings | siempre fija `womp 0` y `proximitywake 1` | `sudo pmset -a womp 1 proximitywake 0` |
| Auto-restart en freeze/corte de luz | no esta configurado | `sudo pmset -a autorestart 0` + `sudo systemsetup -setrestartfreeze off` |
| SSH remoto apagado | esta prendido | `sudo systemsetup -setremotelogin on` — dejalo prendido si lo usas para desarrollo |
| Login Window muestra hostname | `AdminHostInfo` no es `HostName` | `sudo defaults delete /Library/Preferences/com.apple.loginwindow AdminHostInfo` |
| Touch ID para sudo | `/etc/pam.d/sudo_local` no existe | `sudo rm /etc/pam.d/sudo_local` |
| `/Volumes` visible en Finder | tiene el flag hidden | `sudo chflags hidden /Volumes` |

Mecanismo oficial `sudo_local` de Apple (Sonoma+): sobrevive updates de
macOS, a diferencia del viejo hack de `pam_tid.so` directo en
`/etc/pam.d/sudo`. Compatibilidad con herramientas de desarrollo:

| Herramienta | Compatible? | Nota |
|---|---|---|
| Terminal.app, VS Code, Warp | Si, nativo | Sin configuracion extra |
| iTerm2 | Si, requiere toggle | Preferences > Advanced > "Allow sessions" > "No" |
| tmux | Si, requiere `pam-reattach` | `brew install pam-reattach`, agregar `auth optional /opt/homebrew/lib/pam/pam_reattach.so` antes de `pam_tid.so` en `sudo_local` |
| SSH / scripts / CI | Si, sin cambios | `pam_tid.so` usa `sufficient`: sin GUI cae a password |
| Macs sin Touch ID | Si, sin cambios | Cae a password automaticamente |
| Grabacion de pantalla activa | Si, sin cambios | Touch ID se desactiva por seguridad, cae a password |

Ademas, el tier 2 **verifica y reporta sin escribir nada**: FileVault,
firewall + stealth mode, SIP, Gatekeeper, Secure Token, bloqueo de pantalla,
y HiDPI para monitores 4K (`sudo defaults write
/Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool
true`, solo hace falta con un monitor 4K externo). Ninguno de estos se
modifica desde el script — son decisiones tuyas, el script solo confirma el
estado.

### Bonjour multicast — opt-in explicito (`--bonjour-off`)

CIS Benchmark Level 1. Reduce ruido de red y superficie de ataque. No rompe
AirDrop ni AirPlay (usan AWDL, distinto de mDNS multicast), pero **si rompe**
descubrimiento de impresoras Bonjour, servidores DLNA y Home Assistant en tu
LAN. Por eso no es default:

```bash
./defaults.sh --bonjour-off
```

Revertir:
```bash
sudo defaults delete /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements
sudo killall mDNSResponder
```

## Que hace — Tier 3 (exclusiones de indexado, sin sudo)

La ganancia real y medible en una maquina de desarrollo. Sequoia tiene una
regresion documentada de indexado de Spotlight (CPU e I/O de disco altos), y
el arbol de desarrollo — `node_modules`, builds, `DerivedData` — es lo que
peor se comporta. `sudo tmutil disablelocal`, la recomendacion clasica para
liberar snapshots locales, **no existe desde High Sierra (10.13)**; esto es
el reemplazo real.

El script excluye de Spotlight (`.metadata_never_index`) y de Time Machine
(`tmutil addexclusion -p`) las rutas que existan de:

- `~/Developer`
- `~/Library/Developer/Xcode/DerivedData`
- `~/Library/Caches`
- `~/.cache`
- `~/go/pkg`
- `~/Library/Containers/com.docker.docker`

No crea directorios — si una ruta no existe, se saltea. También reporta
cuantos snapshots locales huerfanos hay en `/` (sin borrar ninguno): el
comando real para liberarlos es `sudo tmutil thinlocalsnapshots / <bytes> 4`,
una operacion irreversible que este script no toma por vos.

## Qué NO arregla este script

Es la parte que importa mas que la lista de arriba: separar lo que un
`defaults write` puede tocar de lo que no.

- **`mediaanalysisd` y `photoanalysisd`** (analisis de fotos/video en
  background, Visual Look Up, Live Text) no se pueden desactivar sin apagar
  SIP y editar plists del sistema — no soportado, no reversible con
  confianza. Hay reportes de consumo alto (>600% CPU) en Tahoe 26 combinado
  con Xcode. La unica mitigacion soportada es reducir que se indexa (tier 3
  de este script), no desactivar el daemon.
- **`launchctl limit maxfiles` a nivel de sistema** esta bloqueado por SIP
  desde macOS 13.5 — Apple lo confirmo como bug conocido sin fix. El camino
  real para herramientas como Vite que abren muchos file descriptors es
  `ulimit -n` por shell o `setrlimit` por proceso, no un `defaults write`
  global.
- **El techo termico y de memoria del hardware.** En un MacBook Air (sin
  ventilador) o con 8-16 GB de RAM unificada, ningun `defaults write` mueve
  throughput sostenido. Lo que compran estos scripts es latencia de interfaz
  y menos carga de fondo, no mas rendimiento bruto bajo carga sostenida.
- **Apps de terceros en el login.** Suelen pesar mas que cualquier key de
  este script. Auditalas con `osascript -e 'tell application "System Events"
  to get the name of every login item'` — el script no las toca.

## Revertir

Un cambio especifico:

```bash
defaults delete <dominio> <key>
```

Ejemplo — volver a mostrar iconos del desktop:

```bash
defaults delete com.apple.finder CreateDesktop && killall Finder
```

TODO a defaults de fabrica (precaucion: borra TODAS tus preferencias de
usuario de esos dos dominios):

```bash
defaults delete NSGlobalDomain && defaults delete com.apple.finder
```
