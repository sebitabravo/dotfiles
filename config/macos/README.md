# macOS Defaults

Optimizaciones de macOS orientadas a developers. Cero dependencias externas.

Verificado en **Sequoia 15.7.9**, **Tahoe 26.6.2** y **Golden Gate 27.0**
(arm64). El script corre en las tres: lo que cambio entre versiones esta detras
de un guard por version, ninguna optimizacion se removio. Las keys
`springboard-*` de Launchpad se escriben solo hasta Sequoia, porque Tahoe saco
Launchpad del sistema y 27 no lo trajo de vuelta, y Reduce Transparency se
salta hasta 26.2, la ventana donde Apple la tuvo rota antes de arreglarla en
26.3.

El script esta reconciliado contra el estado real de la maquina: los valores
reflejan como esta configurada hoy, no una propuesta teorica.

## Quick Start

```bash
chmod +x defaults.sh && ./defaults.sh --dry-run   # revisar antes de aplicar
./defaults.sh                                     # aplicar de verdad
../../.github/verify.sh                           # auditar el resultado (desde config/macos/)
```

Que significa cada marca, con precision — esto decia antes que `[SKIP]` era
"ya estaba asi", y no es cierto para la mayoria de los items:

| Marca | Que significa de verdad |
|---|---|
| `[SET]` | El `defaults write` devolvio exito. **No** implica que el valor haya cambiado: en una maquina ya configurada casi todo sale `[SET]` igual, porque escribir el mismo valor tambien es exito. |
| `[SKIP]` | Un guard decidio no ejecutar: guard por version de macOS, guard de estado del Tier 2, ruta inexistente en el Tier 3, o key ya ausente en un `defaults delete`. |
| `[FAIL]` | El write no tuvo efecto (ej: dominio protegido por TCC sin Full Disk Access). Suma al exit code. |
| `[WARN]` | Verificacion de solo lectura que encontro algo que revisar a mano. |
| `[--]` | Informativo: estado declarado, sin accion posible o sin accion deseada. |

Para saber si hay **drift** no sirve mirar los `[SET]`: para eso esta
`verify.sh`, que no escribe nada, compara el estado real contra lo que el
script promete y sale con `1` si algo no coincide.

### Despues de formatear: el orden importa

Tres bloques del script son **dependientes del orden** y en una Mac recien
formateada se saltan solos, en silencio, sin que nada falle. Correrlo una sola
vez apenas termina el formateo deja esas partes sin aplicar:

| Bloque | Por que se salta en una Mac nueva | Que necesita antes |
|---|---|---|
| Safari (~30 keys) | La terminal no tiene Full Disk Access, y el canario lo detecta | Ajustes > Privacidad y Seguridad > Acceso total al disco, agregar la terminal y reabrirla |
| Tier 3 (Spotlight + Time Machine) | `~/Developer`, `~/.cache` y `~/go/pkg` todavia no existen | Clonar los repos y correr los toolchains al menos una vez |
| VS Code press-and-hold | `/Applications/Visual Studio Code.app` no existe | Instalar VS Code (lo trae el `Brewfile`) |

Orden recomendado tras un formateo:

```bash
# 1. Bootstrap del repo (NO aplica defaults.sh, es deliberado)
./install.sh

# 2. Dar Full Disk Access a la terminal y reabrirla, si no el bloque
#    Safari se saltea entero

# 3. Primera pasada: todo menos lo que depende de directorios que aun no estan
cd config/macos && ./defaults.sh

# 4. Clonar repos, correr los toolchains, dejar que ~/Developer y ~/.cache
#    existan de verdad

# 5. Segunda pasada: ahora si aplica el Tier 3
./defaults.sh

# 6. Auditar
../../.github/verify.sh
```

El paso 5 no es opcional: sin el, las exclusiones de Spotlight y Time Machine
—que son la unica ganancia de rendimiento medible del script— nunca se
aplican. El script avisa al final del Tier 3 cuando quedaron rutas pendientes.

Lo que **ningun** script arregla despues de un formateo, y hay que hacer a
mano: activar FileVault (genera la llave de recuperacion, no se automatiza),
configurar un destino de Time Machine, poner el receptor de AirPlay en
"Usuario actual", y la checklist de GUI del final de este documento.

### Despues de un upgrade de major: que se cae y que no

Un upgrade de major **no** reescribe los plists de usuario en masa. Medido
sobre el salto de Tahoe 26.6.2 a Golden Gate 27.0 en esta maquina, de 10 keys
muestreadas del script sobrevivieron 9: animaciones de Dock y Finder,
`mru-spaces`, `reduceTransparency`, `AppleShowAllExtensions`, el thumbnail de
capturas y las animaciones de Mail quedaron todas como estaban.

La que se cae es **el identificador de publicidad**:

```
com.apple.AdLib allowIdentifierForAdvertising = 1   # el script lo pone en 0
com.apple.AdLib auto_opt_in                   = 1
com.apple.AdLib opted_in_buddy                = 1
```

`opted_in_buddy` es la pista: "Buddy" es el asistente de configuracion que
corre despues de instalar una major. Ese flujo te vuelve a inscribir en
anuncios personalizados y pisa la preferencia, sin preguntar de nuevo de forma
visible. No es un bug del script: es el instalador de macOS ganandole al
ultimo write.

Por eso, despues de cada upgrade de major:

```bash
./defaults.sh              # reaplica todo, idempotente
../../.github/verify.sh    # confirma que no quedo drift
```

Tambien conviene mirar el disco: macOS 27 **reconstruye el indice de Spotlight
entero** tras el upgrade, y durante las primeras 24-48 horas Spotlight, Photos
y la descarga de modelos de Apple Intelligence compiten por CPU, disco y
bateria. Es trabajo de una vez, no una regresion — pero es justo cuando las
exclusiones del Tier 3 pagan mas, asi que vale correr el script antes de
empezar a compilar.

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
| **Finder** | Extensiones visibles, barra de ruta y de estado, panel de vista previa, carpetas primero al ordenar, spring-loading instantaneo, trash auto-clean >30 dias, sin warning al vaciar papelera, sin iconos de discos en el escritorio (preferencia personal), sin .DS_Store en network |
| **Dock** | Auto-hide instantaneo (sin delay ni animacion), sin rebote al abrir apps, sin apps recientes, minimizar a slot propio, size 36px |
| **Mission Control** | Escritorios en orden fijo (sin reorden por uso), sin cambio automatico de escritorio, ventanas agrupadas por app |
| **Ventanas** | Doble clic en la barra de titulo = Fill, arrastrar con ctrl+cmd desde cualquier punto, Stage Manager off, tiling solo con Option (ver abajo), login sin reabrir ventanas ni relanzar apps (drift-control, ver abajo) |
| **Menu Bar** | Clock digital 24h, barra minima (solo reloj + Control Center), icono Spotlight oculto, auto-hide de la barra completa (preferencia personal, ver abajo) |
| **Desktop** | Iconos visibles en el Finder pero ocultos mientras trabajas, y sin iconos de volumenes montados (preferencia personal, ver abajo) |
| **Trackpad** | Tap to click, click derecho con dos dedos, arrastre con tres dedos, swipes de espacios con cuatro dedos |
| **Region** | Metrico, Celsius, semana desde el lunes, fecha corta ISO (y-MM-dd) |
| **Safari / WebKit** | ~30 keys: sin tracking ni search suggestions, pop-ups bloqueados, fraudulent website warning, extensiones auto-update, thumbnail cache off, Debug menu, Web Inspector. **AutoFill esta ACTIVO** (incluye contrasenas y tarjetas) — es funcionalidad principal de macOS, no se toca. Se salta entero si la terminal no tiene Full Disk Access (ver mas abajo). |
| **Privacidad** | Siri analytics off, dictado off, diagnostics off, apps anonymous usage off, IDFA desactivado |
| **Security** | Screensaver password immediate (idle 5 min), Terminal Secure Keyboard Entry |
| **Software Update** | Check diario, auto-descarga, auto-instalar updates criticos de seguridad y system data files |
| **App Store** | Debug menu, auto-update apps + auto-restart |
| **Activity Monitor** | Todos los procesos visibles, refresh 2s, sort por CPU |
| **Xcode** | Debug menu, file extensions, parallel build (max cores), numeric progress, no state restoration, duracion del build visible (`ShowBuildOperationDuration`, util para notar thermal throttling en un fanless) |
| **Terminal** | UTF-8 only, Secure Keyboard Entry, no line marks |
| **Accessibility** | Ctrl+Scroll = zoom de pantalla, navegacion completa por teclado (Tab llega a todos los controles) |
| **Transparencia** | Reduce Transparency (alivio de GPU en WindowServer). Se salta hasta Tahoe 26.2, donde la key estaba rota (26.1 y 26.2 estan documentados; 26.0 entra por precaucion); desde 26.3 se aplica. Activarla deshabilita el selector Clear/Tinted de Ajustes > Apariencia: son mutuamente excluyentes. El fix de 26.3 es **parcial** — ver abajo. |
| **Tahoe 26** | Thumbnail flotante de capturas desactivado (en Tahoe pierde la captura si se cancela una accion sobre el). |
| **Mail** | Sin animaciones al responder/enviar, copy email sin nombre, texto plano por defecto, inline attachments off |

### Ecosistema Apple: que esta verificado sano y que tiene costo

Esta config asume que la Mac vive dentro del ecosistema Apple. Se audito
entera buscando cosas que lo degraden. Resultado:

**Handoff y Portapapeles Universal: intactos, verificado.** Existia la sospecha
de que `NSUserActivityLoggingEnabled -bool false` los rompia. No lo hace: las
keys que gobiernan Handoff viven en `com.apple.coreservices.useractivityd`
(`ActivityAdvertisingAllowed`, `ActivityReceivingAllowed`,
`ClipboardSharingEnabled`) y esta config no las escribe. Con las tres ausentes,
Handoff esta encendido.

**Apple Intelligence y AirPlay Receiver: no se tocan.** Son funciones del
ecosistema que aca se usan. El script tampoco avisa sobre ellas — un aviso que
se repite cada corrida y no se puede seguir es ruido, no seguridad. Vale saber
que AirPlay Receiver ocupa los puertos 5000 y 7000, asi que si un server local
no puede tomar el 5000, la causa es esa.

**`tcpkeepalive` queda en 1 y no debe bajarse.** En 0 rompe Find My y las push
notifications mientras la Mac duerme.

**`powernap 0` y `womp 0` son dos decisiones distintas, no una.** Se escriben
juntas pero cuestan cosas diferentes.

`powernap 0`: la Mac dormida no despierta a sincronizar iCloud/Mail ni a correr
Time Machine. Sin destino de Time Machine configurado y con un iPhone al lado,
no cuesta nada concreto. Revertir: `sudo pmset -a powernap 1`.

`womp`: **apagado se pierden el bloqueo y el borrado remotos** mientras la Mac
duerme. macOS lo dice literal — *"You won't be able to locate, lock, or erase
this Mac while it's asleep because Wake for network access is turned off"*.

Por eso va **separado por fuente**, igual que `lowpowermode`: el costo de
apagarlo solo se paga donde despertar cuesta algo.

| Fuente | Valor | Por que |
|---|---|---|
| AC (`-c womp 1`) | encendido | Enchufada no hay bateria que preservar, y es lo que habilita lock/erase remoto |
| Bateria (`-b womp 0`) | apagado | Una Mac desatendida en una mochila no deberia despertar por cada paquete unicast |

Revertir: `sudo pmset -c womp 0` (AC) o `sudo pmset -b womp 1` (bateria).

Detalle de hardware: `pmset -g cap` imprime **solo la fuente activa**. Con
bateria muestra `Capabilities for Battery Power:` (verificado en este M3 Air
descargando: incluye `womp`); con cargador muestra la de AC. `womp` existe en
ambas, y `pmset -b womp 0` persiste (visible en `pmset -g custom`) y es
funcional: es lo que apaga el wake por red cuando no hay enchufe.

**Ubicar la Mac en Buscar NO depende de ninguna de las dos.** Find My usa un
mecanismo aparte (Search Party): la Mac emite beacons Bluetooth cifrados que
recogen otros equipos Apple cercanos, y eso funciona dormida. El limite real es
el estado de energia — una Mac **apagada del todo** no se encuentra, porque
Apple Silicon no tiene el beacon en apagado que si tiene un AirTag. Ese beacon
solo reporta posicion: no puede recibir una orden, y por eso bloquear o borrar
si necesitan `womp`.

Con FileVault activo los datos ya son ilegibles sin la password, asi que el
borrado remoto es defensa en profundidad, no el control principal.

**Costo menor: Siri apagado en la Mac.** `Assistant Enabled = 0` y
`CoreDonationsEnabled = 0`. Si usas Siri en iPhone, Watch o HomePod, la Mac es
el unico equipo que no responde, y las sugerencias no se comparten entre
dispositivos. Es deliberado, pero es un hueco en un ecosistema activo.

### Regla de compatibilidad: la palabra clave es "en silencio"

Este es un repo personal y sus preferencias no le deben neutralidad a nadie.
La regla no es "no cambies lo que el usuario espera" — es **no lo cambies en
silencio**.

Un ajuste de gusto que rompe una expectativa es legitimo si esta declarado y
trae su comando para revertirlo. Por eso los cuatro de la seccion de abajo
siguen activos: cambian cosas fuertes, pero cualquiera que copie el repo puede
verlos listados y sacar solo esos. Lo que no vale es que alguien pierda una
funcion conocida sin forma de saber que fue el script.

Esto pesa mas si la config la usa alguien que recien llega a macOS desde
Windows o Linux: esa persona no tiene como distinguir "macOS es asi" de "un
script me lo saco".

Distinto es cuando **ni el script sabe** que esta decidiendo. El caso que fijo
la regla fueron los **widgets de escritorio**, ocultos con
`StandardHideWidgets` porque Tahoe los activa solo tras el upgrade. Ahi
`defaults read` no distingue "Tahoe me lo prendio sin preguntar" de "lo uso
todos los dias", asi que la key se removio del script: no era una preferencia
declarada, era una suposicion. Se gestionan en Ajustes > Escritorio y Dock >
Mostrar widgets.

**Lo que NO se toca a proposito:** las animaciones de ventanas y apps quedan
en su comportamiento stock — este script es para developers que necesitan ver
las animaciones de las apps que construyen. AutoFill de Safari tampoco se
toca: es la funcionalidad principal, no bloat.

### macOS 27 Golden Gate: que cambia y que no se agrego

27.0 salio el 14 de septiembre de 2026. Lo que importa para este script:

- **Reduce Transparency sigue viva.** No se deprecio ni se renombro: verificado
  leyendo `com.apple.universalaccess` en una 27.0 real, la key esta y vale `1`.
  El guard de la ventana rota es `MACOS_MAJOR -eq 26`, no `-ge 26`, asi que en
  27 la key se vuelve a escribir. Hay un test que mata ese mutante justo.
- **El slider de Liquid Glass no la reemplaza.** 27 agrega en Ajustes >
  Apariencia un slider continuo de opacidad, que sustituye al par Clear/Tinted
  de Tahoe. Solo tinta menus, Control Center, Notification Center, Spotlight,
  toolbars y sidebars; no toca la barra de menus, el Dock ni los iconos del
  Finder. Reduce Transparency aplana mas que el extremo del slider, asi que
  siguen siendo cosas distintas y la de Accesibilidad es la que sirve aca.
- **No se le agrego ninguna key nueva al script.** Ese slider no tiene key
  publica documentada — no aparece en `defaults read -g` ni en
  `com.apple.universalaccess` hasta que lo movas a mano — y las unicas keys
  nuevas que circulan (`NSSplitViewItemSidebarDefaultsToFloatingAppearance`,
  `NSConvolutionOverride1`) salen de hilos de foro sobre las betas, son
  cosmeticas y no tienen fuente estable. Este script no escribe keys que no
  puede verificar.
- **Lo que si conviene mirar**: 27 mueve comportamiento a feature flags bajo
  `/Library/Preferences/FeatureFlags/Domain/`. Es un dominio de sistema que
  Apple usa para prender y apagar features entre builds; escribir ahi a ciegas
  es exactamente el tipo de cosa que este script no hace.

#### Contraste contra mSCP release_27.0

El macOS Security Compliance Project (NIST, `usnistgov/macos_security`) es la
fuente autoritativa de hardening y ya publico `release_27.0`, que ademas trae
el CIS Benchmark y el DISA STIG prerelease para macOS 27. Dejo de usar ramas
por version: todo vive en `main`.

Sus reglas nuevas para 27 son, segun su propio CHANGELOG:
`os_bluetooth_modification_disable`, `os_chat_disable`,
`os_call_recording_disable`, `system_settings_siri_AI_disable`,
`os_apple_intelligence_pcc_disable`, `os_visual_intelligence_disable`,
`os_natural_language_editing_disable`, `os_allow_enterprise_trust_disabled`,
`os_install_configuration_profile_disable`,
`os_erase_contents_and_settings_disable` y tres `*_familycontrols`.

**Ninguna se puede aplicar con `defaults write`.** Se verifico leyendo los
YAML: son DDM (declarative device management) o perfiles `.mobileconfig` y
necesitan inscripcion MDM. `system_settings_siri_ai_disable`, por ejemplo,
declara dominio `com.apple.ironwood.support` con la key `allowSiri3489`, y su
verificacion literal es "abrir Ajustes > General > Gestion de dispositivos y
revisar las Device Declarations". En un laptop personal sin MDM eso no existe.

Conclusion: para esta maquina, macOS 27 **no aporta ninguna key nueva
aplicable**. Lo que si se puede decidir a mano es si queres Apple Intelligence
encendido — Ajustes > Apple Intelligence y Siri — porque en 27 descarga
modelos y corre analisis en background. En esta maquina Siri ya esta apagado
(`com.apple.assistant.support "Assistant Enabled" = 0`).

Sobre CIS: el benchmark de Tahoe paso a **v1.1.0**, pero fue una pasada de
mantenimiento sin agregar ni quitar controles (0 fixlets nuevos, 0 borrados, 4
actualizados sobre 105). Los numeros que cita este README siguen validos.

### Reduce Transparency: el fix de 26.3 no esta completo

Apple arreglo en 26.3 lo que rompio en 26.1 y 26.2, y ni lo documento en las
release notes. Pero el arreglo es parcial: los sidebars y las toolbars vuelven
a ser opacos, y aun asi **la toolbar y sus botones siguen mal definidos salvo
que tambien se active Increase Contrast** (`com.apple.universalaccess
increaseContrast`). Siri tambien se sigue viendo mal con Reduce Transparency
encendido.

Este script **no** escribe `increaseContrast`: es un cambio visual fuerte
(bordes marcados en toda la interfaz) y es preferencia, no seguridad. Queda
declarado aca para que la decision sea informada — si vas a usar Reduce
Transparency en Tahoe, esa es la otra mitad:

```bash
defaults write com.apple.universalaccess increaseContrast -bool true
```

Al reves tambien vale: si lo que te importa es el diseño de Liquid Glass,
Reduce Transparency es justo lo que te lo saca, y sacarla es una linea:

```bash
defaults delete com.apple.universalaccess reduceTransparency
```

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

### Preferencias personales — que borrar si copias esta config

Esta es una configuracion personal, no un producto neutro. Los cuatro ajustes
de abajo son **gusto**, no optimizacion ni seguridad: cambian cosas que un
usuario de macOS reconoce al instante. Van activados a proposito porque asi
trabaja quien mantiene el repo.

Se listan aparte por una sola razon: para que sepas cuales son opinion y cuales
son mejoras reales, y puedas sacar estas sin tocar el resto. Cada una se
revierte sola, no hay que abandonar el script entero.

| Preferencia | Que vas a notar | Sacarla |
|---|---|---|
| `com.apple.swipescrolldirection` | Scroll invertido. Apple usa scroll natural desde Lion (2011): si venis de macOS, el trackpad se va a sentir al reves. | `defaults delete NSGlobalDomain com.apple.swipescrolldirection` |
| `_HIHideMenuBar` | La barra de menu se esconde hasta que subis el mouse. Ningun Mac sale asi de fabrica. | `defaults delete NSGlobalDomain _HIHideMenuBar` |
| `HideDesktop` + `StandardHideDesktopIcons` | Los iconos del escritorio no se ven mientras trabajas. Siguen en el Finder, no se borro nada. | `defaults delete com.apple.WindowManager HideDesktop` |
| `Show*OnDesktop` (x3) | **La mas fuerte:** un pendrive se monta pero **no aparece en el escritorio**. Hay que buscarlo en la sidebar del Finder. | `defaults delete com.apple.finder ShowExternalHardDrivesOnDesktop` y `ShowRemovableMediaOnDesktop` |

Sobre la ultima vale un detalle tecnico: los defaults de Apple **no son
uniformes**. El disco interno ya viene oculto de fabrica, pero externos, CD/DVD
y servidores conectados vienen visibles. Esta config oculta los tres, asi que
si te desaparece un USB del escritorio es esto y no un puerto roto.

Despues de cualquiera de esos `defaults delete`, corre `killall Finder Dock
SystemUIServer WindowManager` o cierra sesion.

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
y nunca se ejecutaba. Ahora esta dentro de `defaults.sh`: todo el tier corre
en **una sola sesion root** (`sudo bash` con heredoc) y tu password se pide
**una sola vez** al inicio del tier. Se salta completo con `--no-sudo`.

Por que una sola sesion: con `timestamp_timeout=0` instalado, **cada `sudo`
suelto re-pide password por diseño** (CIS 5.4) — N invocaciones sueltas son N
prompts aunque el timestamp este caliente, y calentar con `sudo -v` ya no
ayuda. Una sola invocacion de `sudo` es un solo prompt. Ojo: esto vale dentro
del script; **ad-hoc sudo fuera del script sigue pidiendo password cada vez
mientras el drop-in exista, por diseño**.

| Item | Aplica si... | Revertir |
|---|---|---|
| Developer mode | `DevToolsSecurity -status` dice disabled | `sudo DevToolsSecurity -disable` |
| Power Nap off | esta en 1 (AC o bateria) | `sudo pmset -a powernap 1` |
| Wake for network | `womp` no esta en 1 (AC) o en 0 (bateria) | `sudo pmset -c womp 0` (AC) / `sudo pmset -b womp 1` (bateria) — nunca `-a`, que aplasta el split |
| Wake por proximidad | siempre fija `proximitywake 1` | `sudo pmset -a proximitywake 0` |
| Auto-restart en freeze/corte de luz | no esta configurado | `sudo pmset -a autorestart 0` + `sudo systemsetup -setrestartfreeze off` |
| SSH remoto apagado | esta prendido | `sudo systemsetup -setremotelogin on` — dejalo prendido si lo usas para desarrollo |
| NTP en time.apple.com | hora de red apagada o contra otro servidor | `sudo systemsetup -setusingnetworktime off` (o `-setnetworktimeserver` con otro) |
| Banner de login (plantilla equipo extraviado, personalizar con `LOGIN_BANNER="..."` o editar el default; usar email secundario, nunca el Apple ID) | `LoginwindowText` ausente | `sudo defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText` |
| Sudo sin grace period (dentro de la sesion root unica) | `timestamp_timeout` ya fijado en sudoers | `sudo rm /etc/sudoers.d/10_cis_timestamp_timeout` (cada sudo vuelve a pedir password mientras exista) |
| Login Window muestra hostname | `AdminHostInfo` no es `HostName` | `sudo defaults delete /Library/Preferences/com.apple.loginwindow AdminHostInfo` |
| Pistas de password apagadas (CIS 2.11.5) | `RetriesUntilHint` no es `0` | `sudo defaults delete /Library/Preferences/com.apple.loginwindow RetriesUntilHint` |
| Touch ID para sudo | `/etc/pam.d/sudo_local` no existe | `sudo rm /etc/pam.d/sudo_local` |
| `/Volumes` visible en Finder | tiene el flag hidden | `sudo chflags hidden /Volumes` |
| Firewall encendido | esta apagado | `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off` |
| Firewall stealth mode | esta apagado | `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode off` — apagalo si necesitas responder ping desde afuera |
| Firewall permite rapportd | no esta en `--listapps` | `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --remove /usr/libexec/rapportd` |
| Firewall permite sharingd | no esta en `--listapps` | `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --remove /usr/libexec/sharingd` |
| Low Power Mode en bateria | esta en 0 | `sudo pmset -b lowpowermode 0` |
| Low Power Mode apagado en AC | esta en 1 | `sudo pmset -c lowpowermode 1` |

Con firewall + stealth on, `rapportd` (discovery de AirDrop/Handoff) y
`sharingd` (AirDrop/compartir) quedan como excepciones con entrante permitido
(`--add` + `--unblockapp`): preserva AirDrop/Handoff discovery con firewall
on. Se verifica con `socketfilterfw --listapps`.

Low Power Mode se aplica **solo en bateria** (`-b`), y en AC se fuerza apagado
(`-c`). En un fanless capea CPU y GPU: el intercambio conviene con bateria y no
tiene sentido con enchufe, donde solo compraria builds mas lentos.

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

El tier 2 tambien verifica sin escribir el Secure Token y el HiDPI para
monitores 4K (`sudo defaults write
/Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool
true`, solo hace falta con un monitor 4K externo).

### Reapertura al login — drift-control, no optimizacion

```
com.apple.loginwindow TALLogoutSavesState            false
com.apple.loginwindow LoginwindowLaunchesRelaunchApps false
```

Corresponden al checkbox "Reabrir ventanas al volver a iniciar sesion". Estan
aca para que el estado quede declarado en el repo, no porque midan nada.

Lo que **no** son, dicho explicito para que nadie las venda de mas: vienen de
un hack de Lion (2011) y desde 10.7.4 el checkbox persiste solo, asi que
escribirlas puede dejarlo tildado pero inerte. Apple documenta el checkbox
(HT102318) como la forma de evitar el reopen, **no** como mitigacion de los
memory leaks de Tahoe. Que arrancar con menos estado implique menos RAM e IO
es plausible; no esta medido.

Revertir: `defaults delete com.apple.loginwindow TALLogoutSavesState` y lo
mismo con `LoginwindowLaunchesRelaunchApps`.

### Tiling de ventanas — que no dispare solo, pero que siga estando

Los cuatro toggles viven en Ajustes > Escritorio y Dock > Ventanas y vienen
todos encendidos. La configuracion de aca es la que recomiendan TidBITS,
AppleInsider y Computerworld, y **no** es apagarlos todos:

| Key | Valor | Por que |
|---|---|---|
| `EnableTilingByEdgeDrag` | `false` | Arrastrar una ventana cerca de un borde para moverla la acomoda sin que la pidas. Con dos monitores el gesto ocurre cada vez que se pasa una ventana de una pantalla a la otra. |
| `EnableTopTilingByEdgeDrag` | `false` | Lo mismo con el gesto de arrastrar a la barra de menu para maximizar. |
| `EnableTilingOptionAccelerator` | `true` | Se deja **encendido** a proposito: es el disparo deliberado. Apagarlo pierde el tiling entero y no gana nada. |
| `EnableTiledWindowMargins` | `false` | Ventanas pegadas, sin margen entre ellas. |

Resultado: el tiling deja de dispararse por accidente y sigue funcionando
cuando se mantiene Option al arrastrar.

El acelerador se escribe explicito aunque hoy coincida con el default de Apple,
porque estos toggles se reportan volviendo solos despues de updates de macOS.

Revertir: `defaults delete com.apple.WindowManager EnableTilingByEdgeDrag` (y
las otras tres keys), despues `killall WindowManager`.

### Verificacion de seguridad — corre siempre

Vivia dentro del tier 2, asi que `--no-sudo` terminaba sin reportar una sola
linea de seguridad. Ninguna de estas lecturas necesita privilegios, asi que
ahora corren en toda ejecucion: FileVault, firewall, stealth mode, SIP,
Gatekeeper y bloqueo de pantalla.

Se verifican tambien **espacio libre** y **servicios escuchando**.

El espacio se lee de `diskutil apfs list`, no de `df`: `df` reporta contra el
snapshot sellado del sistema y da un numero que no es el que el kernel le
entrega a una app. Avisa bajo 20%, que es heuristica de comunidad para dejar
aire a swap, snapshots de APFS e indexado — Apple no publica un minimo.

El chequeo de listeners existe para que la pregunta "¿importa el firewall en
esta maquina?" se **mida** en vez de asumirse. Con cero procesos escuchando en
todas las interfaces el exposure es teorico; con listeners reales el firewall y
el stealth mode hacen trabajo. Ademas detecta AirPlay Receiver (ControlCenter
en 5000/7000): es la superficie de AirBorne — 23 fallas reportadas por Oligo
Security, de las cuales el RCE zero-click en la misma red sale de encadenar
CVE-2025-24252 (use-after-free) con CVE-2025-24206 (bypass del click de
aceptacion) — y encima ocupa el puerto 5000, que choca con medio servidor de
desarrollo.

El detalle que decide la mitigacion: Oligo documenta que esa cadena **solo
funciona con el receptor en "Cualquier persona en la misma red" o "Todos"**.
Con **"Usuario actual"** no aplica, y AirPlay desde el propio iPhone sigue
andando. Por eso el script recomienda ese modo en vez de apagar el receptor.

Lo que **no** hace ese modo es dejarte a salvo de todo: Oligo dice textual que
cambiar a "Current User" *"does not prevent all of the issues"* — queda al
menos un camino one-click (CVE-2025-24137, parchado en Sequoia 15.3) que
aplica igual. "Usuario actual" cierra el vector grave, no la familia entera;
la defensa real ahi es estar parchado, no el dropdown.

El script lee el modo de `AirplayReceiverAdvertising` (`1` = Usuario actual,
`2` = Cualquiera en la misma red, `3` = Todos, dominio por-host
`com.apple.controlcenter`). Esa key no esta documentada por Apple ni cubierta
por CIS — sale de hilos de Jamf Nation — asi que se **lee** para reportar el
modo y no se escribe: una key no soportada puede cambiar de nombre o de
semantica en cualquier update y dejarte creyendo que aplicaste algo. Se cambia
a mano en Ajustes > General > AirDrop y Handoff > Receptor de AirPlay.

Se verifica tambien que **exista un destino de Time Machine**. Va en este
bloque a proposito: en las guias de hardening el backup queda arriba de
FileVault en la lista de lo que realmente importa, porque FileVault sin backup
no protege los datos — los vuelve irrecuperables si el SSD muere o se pierde la
password. El script no puede configurarlo (necesita un disco o destino de red
real), asi que avisa. Si hay destino, tambien informa frescura (avisa sobre 7
dias sin backup completo) y cifrado cuando tmutil expone el campo; si no lo
expone dice que no lo sabe en vez de inventar. Configurar el destino jamas se
automatiza (`tmutil setdestination` apunta a hardware real).

### La capa que FileVault, SIP y el firewall no cubren

Dos chequeos de solo lectura tapan un hueco que el resto de la config no ve.
Ninguno remedia nada: reportan.

**Directorios world-writable en `/Library`** (CIS Tahoe L2 5.1.7). Un `0777`
sin sticky bit deja que cualquier proceso escriba o reemplace archivos ahi. El
vector no es remoto, es **escalada local**: codigo que ya corre como vos —un
`postinstall` de npm, una app troyanizada— deja un archivo que despues consume
un proceso privilegiado. En una maquina que instala paquetes a diario ese es el
camino realista, y FileVault, SIP y el firewall operan en otra capa.

Los culpables tipicos son instaladores de terceros, no macOS. El caso que
motivo el chequeo:

```
drwxrwxrwx root:wheel  .../Logi/LogiPluginService/LibraryPackagesToInstall
```

Root es el dueño, el nombre dice "paquetes para instalar", y cualquiera escribe
adentro. Se reporta y no se remedia a proposito: bajarle los permisos a un
directorio de un vendor puede romper su software. Se endurece a mano con
`sudo chmod o-w <dir>` despues de mirar quien es el dueño.

**`csrutil authenticated-root`** (Sealed System Volume). El volumen de sistema
esta sellado criptograficamente: cada archivo hashea hacia un hash raiz que el
arranque verifica, y eso es lo que vuelve inviable el rootkit clasico que
reemplaza binarios del sistema. Va junto a SIP y Gatekeeper porque son la misma
familia; sin esta linea el sello era el unico de los tres que nadie miraba.
Solo se apaga a proposito desde Recovery, asi que es un tripwire barato, no una
defensa nueva.

**Por que `DisableFDEAutoLogin` no esta.** CIS lo pide, y se evaluo. Usa la
**misma contraseña** que FileVault, asi que quien pudo desbloquear el disco ya
puede loguearse: lo unico que cubre es la ventana entre desbloquear y llegar al
escritorio. El control esta escrito para maquinas compartidas de empresa; en un
laptop de un solo usuario con Touch ID y bloqueo inmediato de pantalla compra
muy poco a cambio de un prompt extra en cada arranque en frio. Queda anotado
para no volver a discutirlo desde cero.

### Contraste contra CIS Apple macOS 26 Tahoe

El benchmark oficial existe (L1 son ~90 controles) y esta config cubre buena
parte, pero tres huecos se cerraron recien y uno se descarto a proposito:

| Control CIS | Estado aca |
|---|---|
| 2.11.5 Show Password Hints | Se aplica en el Tier 2 (`RetriesUntilHint = 0`) |
| 2.3.3.7 Internet Sharing | Auditado en el bloque de solo lectura |
| 2.3.3.10 Bluetooth Sharing | Auditado en el bloque de solo lectura |
| 2.3.1.2 AirPlay Receiver | Se audita, no se apaga: se usa. Mitigacion = modo "Usuario actual" |
| 2.6.8 Admin password para ajustes del sistema | **Descartado**, ver abajo |
| 2.5.1.x Writing Tools / resumenes de Apple Intelligence | Sin key de usuario: solo payload MDM (`allowWritingTools`) |

**Por que 2.6.8 queda afuera.** El control pide poner `shared = false` en
`system.preferences` via `security authorizationdb`. Modificar authorizationdb
rompe `sysadminctl` y `dsconfigad` cuando corren no interactivos — fallan con
`errAuthorizationInteractionNotAllowed`, lo que ironicamente rompe otras
remediaciones CIS que dependen de `sysadminctl` bajo sudo (issue #574 de
`usnistgov/macos_security`). Ademas hay reportes de que el valor no persiste
desde Big Sur: la GUI sigue mostrando la casilla destildada. Un control que no
se puede verificar y que rompe automatizacion no entra a este script.

Tambien se auditan **sharing, invitado y auto-login**, todo legible sin sudo:
Screen Sharing, Remote Management y Remote Apple Events por ausencia de sus
plists (si aparecen, se revisan en GUI), printer sharing via `cupsctl`,
share points SMB via `sharing -l` (dato informativo: la carpeta Publica sale
compartida por defecto), mas `GuestEnabled` y `autoLoginUser` del loginwindow.
El on/off de File Sharing en si necesita privilegios y queda en Ajustes >
General > Compartir; SSH ya se cubre en el Tier 2.

Cinco de esas siguen siendo un aviso y no una accion, y no es por prudencia
sino porque no hay forma de automatizarlas:

| Item | Por que no se automatiza |
|---|---|
| FileVault | `fdesetup enable` genera una llave de recuperacion. Una corrida no interactiva la descarta, y sin ella un olvido de password deja el disco irrecuperable. |
| SIP | `csrutil enable` responde `This tool needs to be executed from Recovery OS`. |
| Gatekeeper | `spctl --master-enable` dejo de existir en Sequoia (`This operation is no longer supported`). Solo se re-arma desde Ajustes. |
| Bloqueo de pantalla | `sysadminctl -screenLock` exige `-password <password>` en claro. |
| Time Machine | Configurar un destino requiere un disco o servidor real. `tmutil setdestination` existe pero apunta a hardware que el script no puede inventar. |

El firewall si es la excepcion: es aditivo, reversible y scriptable, asi que el
tier 2 lo enciende en vez de limitarse a avisar.

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

### Homebrew autoupdate — opt-in manual (el script no lo toca)

`brew autoupdate` (tap `homebrew/autoupdate`) programa `brew upgrade` via
launchd. Aca es opt-in y manual a proposito: un upgrade automatico puede
cambiar el toolchain en mitad de un trabajo. Si lo queres:

```bash
brew tap homebrew/autoupdate
brew autoupdate start 86400 --upgrade --cleanup
```

Ver `brew autoupdate --help` para mas flags. Revertir: `brew autoupdate stop`
(y `brew untap homebrew/autoupdate` si no lo usas mas). Estado:
`brew autoupdate status`.

## Que hace — Tier 3 (exclusiones de indexado, sin sudo)

La ganancia real en una maquina de desarrollo, y la justificacion es el
tamaño del arbol, no un bug: un solo `node_modules` ronda entre 50.000 y
200.000 archivos chicos, y cada `npm install`, checkout grande, build de
Xcode a `DerivedData` o extraccion de imagen de Docker dispara una rafaga de
eventos de FSEvents que Spotlight persigue con varios `mdworker` en paralelo.

Antes esta seccion decia que Sequoia tenia una "regresion documentada" de
indexado. No la tiene: no hay release note ni radar de Apple, y lo unico
documentado fue un bug de beta que se cerro en la segunda Developer Beta. Las
exclusiones valen igual — el volumen de archivos es real — pero se declaran
por lo que son.

`sudo tmutil disablelocal`, la recomendacion clasica para liberar snapshots
locales, **no existe desde High Sierra (10.13)**; esto es el reemplazo real.

El script excluye de Spotlight (`.metadata_never_index`) y de Time Machine
(`tmutil addexclusion -p`) las rutas que existan de:

- `~/Developer`
- `~/Library/Developer/Xcode/DerivedData`
- `~/Library/Caches`
- `~/.cache`
- `~/go/pkg`
- `~/Library/Containers/com.docker.docker`

No crea directorios — si una ruta no existe, se saltea. El guard
`tmutil isexcluded` es sin sudo y no pide nada; con `timestamp_timeout=0`
instalado, cada exclusion de Time Machine que falte pide tu password una vez
(`tmutil addexclusion` requiere root). Si todo ya esta excluido, el tier no
pide password. También reporta
cuantos snapshots locales huerfanos hay en `/` (sin borrar ninguno): el
comando real para liberarlos es `sudo tmutil thinlocalsnapshots / <bytes> 4`,
una operacion irreversible que este script no toma por vos.

## Telemetria por via soportada — lo scripteado y lo que queda en GUI

El script escribe solo keys publicas y verificables. Todo lo que no tiene key
estable queda como verify-only (`[OK]`/`[WARN]` de solo lectura) mas checklist
manual. Nada de `launchctl disable`, `mdutil -a -d`, `spctl --master-disable`,
borrado de DBs de analytics ni keys inventadas.

Lo scripteado (con su revert):

| Key | Valor | Revertir |
|---|---|---|
| `com.apple.assistant.support "Search Queries Data Sharing Status"` | `2` | `defaults delete com.apple.assistant.support "Search Queries Data Sharing Status"` |
| `com.apple.assistant.support "Dictation Enabled"` | `false` (con dictado por servidor el audio sale a Apple; solo el dictado en el dispositivo es on-device) | `defaults write com.apple.assistant.support "Dictation Enabled" -bool true` |
| `com.apple.assistant.support "Siri Data Sharing Opt-In Status"` | `2` | `defaults delete com.apple.assistant.support "Siri Data Sharing Opt-In Status"` |
| `com.apple.suggestions SiriSuggestionsEnabled` | `false` | `defaults delete com.apple.suggestions SiriSuggestionsEnabled` |
| `com.apple.SubmitDiagInfo AutoSubmit` / `ThirdPartyDataSubmit` | `false` | `defaults delete com.apple.SubmitDiagInfo AutoSubmit ThirdPartyDataSubmit` |
| `com.apple.analyticsd AnalyticsEnabled` | `false` | `defaults delete com.apple.analyticsd AnalyticsEnabled` |
| `com.apple.iCloud EnableAnalytics` | `false` | `defaults delete com.apple.iCloud EnableAnalytics` |
| `com.apple.UsageTracking CoreDonationsEnabled` / `UDCAutomationEnabled` | `false` | `defaults delete com.apple.UsageTracking CoreDonationsEnabled UDCAutomationEnabled` |
| `com.apple.AdLib allowApplePersonalizedAdvertising` / `forceLimitAdTracking` / `allowIdentifierForAdvertising` | `false` / `true` / `0` | `defaults delete com.apple.AdLib allowApplePersonalizedAdvertising forceLimitAdTracking allowIdentifierForAdvertising` |
| `com.apple.CloudSubscriptionFeatures.optIn auto_opt_in` | solo lectura (`[--]`, no se escribe) | N/A: se gobierna en Ajustes > Apple Intelligence y Siri |
| `com.apple.Spotlight SuggestionsEnabled` / `ServerSuggestionsEnabled` | `false` | `defaults delete com.apple.Spotlight SuggestionsEnabled ServerSuggestionsEnabled` |

Checklist GUI (sin key publica, se hace a mano una vez y se re-chequea tras
cada major update, que suele reactivar toggles):

- [ ] **Help Apple Improve Search OFF**: Ajustes > Spotlight, al fondo del
  todo. Gobierna el *almacenamiento* de queries, no la *transmision*: con
  sugerencias de Safari activas el texto igual viaja para pedir sugerencias.
- [ ] **Mejorar Siri y Dictado OFF** + resto del panel: Ajustes > Privacidad
  y Seguridad > Analisis y mejoras (Compartir analisis del Mac, Mejorar Siri
  y Dictado, Compartir con desarrolladores, Compartir analisis de iCloud).
- [ ] **Anuncios personalizados OFF**: Ajustes > Privacidad y Seguridad >
  Publicidad de Apple (las keys AdLib de arriba son el respaldo scripteado).
- [ ] **Sugerencias y Buscar OFF**: Ajustes > Privacidad y Seguridad >
  Localizacion > Servicios del sistema. Sin key publica: solo GUI.
- [ ] **Apple Intelligence master OFF**: Ajustes > Apple Intelligence y Siri,
  toggle de arriba. Si se usa: ChatGPT sin cuenta vinculada y Confirmar
  solicitudes de ChatGPT en ON (es el unico indicador visible de que un
  request sale de la Mac; el atajo "Ask ChatGPT..." saltea la confirmacion).
  El viejo opt-out por feature (ID 545129924) se saco del script: no gobernaba
  el master y el ID cambia entre updates, asi que fijarlo es fragil.
- [ ] **Safari triple-OFF**: Safari > Ajustes > Buscar — desmarcar
  sugerencias del motor de busqueda, sugerencias de Safari y precargar Top
  Hit. Las keys del script hacen lo mismo pero exigen Full Disk Access; en
  GUI funciona siempre.
- [ ] **Spotlight categorias**: Ajustes > Spotlight — desmarcar Websites
  (contenido web) y Siri Suggestions; boton Search Privacy para excluir
  volumenes (el arbol de desarrollo ya va por el Tier 3 del script).
- [ ] **Accesorios en "Preguntar siempre"**: Ajustes > Privacidad y Seguridad
  > Accesorios > Permitir conectar accesorios. Sin key scripteable: la unica
  key publica (`allowUSBRestrictedMode`) es via MDM supervisado y solo sirve
  para forzar "permitir", no para fijar "preguntar siempre" (Apple: guia de
  despliegue "Manage accessory access").
- [ ] **Safari anti-tracking + Hide IP**: Safari > Ajustes > Privacidad —
  impedir rastreo entre sitios y ocultar IP de rastreadores. CIS Tahoe 6.3.5
  lo pone como auditoria, no como default automatico: sin key publica estable,
  va en GUI.
- [ ] **Dictado en el dispositivo**: el script ya deja Dictation Enabled en
  0 (con dictado por servidor el audio sale a Apple). Si se reactiva, bajar el
  idioma en Ajustes > Teclado > Dictado para que procese on-device.

Queda vivo por diseno (no es drift, no se "arregla" desde aca): daemons
residentes (`mediaanalysisd`/`photoanalysisd`, ver abajo), Private Cloud
Compute (con el master ON parte del trabajo sale de la Mac; solo el master
OFF lo frena) y Fotos (su analisis es parte del app, mitigacion = Tier 3 +
`UserSelectedAnonymousUsageOptIn`).

## Qué NO arregla este script

Es la parte que importa mas que la lista de arriba: separar lo que un
`defaults write` puede tocar de lo que no.

- **`mediaanalysisd` y `photoanalysisd`** (analisis de fotos/video en
  background, Visual Look Up, Live Text) no se pueden desactivar sin apagar
  SIP y editar plists del sistema — no soportado, no reversible con
  confianza. El consumo alto esta reportado desde 15.1 y sigue en 26.x sin
  fix oficial de Apple; las cifras que se ven en los reportes rondan un core
  saturado de forma sostenida, no el ">600%" que este README afirmaba sin
  fuente. Hay un hilo de Apple Developer que lo ata al **Simulator de iOS**:
  los runtimes traen fototecas de muestra y el host las indexa, asi que
  aparece justo trabajando con Xcode. La unica mitigacion soportada es
  reducir que se indexa (tier 3 de este script), no desactivar el daemon.
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
