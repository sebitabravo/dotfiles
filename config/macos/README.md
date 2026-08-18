# macOS Defaults

Optimizaciones de macOS orientadas a developers. **265 defaults write**, 3 defaults delete, 54 secciones. Cero dependencias. Cero `sudo`.

Verificado en **Sequoia 15.7.9**. Tahoe 26.x no esta verificado: ahi Launchpad ya no existe (lo absorbio Spotlight) y las keys `springboard-*` pasan a ser no-op.

El script esta reconciliado contra el estado real de la maquina: los valores reflejan como esta configurada hoy, no una propuesta teorica.

## Quick Start

```bash
chmod +x defaults.sh && ./defaults.sh
```

Solo escribe a preferencias de usuario via `defaults write`. Si algo no te gusta, volves atras sin consecuencias. Ningun cambio rompe el ecosistema Apple (Handoff, Continuity, Find My, AirDrop, etc.).

## Que hace

| Area | Que se optimiza |
|---|---|
| **Animaciones** | Ventanas instantaneas, sin rebote elastico, sin anillo de foco animado |
| **Teclado** | Key repeat rapido (2), delay corto (15), Tab navega todos los controles |
| **Finder** | Extensiones visibles, barra de ruta y de estado, panel de vista previa, carpetas primero al ordenar, spring-loading instantaneo, trash auto-clean >30 dias, sin warning al vaciar papelera, sin iconos de discos en el escritorio, sin .DS_Store en network |
| **Dock** | Auto-hide instantaneo (sin delay ni animacion), sin rebote al abrir apps, sin apps recientes, minimizar a slot propio, size 48px |
| **Mission Control** | Escritorios en orden fijo (sin reorden por uso), sin cambio automatico de escritorio |
| **Ventanas** | Doble clic en la barra de titulo = Fill, arrastrar con ctrl+cmd desde cualquier punto, Stage Manager off |
| **Menu Bar** | Clock digital 24h, barra minima (solo reloj + Control Center), icono Spotlight oculto |
| **Desktop** | Iconos visibles en el Finder pero ocultos mientras trabajas (WindowManager) |
| **Trackpad** | Tap to click, click derecho con dos dedos, arrastre con tres dedos, swipes de espacios con cuatro dedos |
| **Region** | Metrico, Celsius, semana desde el lunes, fecha corta ISO (y-MM-dd) |
| **Safari / WebKit** | 30+ keys: sin tracking ni search suggestions, pop-ups bloqueados, fraudulent website warning, extensiones auto-update, thumbnail cache off, Debug menu, Web Inspector. **AutoFill esta ACTIVO** (incluye contrasenas y tarjetas) |
| **Privacidad** | Siri analytics off, diagnostics off, apps anonymous usage off. **El identificador de publicidad (IDFA) esta ACTIVO** |
| **Security** | Screensaver password immediate (idle 5 min), Terminal Secure Keyboard Entry |
| **Software Update** | Check diario, auto-descarga, auto-instalar updates criticos de seguridad y system data files |
| **App Store** | Debug menu, auto-update apps + auto-restart |
| **Activity Monitor** | Todos los procesos visibles, refresh 2s, sort por CPU |
| **Xcode** | Debug menu, file extensions, parallel build (max cores), numeric progress, no state restoration |
| **Terminal** | UTF-8 only, Secure Keyboard Entry, no line marks |
| **Accessibility** | Ctrl+Scroll = zoom de pantalla, navegacion completa por teclado (Tab llega a todos los controles) |
| **Tahoe 26.x** | Reduce Transparency (Liquid Glass GPU relief ~15-20% WindowServer CPU) |
| **Mail** | Sin animaciones al responder/enviar, copy email sin nombre, texto plano por defecto, inline attachments off |
| **Varios** | Quick Look text selection, Mission Control sin reorden, Launchpad, Trackpad, Sound, Calendar, Help Viewer, Notification Center, App Store, Spotlight suggestions off |

## Minimalismo Extremo (Opcional)

Si querés un sistema ultra-minimalista, ejecuta estos comandos adicionales. No estan en el script principal porque rompen comportamiento esperado de macOS o funcionalidad que la mayoria de los usuarios necesita.

### Menu bar auto-hide

La menu bar desaparece hasta que pasas el mouse arriba. Mas espacio vertical, pero desorienta al principio.

```bash
defaults write NSGlobalDomain _HIHideMenuBar -bool true
killall SystemUIServer
```

### Key repeat sin menu de acentos

Mantener tecla repite el caracter en vez de mostrar el menu de acentos. Util para developers, frustrante para usuarios que escriben en español.

```bash
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
```

### Screenshot sin thumbnail flotante

La captura se guarda directo a disco sin preview editable. Mas rapido, pero no podes editar ni compartir al instante.

```bash
defaults write com.apple.screencapture show-thumbnail -bool false
```

---

## Revertir

Para revertir un cambio especifico:

```bash
defaults delete <domain> <key>
```

Ejemplo — volver a mostrar iconos del desktop:

```bash
defaults delete com.apple.finder CreateDesktop && killall Finder
```

Para revertir TODO a defaults de fabrica (precaución: borra TODAS tus preferencias de usuario):

```bash
defaults delete NSGlobalDomain && defaults delete com.apple.finder
```

---

## Recomendaciones con sudo

Estas optimizaciones requieren `sudo` — no estan en el script principal porque estan fuera del alcance sin password. Son seguras, no rompen el ecosistema Apple, y cada una tiene un camino claro de vuelta atras.

### Ya configurado en esta maquina

Verificado el 2026-08-15 en Sequoia 15.7.9. No hace falta volver a revisarlos:

| Control | Estado | Como se verifica |
|---|---|---|
| FileVault | On | `fdesetup status` |
| Firewall | Enabled | `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` |
| SIP | Enabled | `csrutil status` |
| Gatekeeper | assessments enabled | `spctl --status` |
| Touch ID para sudo | Configurado | `[ -f /etc/pam.d/sudo_local ]` |
| Bloqueo de pantalla | Inmediato | `sysadminctl -screenLock status` |

### Developer mode para debugging

Sin esto, Xcode y las herramientas de debug piden autenticacion cada vez que se
adjuntan a un proceso. Hoy esta desactivado (`DevToolsSecurity -status`).

```bash
sudo DevToolsSecurity -enable
```

**Revertir:** `sudo DevToolsSecurity -disable`

**Impacto ecosistema Apple:** Ninguno. Solo evita el prompt repetido de
autenticacion al usar el debugger; no baja Gatekeeper ni SIP.

### Firewall + Stealth Mode

El firewall de macOS viene apagado por defecto. Prendelo junto con stealth mode (no responde pings, invisible en la red):

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off  # permite conexiones salientes normales
```

**Revertir:** `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off`

**Impacto ecosistema Apple:** Ninguno. Handoff, AirDrop, Continuity siguen funcionando (usan AWDL, no TCP/IP). Lo unico que hace es bloquear conexiones entrantes no solicitadas.

### Desactivar servicios remotos

SSH y Apple Events remotos suelen venir apagados, pero verifica:

```bash
sudo systemsetup -setremotelogin off       # SSH apagado
sudo systemsetup -setremoteappleevents off # Apple Events remotos apagados
```

**Revertir:** `sudo systemsetup -setremotelogin on`

**Impacto ecosistema Apple:** Ninguno. Apple Events remotos estan deprecados desde Mojave y vienen off por defecto. Si usas SSH para desarrollo, deja `remotelogin on`.

### Wake on network y proximity wake

Evita que tu Mac se despierte solo por paquetes de red o dispositivos cercanos:

```bash
sudo pmset -a womp 0           # wake on network access off
sudo pmset -a proximitywake 0  # wake from nearby devices off
```

**Revertir:** `sudo pmset -a womp 1` / `sudo pmset -a proximitywake 1`

**Impacto ecosistema Apple:** `womp 0` no afecta Find My (usa Find My network, no WoL). `proximitywake 0` desactiva que Watch/iPhone despierten tu Mac al acercarse — si usas Apple Watch para desbloquear, quiza queres dejarlo en 1.

### FileVault (verificar)

Probablemente ya esta activo. Verifica:

```bash
sudo fdesetup status
```

Si dice `FileVault is Off`:

```bash
sudo fdesetup enable
```

**Revertir:** `sudo fdesetup disable` (tarda horas en desencriptar)

**Impacto ecosistema Apple:** Ninguno. FileVault es transparente con el Secure Enclave (T2/Apple Silicon). iCloud y Find My funcionan normalmente.

### Gatekeeper y Secure Token (verificar)

Gatekeeper bloquea apps no firmadas. Secure Token confirma que tu cuenta puede desbloquear FileVault. Son verificaciones de solo lectura, no cambian nada:

```bash
spctl --status                        # Gatekeeper: "assessments enabled"
sudo sysadminctl -secureTokenStatus $(id -un)  # Secure Token: "ENABLED"
```

**Revertir:** No aplica. Son comandos de solo lectura.

**Impacto ecosistema Apple:** Ninguno. Solo verifican el estado de seguridad actual.

### Touch ID para sudo — metodo oficial Apple

Permite autenticar `sudo` con huella digital en vez de password. Usa el mecanismo oficial `sudo_local` de Apple que **sobrevive updates de macOS** (Sonoma 14+, Sequoia, Tahoe). No es el viejo hack de `pam_tid.so` directo en `/etc/pam.d/sudo` que se reseteaba en cada update.

```bash
# Idempotente: no sobreescribe si ya existe (respeta configuracion custom)
if [ -f /etc/pam.d/sudo_local.template ] && [ ! -f /etc/pam.d/sudo_local ]; then
  sed 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local > /dev/null
  echo "Touch ID para sudo activado (sudo_local)."
else
  echo "Touch ID para sudo ya configurado o no disponible (requiere macOS 14+)."
fi
```

**Revertir:** `sudo rm /etc/pam.d/sudo_local`

**Impacto ecosistema Apple:** Ninguno. Es soporte oficial de Apple documentado en la changelog enterprise de Sonoma.

**Compatibilidad con herramientas de desarrollo:**

| Herramienta | Compatible? | Nota |
|---|---|---|
| Terminal.app, VS Code, Warp | Si, nativo | Funcionan sin configuracion extra |
| iTerm2 | Si, requiere toggle | Preferences > Advanced > "Allow sessions" > cambiar de "Yes" a "No" |
| tmux | Si, requiere `pam-reattach` | `brew install pam-reattach`. Agregar `auth optional /opt/homebrew/lib/pam/pam_reattach.so` antes de `pam_tid.so` en `sudo_local` |
| SSH / scripts / CI | Si, sin cambios | `pam_tid.so` usa flag `sufficient`: si no hay GUI, falla silenciosamente y cae a password |
| DisplayLink docks | Si, requiere fix | `defaults write com.apple.security.authorization ignoreArd -bool TRUE` |
| Macs sin Touch ID (iMac, Mini, Studio) | Si, sin cambios | `pam_tid.so` detecta que no hay sensor y cae a password automaticamente |
| MacBook en clamshell (sin teclado externo Touch ID) | Si, delay minusculo | ~1-2s de timeout intentando el sensor, luego cae a password |
| Grabacion de pantalla activa (OBS, Zoom, CleanShot) | Si, sin cambios | Touch ID se desactiva intencionalmente (seguridad) y cae a password |

**Nota para tmux:** `pam_reattach` re-conecta la sesion tmux al GUI bootstrap namespace para que Touch ID funcione. Sin esto, Touch ID falla silenciosamente y sudo usa password. No es obligatorio — si no usas tmux, no necesitas `pam_reattach`.

### No dormir mientras esta enchufado

Evita que la Mac duerma durante builds largas o procesos de servidor mientras esta conectada al cargador:

```bash
sudo pmset -c sleep 0
```

**Revertir:** `sudo pmset -c sleep 1`

**Impacto ecosistema Apple:** Ninguno. Solo aplica con corriente (`-c` = charger). En bateria se comporta normal.

### Liberar espacio de snapshots locales de Time Machine

Las snapshots locales en el SSD interno pueden consumir 20-60+ GB. Con artifacts de desarrollo (`node_modules`, builds) explotan de tamaño:

```bash
sudo tmutil disablelocal
```

**Revertir:** `sudo tmutil enablelocal`

**Impacto ecosistema Apple:** No perdes los backups regulares de Time Machine cuando conectas el disco. Solo desactiva las snapshots locales que se crean cuando el disco de backup no esta.

### Modos HiDPI para monitores 4K

Desbloquea resoluciones escaladas (HiDPI) en monitores 4K externos. Sin esto, algunos monitores solo muestran texto minusculo (nativo) o borroso (pixel-doubled):

```bash
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true
```

**Revertir:** `sudo defaults delete /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled`

**Impacto ecosistema Apple:** Ninguno. Solo habilita modos que el hardware ya soporta.

### Login screen muestra IP y hostname

Clickeando el reloj en la pantalla de login, ves IP, hostname y version de macOS. Util para SSH sin loguearte:

```bash
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
```

**Revertir:** `sudo defaults delete /Library/Preferences/com.apple.loginwindow AdminHostInfo`

**Impacto ecosistema Apple:** Ninguno. El acceso fisico a la pantalla de login ya es game-over de todas formas.

### Auto-restart en freeze o perdida de energia

La Mac se reinicia automaticamente si el sistema se congela o si hay un corte de luz y vuelve:

```bash
sudo systemsetup -setrestartfreeze on
sudo pmset -a autorestart 1
```

**Revertir:** `sudo systemsetup -setrestartfreeze off` / `sudo pmset -a autorestart 0`

**Impacto ecosistema Apple:** Ninguno.

### Hacer visible /Volumes en Finder

Util para debuggear mounts, discos externos, DMGs y Docker volumes:

```bash
sudo chflags nohidden /Volumes
```

**Revertir:** `sudo chflags hidden /Volumes`

**Impacto ecosistema Apple:** Ninguno.

### Desactivar Bonjour multicast advertisements

CIS Benchmark Level 1. Reduce ruido de red y superficie de ataque. No rompe AirDrop ni AirPlay (usan AWDL, que es distinto de mDNS multicast):

```bash
sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool YES
sudo killall mDNSResponder
```

**Revertir:**
```bash
sudo defaults delete /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements
sudo killall mDNSResponder
```

**Advertencia:** Algunas apps de descubrimiento local (servidores DLNA, impresoras Bonjour, Home Assistant discovery) pueden dejar de detectar dispositivos. Si usas apps que dependen de Bonjour para encontrar cosas en tu red local, no lo actives.
