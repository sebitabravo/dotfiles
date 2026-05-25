# macOS Defaults

Optimizaciones para macOS Sequoia 15.x y Tahoe 26.x orientadas a developers. **215 defaults write**, 3 defaults delete, 40+ secciones. Cero dependencias. Cero `sudo`.

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
| **Finder** | Extensiones visibles, path completo, barra de estado, sin warning al vaciar papelera, sin .DS_Store en network |
| **Dock** | Auto-hide instantaneo (sin delay), sin animaciones, sin apps recientes, size 48px |
| **Menu Bar** | Auto-hide, clock minimalista (HH:mm), icono Spotlight oculto, spacing compacto |
| **Desktop** | Iconos ocultos — escritorio limpio |
| **Safari / WebKit** | 25+ keys de hardening: sin autofill, sin tracking, developer menu, Web Inspector |
| **Privacidad** | Siri analytics off, diagnostics off, advertising tracking off, apps anonymous usage off |
| **Seguridad** | Screensaver con password inmediato (idle 5 min), Gatekeeper, firewall alerts |
| **Xcode** | Simulator en modo oscuro, build system optimizado |
| **Terminal** | UTF-8 por defecto, sin marcas de linea, shell exit inmediato |
| **Tahoe 26.x** | Liquid Glass sin clutter, AutoFill heuristic disabled |
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

### Sin warning al vaciar papelera

No pide confirmacion al vaciar la papelera. Mas agil, pero un click accidental y perdes todo.

```bash
defaults write com.apple.finder WarnOnEmptyTrash -bool false
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
