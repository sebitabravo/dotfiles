#!/usr/bin/env bash
# macOS — defaults write optimizations
# Verificado en Sequoia 15.7.9 y en Tahoe 26.6.2 (arm64). Corre en las dos: lo
# que cambio entre versiones esta detras de guards por version, no removido.
# Las keys springboard-* de Launchpad se escriben solo hasta Sequoia (Tahoe lo
# saco del sistema) y Reduce Transparency se salta solo en 26.0-26.2, la
# ventana donde Apple la tuvo rota.
# El inventario ejecutable se puede revisar sin escrituras con --dry-run.
#
# Apply: chmod +x defaults.sh && ./defaults.sh
# Flags:
#   --dry-run      imprime cada comando sin ejecutarlo
#   --no-sudo      salta el tier con sudo (DevToolsSecurity, powernap, etc.)
#   --bonjour-off  agrega el opt-in de NoMulticastAdvertisements (rompe
#                  descubrimiento de impresoras/DLNA/Home Assistant en LAN)
#   --help         esta ayuda
#
# Reconciliado contra el estado real de la maquina: los valores de aca son los
# que la Mac tiene hoy, no los que el script proponia originalmente. Donde el
# valor vivo baja la privacidad respecto del original hay un comentario
# "Para revertir:" con el valor endurecido.
set -euo pipefail

DRY_RUN=0
NO_SUDO=0
BONJOUR_OFF=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-sudo) NO_SUDO=1 ;;
    --bonjour-off) BONJOUR_OFF=1 ;;
    --help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      echo "Flag desconocida: $arg (ver --help)" >&2
      exit 1
      ;;
  esac
done

# ── Preflight ──────────────────────────────────────────────────────
MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
# El minor hace falta porque hay keys cuyo comportamiento cambio dentro de la
# misma major: Reduce Transparency estuvo roto en 26.1/26.2 y se arreglo en
# 26.3. Un release sin minor ("26") se trata como 26.0.
if [ "$MACOS_VERSION" = "$MACOS_MAJOR" ]; then
  MACOS_MINOR=0
else
  MACOS_MINOR="${MACOS_VERSION#*.}"
  MACOS_MINOR="${MACOS_MINOR%%.*}"
fi
ARCH="$(uname -m)"
echo "=== macOS $MACOS_VERSION ($ARCH) ==="
if [ "$MACOS_MAJOR" -ge 26 ]; then
  echo "[--] Tahoe 26.x: Launchpad ya no existe (lo absorbio Spotlight), asi" \
    "que las keys springboard-* se saltan en esta version."
fi
if [ "$MACOS_MAJOR" -eq 26 ] && [ "$MACOS_MINOR" -lt 3 ]; then
  echo "[!!] 26.0-26.2 tienen Reduce Transparency roto: se salta en esta" \
    "version. Actualizar a 26.3 o superior lo habilita."
fi
if [ "$ARCH" != "arm64" ]; then
  echo "[!!] Script verificado solo en Apple Silicon (arm64)."
fi

# ── Helpers de reporte ─────────────────────────────────────────────
# apply_default: forwarda todo a `defaults write` y reporta si el write
# realmente tuvo exito. Antes cada bloque hacia echo "[OK]" incondicional,
# incluso cuando el write fallaba (ej: dominio protegido por TCC sin Full
# Disk Access). set -e no detiene el script porque el resultado del `if`
# siempre es 0.
DEFAULTS_FAILURES=0

record_failure() {
  DEFAULTS_FAILURES=$((DEFAULTS_FAILURES + 1))
  echo "[FAIL] $1"
}

apply_default() {
  local label="$1"
  shift
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] defaults write $*"
    return 0
  fi
  if defaults write "$@" 2>/dev/null; then
    echo "[SET] $label"
  else
    record_failure "$label"
  fi
}

# Variante para `defaults -currentHost write ...` (el host va antes del verbo).
apply_default_host() {
  local label="$1"
  shift
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] defaults -currentHost write $*"
    return 0
  fi
  if defaults -currentHost write "$@" 2>/dev/null; then
    echo "[SET] $label"
  else
    record_failure "$label"
  fi
}

delete_default() {
  local label="$1"
  shift
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] defaults delete $*"
    return 0
  fi
  if defaults delete "$@" 2>/dev/null; then
    echo "[SET] $label"
  else
    echo "[SKIP] $label (key ausente)"
  fi
}

echo "=== Aplicando defaults de macOS ==="

# ── Animaciones de ventanas ────────────────────────────────────────
apply_default "Window resize instant" NSGlobalDomain NSWindowResizeTime -float 0.001

# Window animations: stock macOS (animations are part of the experience)
# NSAutomaticWindowAnimationsEnabled kept at default (true)

apply_default "Document revisions animation disabled" NSGlobalDomain NSDocumentRevisionsWindowTransformAnimation -bool false

apply_default "Full-screen toolbar animation instant" NSGlobalDomain NSToolbarFullScreenAnimationDuration -float 0

# Column view animation: stock macOS (smooth navigation feel)

# Scroll: stock macOS (smooth scrolling + elastic feel are iconic)

# ── Quick Look ─────────────────────────────────────────────────────
apply_default "Quick Look animation = 0" -g QLPanelAnimationDuration -float 0

# Cursor magnification: stock macOS (no perf/security/stability impact)

# ── Mission Control ────────────────────────────────────────────────
apply_default "Mission Control speed" com.apple.dock expose-animation-duration -float 0.1

# Escritorios en orden fijo: sin esto Mission Control los reordena por uso
# reciente y los atajos ctrl+numero dejan de apuntar siempre al mismo.
apply_default "Escritorios en orden fijo" com.apple.dock mru-spaces -bool false

apply_default "Sin cambio automatico de escritorio al activar una app" com.apple.dock workspaces-auto-swoosh -bool false

# Agrupa las ventanas por aplicacion en Mission Control (Exposé). No es
# animacion, es organizacion: menos scroll visual para encontrar una ventana
# especifica cuando tenes varias apps con multiples ventanas abiertas.
apply_default "Mission Control agrupa ventanas por app" com.apple.dock expose-group-by-app -bool true

# ── Launchpad (existe hasta Sequoia; removido en Tahoe 26) ─────────
# Apple saco Launchpad del sistema en Tahoe y sus archivos ya no estan, asi
# que ahi estas keys solo dejarian entradas muertas en com.apple.dock. En
# Sequoia y anteriores siguen siendo la velocidad real de Launchpad.
if [ "$MACOS_MAJOR" -lt 26 ]; then
  apply_default "Launchpad show speed" com.apple.dock springboard-show-duration -float 0.1

  apply_default "Launchpad hide speed" com.apple.dock springboard-hide-duration -float 0.1

  apply_default "Launchpad page scroll instant" com.apple.dock springboard-page-duration -float 0
else
  echo "[SKIP] Launchpad springboard-* (removido en Tahoe 26.x)"
fi

# ── Dock ───────────────────────────────────────────────────────────
apply_default "Dock tile size = 36px" com.apple.dock tilesize -int 36

apply_default "Dock minimize effect = scale" com.apple.dock mineffect -string "scale"

apply_default "Minimize to separate Dock slot (not into app icon)" com.apple.dock minimize-to-application -bool false

apply_default "No recent apps in Dock" com.apple.dock show-recents -bool false

apply_default "Dock scroll to Exposé" com.apple.dock scroll-to-open -bool true

# ── Dock: auto-hide instantaneo ────────────────────────────────────
# El README ya prometia "auto-hide instantaneo (sin delay)" pero el script
# nunca lo escribia. Los tres van juntos: sin delay y sin animacion de salida.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Dock auto-hide instantaneo"
elif (
  defaults write com.apple.dock autohide -bool true &&
    defaults write com.apple.dock autohide-delay -float 0 &&
    defaults write com.apple.dock autohide-time-modifier -float 0
) 2>/dev/null; then
  echo "[SET] Dock auto-hide instantaneo"
else
  record_failure "Dock auto-hide instantaneo"
fi

apply_default "Sin animacion de rebote al abrir apps" com.apple.dock launchanim -bool false

apply_default "Iconos del Dock no rebotan por notificacion" com.apple.dock no-bouncing -bool true

apply_default "Spring-load all Dock items" com.apple.dock enable-spring-load-actions-on-all-items -bool true

apply_default "Dock show hidden app icons" com.apple.dock showhidden -bool true

apply_default "Dock highlight stacks on hover" com.apple.dock mouse-over-hilite-stack -bool true

# Esquina inferior derecha sin accion (1 = ninguna), sin modificador.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Hot corner inferior derecha desactivada"
elif (
  defaults write com.apple.dock wvous-br-corner -int 1 &&
    defaults write com.apple.dock wvous-br-modifier -int 0
) 2>/dev/null; then
  echo "[SET] Hot corner inferior derecha desactivada"
else
  record_failure "Hot corner inferior derecha desactivada"
fi

# Las cuatro esquinas quedan desactivadas con valores explicitos y versionables.
apply_default "Hot corner superior izquierda desactivada" com.apple.dock wvous-tl-corner -int 1
apply_default "Hot corner superior derecha desactivada" com.apple.dock wvous-tr-corner -int 1
apply_default "Hot corner inferior izquierda desactivada" com.apple.dock wvous-bl-corner -int 1

# ── Trackpad ───────────────────────────────────────────────────────
apply_default "Trackpad tracking speed" NSGlobalDomain com.apple.trackpad.scaling -float 1.5

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Tap to click"
elif (
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true &&
    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
) 2>/dev/null; then
  echo "[SET] Tap to click"
else
  record_failure "Tap to click"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Two-finger right click"
elif (
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true &&
    defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
) 2>/dev/null; then
  echo "[SET] Two-finger right click"
else
  record_failure "Two-finger right click"
fi

# Arrastre con tres dedos. Vive en Accesibilidad, no en las prefs de trackpad,
# y obliga a liberar los gestos de tres dedos: si el swipe horizontal/vertical
# de tres dedos sigue asignado, el arrastre se corta a la mitad.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Arrastre con tres dedos (gestos de tres dedos liberados)"
elif (
  defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true &&
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true &&
    defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 0 &&
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 0 &&
    defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 0 &&
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 0 &&
    defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0 &&
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0
) 2>/dev/null; then
  echo "[SET] Arrastre con tres dedos (gestos de tres dedos liberados)"
else
  record_failure "Arrastre con tres dedos (gestos de tres dedos liberados)"
fi

# Los swipes de escritorio/Mission Control pasan a cuatro dedos.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Swipes de espacios y Mission Control con cuatro dedos"
elif (
  defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 2 &&
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 2 &&
    defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2 &&
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
) 2>/dev/null; then
  echo "[SET] Swipes de espacios y Mission Control con cuatro dedos"
else
  record_failure "Swipes de espacios y Mission Control con cuatro dedos"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Centro de notificaciones desde el borde derecho"
elif (
  defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3 &&
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
) 2>/dev/null; then
  echo "[SET] Centro de notificaciones desde el borde derecho"
else
  record_failure "Centro de notificaciones desde el borde derecho"
fi

# PREFERENCIA PERSONAL. Paridad con Hyprland: scroll natural desactivado. Se
# deja separado de los ajustes especificos del trackpad para conservar ambos
# dispositivos. Apple usa scroll natural desde Lion (2011), asi que quien copie
# esta config y venga de macOS va a notar la inversion al instante.
# Revertir: defaults delete NSGlobalDomain com.apple.swipescrolldirection
apply_default "Scroll natural desactivado" NSGlobalDomain com.apple.swipescrolldirection -bool false

# ── Keyboard ───────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Key repeat: delay 225ms, rate 30ms"
elif (
  defaults write NSGlobalDomain InitialKeyRepeat -int 15 &&
    defaults write NSGlobalDomain KeyRepeat -int 2
) 2>/dev/null; then
  echo "[SET] Key repeat: delay 225ms, rate 30ms"
else
  record_failure "Key repeat: delay 225ms, rate 30ms"
fi

# ── Bluetooth ──────────────────────────────────────────────────────
# Tuning heredado de SBC/A2DP (sube el bitpool minimo negociado). Con AAC en
# Apple Silicon el codec no pasa por este parametro, asi que no hay evidencia
# de que cambie la calidad percibida hoy. Se deja: es inocuo, no rompe nada.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Bluetooth audio bitpool optimized (40-80, negotiated 48-80)"
elif (
  defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40 &&
    defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Max (editable)" -int 80 &&
    defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool Min (editable)" -int 80 &&
    defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool (editable)" -int 80 &&
    defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool" -int 80 &&
    defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Max" -int 80 &&
    defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Min" -int 48
) 2>/dev/null; then
  echo "[SET] Bluetooth audio bitpool optimized (40-80, negotiated 48-80)"
else
  record_failure "Bluetooth audio bitpool optimized (40-80, negotiated 48-80)"
fi

# ── WindowManager (Sequoia 15.x) ───────────────────────────────────
apply_default "WindowManager tiling no margins" com.apple.WindowManager EnableTiledWindowMargins -bool false

# Politica de tiling: que no dispare solo, pero que siga estando. Arrastrar una
# ventana cerca de un borde para moverla la termina acomodando sin que la
# pidas, y con dos monitores externos ese gesto ocurre cada vez que se pasa una
# ventana de una pantalla a la otra. Se apagan los dos disparos por arrastre y
# se deja el acelerador de Option: asi el tiling pasa solo cuando se pide.
# Se escribe el acelerador explicito aunque hoy sea el default de Apple, porque
# estos toggles se reportan volviendo solos despues de updates de macOS.
apply_default "Tiling por arrastre al borde apagado" com.apple.WindowManager EnableTilingByEdgeDrag -bool false

apply_default "Tiling por arrastre a la barra de menu apagado" com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false

apply_default "Tiling con Option mantenido activo" com.apple.WindowManager EnableTilingOptionAccelerator -bool true

apply_default "Stage Manager desactivado" com.apple.WindowManager GloballyEnabled -bool false

# El clic en el fondo NO manda las ventanas atras para mostrar el escritorio:
# con Stage Manager apagado ese gesto solo estorba.
apply_default "Clic en el fondo no revela el escritorio" com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

# PREFERENCIA PERSONAL. Los iconos siguen en el Finder, solo se ocultan del
# escritorio mientras trabajas. Quien guarde archivos en el escritorio y copie
# esta config los va a extrañar hasta que lea esta linea.
# Revertir: defaults delete com.apple.WindowManager HideDesktop
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Iconos del escritorio ocultos mientras trabajas"
elif (
  defaults write com.apple.WindowManager HideDesktop -bool true &&
    defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true
) 2>/dev/null; then
  echo "[SET] Iconos del escritorio ocultos mientras trabajas"
else
  record_failure "Iconos del escritorio ocultos mientras trabajas"
fi

apply_default "Ventanas agrupadas por aplicacion" com.apple.WindowManager AppWindowGroupingBehavior -int 1

# Los widgets de escritorio NO se ocultan desde aca, aunque Tahoe los active
# solo despues del upgrade. Son una funcion que un usuario de macOS conoce y
# espera encontrar, y el script no puede distinguir entre "Tahoe me lo prendio
# sin preguntar" y "lo uso todos los dias". Ante la duda gana la expectativa
# del usuario: se gestionan en Ajustes > Escritorio y Dock > Mostrar widgets.

# ── Finder ─────────────────────────────────────────────────────────
apply_default "Finder animations disabled" com.apple.finder DisableAllAnimations -bool true

apply_default "Finder default list view" com.apple.finder FXPreferredViewStyle -string "Nlsv"

apply_default "Finder show hidden files" com.apple.finder AppleShowAllFiles -bool true

apply_default "No extension change warning" com.apple.finder FXEnableExtensionChangeWarning -bool false

apply_default "Finder open in tabs" com.apple.finder FinderSpawnTab -bool true

apply_default "Finder search current folder" com.apple.finder FXDefaultSearchScope -string "SCcf"

apply_default "Finder status bar" com.apple.finder ShowStatusBar -bool true

apply_default "Finder path bar" com.apple.finder ShowPathbar -bool true

# Titulo de la ventana: stock macOS (solo el nombre de la carpeta).
# _FXShowPosixPathInTitle mostraria la ruta completa "$HOME/Developer"
# en vez de "Developer". La barra de ruta de abajo (ShowPathbar) ya da esa
# informacion sin ocupar el titulo.

apply_default "Sidebar devices section" com.apple.finder SidebarDevicesSectionDisclosedState -bool true

apply_default "Sidebar places section" com.apple.finder SidebarPlacesSectionDisclosedState -bool true

apply_default "iCloud Desktop visible en la sidebar" com.apple.finder SidebarShowingiCloudDesktop -bool true

apply_default "Seccion iCloud Drive colapsada" com.apple.finder SidebariCloudDriveSectionDisclosedState -bool false

# PfHm = Home folder (not Recents)
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Finder new window = Home"
elif (
  defaults write com.apple.finder NewWindowTarget -string "PfHm" &&
    defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
) 2>/dev/null; then
  echo "[SET] Finder new window = Home"
else
  record_failure "Finder new window = Home"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Finder list view columns: name, date, size"
elif (
  defaults write com.apple.finder FK_StandardViewSettings -dict-add ListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }' &&
    defaults write com.apple.finder FK_StandardViewSettings -dict-add ExtendedListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
) 2>/dev/null; then
  echo "[SET] Finder list view columns: name, date, size"
else
  record_failure "Finder list view columns: name, date, size"
fi

# Keep folders on top when sorting by name
apply_default "Finder folders on top" com.apple.finder _FXSortFoldersFirst -bool true

# Spring-loading: folders spring open instantly when dragging files over them
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Finder spring-loading instant"
elif (
  defaults write NSGlobalDomain com.apple.springing.enabled -bool true &&
    defaults write NSGlobalDomain com.apple.springing.delay -float 0
) 2>/dev/null; then
  echo "[SET] Finder spring-loading instant"
else
  record_failure "Finder spring-loading instant"
fi

delete_default "Finder info panes reset" com.apple.finder FXInfoPanesExpanded

delete_default "Desktop icon positions reset" com.apple.finder FXDesktopVolumePositions

apply_default "Quick Look text selection" com.apple.finder QLEnableTextSelection -bool true

apply_default "Panel de vista previa visible" com.apple.finder ShowPreviewPane -bool true

apply_default "Agrupar por tipo" com.apple.finder FXPreferredGroupBy -string "Kind"

# ── Escritorio: sin iconos de volumenes ────────────────────────────
# Los discos siguen montados y accesibles desde la sidebar; solo se saca el
# icono del escritorio.
# PREFERENCIA PERSONAL, y la mas fuerte de todas: escritorio limpio de
# volumenes. Ojo con lo que implica, porque los defaults de Apple no son
# uniformes — el disco interno ya viene oculto de fabrica, pero externos,
# CD/DVD y servidores vienen visibles. Con estas tres keys puestas, **un
# pendrive se monta pero no aparece en el escritorio**: hay que buscarlo en la
# sidebar del Finder. Es deliberado, no un bug.
# Revertir: defaults delete com.apple.finder ShowExternalHardDrivesOnDesktop
#           defaults delete com.apple.finder ShowRemovableMediaOnDesktop
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Escritorio sin iconos de discos ni medios extraibles"
elif (
  defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false &&
    defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false &&
    defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
) 2>/dev/null; then
  echo "[SET] Escritorio sin iconos de discos ni medios extraibles"
else
  record_failure "Escritorio sin iconos de discos ni medios extraibles"
fi

# ── Papelera ───────────────────────────────────────────────────────
apply_default "Sin confirmacion al vaciar la papelera" com.apple.finder WarnOnEmptyTrash -bool false

apply_default "Papelera se vacia sola pasados 30 dias" com.apple.finder FXRemoveOldTrashItems -bool true

# ── Network Browser ────────────────────────────────────────────────
apply_default "Network browser show all interfaces" com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# ── .DS_Store ──────────────────────────────────────────────────────
# Requires logout to take effect
apply_default "No .DS_Store on network volumes" com.apple.desktopservices DSDontWriteNetworkStores -bool true

apply_default "No .DS_Store on USB drives" com.apple.desktopservices DSDontWriteUSBStores -bool true

# ── Archive Utility ────────────────────────────────────────────────
apply_default "Archive Utility no __MACOSX folders" com.apple.archiveutility "com.apple.archiveutility.disable-resourceforks" -bool true

apply_default "Archive Utility extract in current folder" com.apple.archiveutility "dearchive-into-subfolder" -bool false

apply_default "Archive Utility auto-trash after extract" com.apple.archiveutility "move-archive-to-trash" -bool true

# ── Apariencia ─────────────────────────────────────────────────────
apply_default "Modo oscuro" NSGlobalDomain AppleInterfaceStyle -string "Dark"

# Evita que macOS vuelva automaticamente al modo claro al cambiar la hora.
delete_default "Modo oscuro no cambia automaticamente" NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically

apply_default "Color de seleccion grafito" NSGlobalDomain AppleHighlightColor -string "0.847059 0.847059 0.862745 Graphite"

apply_default "Tinte del fondo en las ventanas activo" NSGlobalDomain AppleReduceDesktopTinting -bool false

apply_default "Iconos chicos en sidebars" NSGlobalDomain NSTableViewDefaultSizeMode -int 1

# ── Region: Chile (metrico, ISO, semana en lunes) ──────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Unidades metricas y Celsius"
elif (
  defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters" &&
    defaults write NSGlobalDomain AppleMetricUnits -bool true &&
    defaults write NSGlobalDomain AppleTemperatureUnit -string "Celsius"
) 2>/dev/null; then
  echo "[SET] Unidades metricas y Celsius"
else
  record_failure "Unidades metricas y Celsius"
fi

apply_default "La semana empieza el lunes" NSGlobalDomain AppleFirstWeekday -dict gregorian -int 2

apply_default "Fecha corta en ISO (y-MM-dd)" NSGlobalDomain AppleICUDateFormatStrings -dict 1 -string "y-MM-dd"

# ── Ventanas ───────────────────────────────────────────────────────
# Doble clic en la barra de titulo llena la pantalla en vez de minimizar.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Doble clic en la barra de titulo = Fill"
elif (
  defaults write NSGlobalDomain AppleActionOnDoubleClick -string "Fill" &&
    defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false
) 2>/dev/null; then
  echo "[SET] Doble clic en la barra de titulo = Fill"
else
  record_failure "Doble clic en la barra de titulo = Fill"
fi

# Mover una ventana desde cualquier punto con ctrl+cmd, sin apuntarle a la barra.
apply_default "Arrastrar ventanas con ctrl+cmd desde cualquier lugar" NSGlobalDomain NSWindowShouldDragOnGesture -bool true

# Clic en la barra de scroll salta a esa posicion en vez de avanzar una pagina.
apply_default "Clic en el scroll salta a la posicion" NSGlobalDomain AppleScrollerPagingBehavior -bool true

# Sin swipe de dos dedos para atras/adelante: se dispara solo al hacer scroll
# horizontal dentro de una pagina.
apply_default "Sin navegacion atras/adelante por swipe" NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false

# App Nap: se deja en el default de Apple (activo). Desactivarlo mantenia las
# apps de fondo con scheduling completo permanente — mas consumo y mas riesgo
# de throttle termico en un chasis sin ventilador (Air). Esta key quedo escrita
# en la maquina por una version anterior del script; se revierte.
delete_default "App Nap vuelve al default de Apple (activo)" NSGlobalDomain NSAppSleepDisabled

# ── Global ─────────────────────────────────────────────────────────
apply_default "Show all file extensions" NSGlobalDomain AppleShowAllExtensions -bool true

apply_default "Scroll bars visible on scroll" NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

apply_default "Show invisible characters" NSGlobalDomain NSTextShowsControlCharacters -bool true

apply_default "Auto-capitalization off" NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

apply_default "Smart dashes off" NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

apply_default "Auto-period off" NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

apply_default "Smart quotes off" NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

apply_default "Spelling correction off" NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

apply_default "Web spelling correction off" NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false

# Tab navega TODOS los controles, no solo campos de texto. Es lo que hace
# utilizables los dialogos sin mouse.
apply_default "Navegacion completa por teclado" NSGlobalDomain AppleKeyboardUIMode -int 3

apply_default "Auto text completion off" NSGlobalDomain NSAutomaticTextCompletionEnabled -bool false

# Apple Intelligence inline predictions (Sequoia+)
apply_default "Inline predictions off" NSGlobalDomain NSAutomaticInlinePredictionEnabled -bool false

apply_default "Toolbar title rollover instant" NSGlobalDomain NSToolbarTitleViewRolloverDelay -float 0

# ── Diálogos Save/Print ────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Save dialog always expanded"
elif (
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true &&
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
) 2>/dev/null; then
  echo "[SET] Save dialog always expanded"
else
  record_failure "Save dialog always expanded"
fi

apply_default "Save to disk by default (not iCloud)" NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Print dialog always expanded"
elif (
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true &&
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
) 2>/dev/null; then
  echo "[SET] Print dialog always expanded"
else
  record_failure "Print dialog always expanded"
fi

apply_default "Print dialog auto-close after job" com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# ── Screensaver ────────────────────────────────────────────────────
# idleTime vive en el dominio por-host: el dominio plano se escribe pero macOS
# no lo lee. Verificado en 15.7.9 — el valor efectivo esta en
# ~/Library/Preferences/ByHost/com.apple.screensaver.<UUID>.plist
apply_default_host "Salvapantallas a los 5 min" com.apple.screensaver idleTime -int 300

# NO-OP desde macOS 10.13.4: estas dos keys se escriben pero el sistema dejo de
# leerlas. El bloqueo inmediato se configura en Ajustes > Pantalla bloqueada, y
# se verifica con `sysadminctl -screenLock status` (debe decir "immediate").
# Se dejan porque documentan la intencion, no porque hagan algo.
apply_default "Screen saver password requested" com.apple.screensaver askForPassword -int 1
apply_default "Screen saver password delay = 0" com.apple.screensaver askForPasswordDelay -int 0
echo "[--] askForPassword: no-op, configurar en Ajustes (ver comentario)"

# ── Screenshots ────────────────────────────────────────────────────
apply_default "Screenshot shadows off" com.apple.screencapture disable-shadow -bool true

apply_default "Capturas en PNG" com.apple.screencapture type -string "png"

# Nombre corto: "Screenshot.png" en vez de "Screenshot 2026-08-15 at 04.01.36".
apply_default "Capturas sin fecha en el nombre" com.apple.screencapture include-date -bool false

# El thumbnail flotante pierde capturas en Tahoe: si se interactua con el y la
# accion se cancela a medias (Compartir > AirDrop > cancelar), la captura no se
# guarda en ningun lado. Sin thumbnail, el archivo va directo al Escritorio.
apply_default "Sin thumbnail flotante en capturas" com.apple.screencapture show-thumbnail -bool false

# La ubicacion queda en el Escritorio (default de macOS) a proposito.
# Si algun dia la queres mover, `location` por defaults es poco fiable desde
# Monterey: hacelo por Screenshot.app > Opciones > Guardar en.

# ── Window Restoration ─────────────────────────────────────────────
# Window restoration por app: stock macOS (las ventanas reabren al relanzar).
#
# Estas dos keys son drift-control del checkbox "Reabrir ventanas al volver a
# iniciar sesion", NO un fix de rendimiento. Honestidad sobre lo que son:
# vienen de un hack de Lion (2011) y desde 10.7.4 el checkbox persiste solo,
# asi que escribirlas puede dejar el checkbox tildado pero inerte. Se ponen
# para que el estado quede declarado en el repo y no dependa de que alguien se
# acuerde de destildarlo, no porque Apple documente esto como mitigacion de
# los memory leaks de Tahoe — Apple documenta el checkbox (HT102318) solo como
# la forma de evitar el reopen. Que menos estado al login implique menos RAM e
# IO al arrancar es plausible, no esta medido.
# En esta maquina ambas ya leen 0, asi que esto codifica el estado existente.
apply_default "Login no reabre ventanas de la sesion anterior" com.apple.loginwindow TALLogoutSavesState -bool false

apply_default "Login no relanza las apps de la sesion anterior" com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false

# ── Preview ────────────────────────────────────────────────────────
apply_default "Preview no window restoration" com.apple.Preview NSQuitAlwaysKeepsWindow -bool false

# ── QuickTime ──────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] QuickTime no window restoration + auto-play on open"
elif (
  defaults write com.apple.QuickTimePlayerX NSQuitAlwaysKeepsWindow -bool false &&
    defaults write com.apple.QuickTimePlayerX MGPlayMovieOnOpen -bool true
) 2>/dev/null; then
  echo "[SET] QuickTime no window restoration + auto-play on open"
else
  record_failure "QuickTime no window restoration + auto-play on open"
fi

# ── Mail ───────────────────────────────────────────────────────────
apply_default "Mail reply animations off" com.apple.mail DisableReplyAnimations -bool true

apply_default "Mail send animations off" com.apple.mail DisableSendAnimations -bool true

# Copy email address without person's name (user@domain.com, not "John Doe <user@domain.com>")
apply_default "Mail copy email without name" com.apple.mail AddressesIncludeNameOnPasteboard -bool false

apply_default "Mail inline attachments off" com.apple.mail DisableInlineAttachmentViewing -bool true

apply_default "Mail plain text compose" com.apple.mail PreferPlainText -bool true

# Mail spell check: stock macOS (spell checking is useful, no security impact)

# ── Messages ───────────────────────────────────────────────────────
apply_default "Messages: auto-emoji off" com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticEmojiSubstitutionEnablediMessage" -bool false

apply_default "Messages: smart quotes off" com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false

# ── Disk Utility ───────────────────────────────────────────────────
# Skipping DMG verification disable for security
echo "[SKIP] DMG verification kept at system default (security)"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Auto-open DMG root after mount"
elif (
  defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true &&
    defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
) 2>/dev/null; then
  echo "[SET] Auto-open DMG root after mount"
else
  record_failure "Auto-open DMG root after mount"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Disk Utility debug menu + advanced image options"
elif (
  defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true &&
    defaults write com.apple.DiskUtility advanced-image-options -bool true
) 2>/dev/null; then
  echo "[SET] Disk Utility debug menu + advanced image options"
else
  record_failure "Disk Utility debug menu + advanced image options"
fi

# ── Time Machine ───────────────────────────────────────────────────
apply_default "No Time Machine prompts" com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# ── Privacidad ─────────────────────────────────────────────────────
apply_default "Don't send diagnostics to Apple" com.apple.SubmitDiagInfo AutoSubmit -bool false

apply_default "Crash reporter dialogs disabled" com.apple.CrashReporter DialogType -string "none"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Siri disabled + menu bar icon removed"
elif (
  defaults write com.apple.Siri SiriPrefStashedStatusMenuVisible -bool false &&
    defaults write com.apple.Siri StatusMenuVisible -bool false &&
    defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
) 2>/dev/null; then
  echo "[SET] Siri disabled + menu bar icon removed"
else
  record_failure "Siri disabled + menu bar icon removed"
fi

# Prevent "Enable Siri?" prompts after updates
apply_default "Siri declined permanently" com.apple.Siri UserHasDeclinedEnable -bool true

# Dictado APAGADO. Con dictado por servidor el audio sale a los servidores de
# Apple; solo el dictado en el dispositivo procesa on-device sin enviar voz.
# Apagarlo cierra esa fuga de voz real. Reversible: -bool true (o activarlo en
# Ajustes > Teclado > Dictado).
# Para revertir: -bool true
apply_default "Dictation disabled" com.apple.assistant.support "Dictation Enabled" -bool false

apply_default "Search queries data sharing off" com.apple.assistant.support "Search Queries Data Sharing Status" -int 2

# Help Apple Improve Search (Ajustes > Spotlight, al fondo): no tiene key
# publica estable. La key de arriba es el best-effort scripteable y ya lee 2
# en esta maquina. El switch de GUI se verifica a mano (checklist en README).
# Solo lectura: jamas se inventa una key para forzarlo.
if [ "$(defaults read com.apple.assistant.support "Search Queries Data Sharing Status" 2>/dev/null || true)" = "2" ]; then
  echo "[OK] Improve Search best-effort (Search Queries Data Sharing Status = 2)"
else
  echo "[WARN] Improve Search: apagar en Ajustes > Spotlight > Help Apple Improve Search"
fi

apply_default "Siri data sharing opt-out" com.apple.assistant.support "Siri Data Sharing Opt-In Status" -int 2

apply_default "Siri suggestions engine off" com.apple.suggestions SiriSuggestionsEnabled -bool false

apply_default "Siri Assistant core disabled" com.apple.assistant.support "Assistant Enabled" -bool false

apply_default "Feedback Assistant no auto-gather" com.apple.appleseed.FeedbackAssistant Autogather -bool false

# IDFA (Identifier for Advertisers) — cross-app tracking.
# Vuelve a 0: dejarlo en 1 contradice a las otras dos keys de este mismo
# dominio, que ya restringen personalizacion y fuerzan el limite de tracking.
# No es AutoFill ni ninguna feature que uses: es el identificador publicitario
# cross-app. Para revertir: -int 1
apply_default "Advertising identifier disabled" com.apple.AdLib allowIdentifierForAdvertising -int 0

apply_default "Apple personalized advertising off" com.apple.AdLib allowApplePersonalizedAdvertising -bool false

apply_default "Ad tracking force-limited" com.apple.AdLib forceLimitAdTracking -bool true

# ── Telemetría ─────────────────────────────────────────────────────
apply_default "Third-party diagnostic data off" com.apple.SubmitDiagInfo ThirdPartyDataSubmit -bool false

apply_default "Analytics disabled" com.apple.analyticsd AnalyticsEnabled -bool false

apply_default "iCloud analytics off" com.apple.iCloud EnableAnalytics -bool false

apply_default "Core donations tracking off" com.apple.UsageTracking CoreDonationsEnabled -bool false

apply_default "UDC automation off" com.apple.UsageTracking UDCAutomationEnabled -bool false

apply_default "App Store diagnostic data off" com.apple.appstore SendDiagnosticData -bool false

# Location > System Services > Suggestions & Search: SIN key publica estable.
# locationd se gobierna desde GUI y no se inventa ninguna key para forzarlo
# (las que circulan por foros tocan plists del sistema sin revert confiable).
# Verify-only + checklist en README. No lee nada porque no hay nada legible
# que refleje ese switch.
echo "[WARN] Location Suggestions & Search: sin key publica — apagar en" \
  "Ajustes > Privacidad y Seguridad > Localizacion > Servicios del sistema"

# ── Apps: anonymous usage ──────────────────────────────────────────
apply_default "Maps anonymous usage off" com.apple.Maps UserSelectedAnonymousUsageOptIn -bool false

apply_default "Health anonymous usage off" com.apple.Health UserSelectedAnonymousUsageOptIn -bool false

apply_default "iMessage anonymous usage off" com.apple.imessage UserSelectedAnonymousUsageOptIn -bool false

apply_default "Photos anonymous usage off" com.apple.Photos UserSelectedAnonymousUsageOptIn -bool false

# Handoff logging only — Handoff itself stays enabled
apply_default "Handoff activity logging off" -g NSUserActivityLoggingEnabled -bool false

# ── Image Capture ──────────────────────────────────────────────────
apply_default_host "Image Capture no auto-launch" com.apple.ImageCapture disableHotPlug -bool true

# ── Safari / WebKit ────────────────────────────────────────────────
apply_default "WebKit developer extras" NSGlobalDomain WebKitDeveloperExtras -bool true

# Safari esta sandboxed: su plist real vive en
# ~/Library/Containers/com.apple.Safari/... protegido por TCC. Sin Full Disk
# Access para la terminal, `defaults write com.apple.Safari` no falla — cae
# en silencio a ~/Library/Preferences/com.apple.Safari.plist, un archivo que
# Safari sandboxed nunca lee. El resultado: 30 "[SET]" que no hicieron nada.
# Se detecta escribiendo una key canario y leyendola desde el plist del
# container; si no aparece ahi, no hay FDA y se salta todo el bloque en vez
# de mentir. Fuente: lapcatsoftware.com/articles/containers.html
SAFARI_CONTAINER_PLIST="$HOME/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari"
SAFARI_FDA_OK=1
if [ "$DRY_RUN" -eq 0 ]; then
  _safari_canary="__dotfiles_fda_probe_$$"
  defaults write com.apple.Safari "$_safari_canary" -bool true 2>/dev/null || true
  if ! defaults read "$SAFARI_CONTAINER_PLIST" "$_safari_canary" >/dev/null 2>&1; then
    SAFARI_FDA_OK=0
  fi
  defaults delete com.apple.Safari "$_safari_canary" 2>/dev/null || true
  defaults delete "$SAFARI_CONTAINER_PLIST" "$_safari_canary" 2>/dev/null || true
fi

if [ "$SAFARI_FDA_OK" -eq 0 ]; then
  echo "[SKIP] Bloque Safari (30 keys): la terminal no tiene Full Disk Access."
  echo "       Ajustes > Privacidad y Seguridad > Acceso total al disco >" \
    "agregar tu terminal y reabrirla. Sin esto los writes van a un plist" \
    "que Safari no lee."
  echo "       Sin FDA, el triple-OFF de Buscar se hace igual en GUI:" \
    "Safari > Ajustes > Buscar (sugerencias del motor, sugerencias de" \
    "Safari, precargar Top Hit). Ver checklist en README."
else

  # Desactivado en esta maquina. Safari 17+ unifico esto en "Funciones para
  # desarrolladores web"; los menus Debug e Internal Debug de mas abajo si estan.
  apply_default "Safari Develop menu off" com.apple.Safari IncludeDevelopMenu -bool false

  apply_default "Safari WebKit dev extras" com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true

  apply_default "Safari full URL in address bar" com.apple.Safari ShowFullURLInSmartSearchField -bool true

  apply_default "Safari universal search off" com.apple.Safari UniversalSearchEnabled -bool false

  apply_default "Safari search suggestions off" com.apple.Safari SuppressSearchSuggestions -bool true

  apply_default "Safari search suggestions disabled" com.apple.Safari SearchSuggestionsEnabled -bool false

  apply_default "Safari preload top hit off" com.apple.Safari PreloadTopHit -bool false

  apply_default "Safari Debug menu" com.apple.Safari IncludeDebugMenu -bool true

  apply_default "Safari WebKit2 dev extras" com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true

  apply_default "Safari spelling correction off" com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false

  apply_default "Safari never auto-open downloads" com.apple.Safari AutoOpenSafeDownloads -bool false

  # AutoFill ACTIVO en esta maquina, incluidos contrasenas y tarjetas. Comodo,
  # pero significa que Safari rellena credenciales sin pedir confirmacion.
  # Para revertir: los cuatro a -bool false
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] Safari AutoFill enabled (revisar)"
  elif (
    defaults write com.apple.Safari AutoFillFromAddressBook -bool true &&
      defaults write com.apple.Safari AutoFillPasswords -bool true &&
      defaults write com.apple.Safari AutoFillCreditCardData -bool true &&
      defaults write com.apple.Safari AutoFillMiscellaneousForms -bool true
  ) 2>/dev/null; then
    echo "[SET] Safari AutoFill enabled (revisar)"
  else
    record_failure "Safari AutoFill enabled (revisar)"
  fi

  # Deprecated since Safari 12.1 — harmless no-op, kept for documentation
  apply_default "Safari Do Not Track" com.apple.Safari SendDoNotTrackHTTPHeader -bool true

  # Enhanced privacy in regular browsing (not just private mode)
  apply_default "Safari enhanced privacy in regular browsing" com.apple.Safari EnableEnhancedPrivacyInRegularBrowsing -bool true

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] Safari Tab to links"
  elif (
    defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true &&
      defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" -bool true
  ) 2>/dev/null; then
    echo "[SET] Safari Tab to links"
  else
    record_failure "Safari Tab to links"
  fi

  apply_default "Safari backspace navigation" com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" -bool true

  apply_default "Safari homepage = start page" com.apple.Safari HomePage -string "https://www.apple.com/startpage/"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] Safari hide favorites bar + sidebar"
  elif (
    defaults write com.apple.Safari ShowFavoritesBar -bool false &&
      defaults write com.apple.Safari ShowSidebarInTopSites -bool false
  ) 2>/dev/null; then
    echo "[SET] Safari hide favorites bar + sidebar"
  else
    record_failure "Safari hide favorites bar + sidebar"
  fi

  apply_default "Safari find contains (not starts-with)" com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

  apply_default "Safari Internal Debug menu" com.apple.Safari IncludeInternalDebugMenu -bool true

  # Security hardening
  apply_default "Safari fraudulent website warning" com.apple.Safari WarnAboutFraudulentWebsites -bool true

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] Safari pop-ups blocked"
  elif (
    defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false &&
      defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false
  ) 2>/dev/null; then
    echo "[SET] Safari pop-ups blocked"
  else
    record_failure "Safari pop-ups blocked"
  fi

  apply_default "Safari auto-update extensions" com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

  apply_default "Safari thumbnail cache off" com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

fi # SAFARI_FDA_OK

# ── Apple Intelligence ─────────────────────────────────────────────
# NO se toca. Esta maquina vive dentro del ecosistema Apple y ahi Apple
# Intelligence es una funcion que se usa, no bloat. El master vive en Ajustes >
# Apple Intelligence y Siri y no tiene key publica igual: lo que habia aca era
# un opt-out por feature (ID 545129924) que ni siquiera gobernaba el master, y
# un aviso que repetia en cada corrida un consejo que no se puede seguir.
# Ademas el ID cambia entre updates (comunidad: macos-defaults.com), asi que
# fijarlo es fragil por diseno. Solo se lee el estado para dejarlo declarado.
_AI_MASTER="$(defaults read com.apple.CloudSubscriptionFeatures.optIn auto_opt_in 2>/dev/null || true)"
if [ "$_AI_MASTER" = "1" ]; then
  echo "[--] Apple Intelligence master ON (auto_opt_in=1, en uso en esta maquina)"
elif [ "$_AI_MASTER" = "0" ]; then
  echo "[--] Apple Intelligence master OFF (auto_opt_in=0)"
else
  echo "[--] Apple Intelligence master sin estado legible (revisar en Ajustes > Apple Intelligence y Siri)"
fi
unset _AI_MASTER

# ── Xcode & Simulator ──────────────────────────────────────────────
apply_default "Xcode DVT debug menu" com.apple.dt.Xcode ShowDVTDebugMenu -bool YES

apply_default "Xcode Cloud upsell suppressed" com.apple.dt.Xcode XcodeCloudUpsellPromptEnabled -bool false

apply_default "Xcode indexing numeric progress" com.apple.dt.Xcode IDEIndexerActivityShowNumericProgress -bool true

apply_default "Xcode file extensions visible" com.apple.dt.Xcode IDEFileExtensionDisplayMode -int 1

apply_default "Xcode build version in Dock icon" com.apple.dt.Xcode DVTEnableDockIconVersionNumber -bool YES

apply_default "Xcode no state restoration on launch" com.apple.dt.Xcode IDEDisableStateRestoration -bool YES

apply_default "Xcode no auto-reopen last project" com.apple.dt.Xcode ApplePersistenceIgnoreState -bool YES

apply_default "Simulator show touches" com.apple.iphonesimulator ShowSingleTouches -int 1

# Parallel build: usa todos los cores disponibles (no limitar a 1-2)
apply_default "Xcode parallel build (max cores)" com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks -int 0

# Duracion del build junto a "Succeeded" en la toolbar. El default de Apple es
# NO. En un fanless que thermal-throttlea, ver cuanto tardo cada build es la
# forma barata de notar que la maquina empezo a bajar de frecuencia.
apply_default "Xcode muestra duracion del build" com.apple.dt.Xcode ShowBuildOperationDuration -bool true

# Press-and-hold POR APP, nunca global. Mantener una tecla en VS Code repite el
# caracter en vez de abrir el menu de acentos, que es lo que hace usable el
# modo Vim (hold j/k). La version global de esta key esta prohibida en este
# repo: en un teclado en español mata el menu de acentos en TODAS las apps, y
# por eso se removio en su momento. Acotarla por bundle-id es lo que la vuelve
# segura — se escriben las tildes normal en cualquier otro lado.
if [ -d "/Applications/Visual Studio Code.app" ]; then
  apply_default "VS Code: hold repite tecla (Vim)" com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
else
  echo "[SKIP] VS Code no instalado (press-and-hold por app)"
fi

# ── Terminal ───────────────────────────────────────────────────────
apply_default "Terminal hide line marks" com.apple.Terminal ShowLineMarks -int 0

apply_default "Terminal Secure Keyboard Entry" com.apple.Terminal SecureKeyboardEntry -bool true

# UTF-8 only (prevents fallback to legacy encodings like MacRoman)
apply_default "Terminal UTF-8 only" com.apple.Terminal StringEncodings -array 4

# ── TextEdit ───────────────────────────────────────────────────────
apply_default "TextEdit plain text default" com.apple.TextEdit RichText -bool false

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] TextEdit UTF-8 encoding"
elif (
  defaults write com.apple.TextEdit PlainTextEncoding -int 4 &&
    defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
) 2>/dev/null; then
  echo "[SET] TextEdit UTF-8 encoding"
else
  record_failure "TextEdit UTF-8 encoding"
fi

# ── Activity Monitor ───────────────────────────────────────────────
# Delete old key to reset Dock icon to default
delete_default "Activity Monitor default Dock icon" com.apple.ActivityMonitor IconType

apply_default "Activity Monitor refresh = 2s" com.apple.ActivityMonitor UpdatePeriod -int 2

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Activity Monitor sort by CPU usage"
elif (
  defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage" &&
    defaults write com.apple.ActivityMonitor SortDirection -int 0
) 2>/dev/null; then
  echo "[SET] Activity Monitor sort by CPU usage"
else
  record_failure "Activity Monitor sort by CPU usage"
fi

# 100 = todos los procesos. El 0 anterior era otra categoria, no "todos".
apply_default "Activity Monitor show all processes" com.apple.ActivityMonitor ShowCategory -int 100

# ── Console ────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Console debug menu + private logs"
elif (
  defaults write com.apple.Console DebugMenuEnabled -bool true &&
    defaults write com.apple.Console PrivateLogsEnabled -bool true
) 2>/dev/null; then
  echo "[SET] Console debug menu + private logs"
else
  record_failure "Console debug menu + private logs"
fi

# ── Help Viewer ────────────────────────────────────────────────────
apply_default "Help Viewer doesn't float on top" com.apple.helpviewer DevMode -bool true

# ── Calendar ───────────────────────────────────────────────────────
apply_default "Calendar debug menu" com.apple.iCal IncludeDebugMenu -bool true

# ── Notification Center ────────────────────────────────────────────
apply_default "Notification banner time = 3s" com.apple.notificationcenterui bannerTime -int 3

# ── Login Window ───────────────────────────────────────────────────
apply_default "Login window show full name" com.apple.loginwindow SHOWFULLNAME -bool true

# ── Menu Bar ───────────────────────────────────────────────────────
apply_default "Battery percentage in menu bar" com.apple.menuextra.battery ShowPercent -bool true

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Clock: digital, 24h, minimal"
elif (
  defaults write com.apple.menuextra.clock IsAnalog -bool false &&
    defaults write com.apple.menuextra.clock ShowSeconds -bool false &&
    defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false &&
    defaults write com.apple.menuextra.clock ShowDate -int 0 &&
    defaults write com.apple.menuextra.clock Show24Hour -bool true
) 2>/dev/null; then
  echo "[SET] Clock: digital, 24h, minimal"
else
  record_failure "Clock: digital, 24h, minimal"
fi
# DateFormat unificado (reemplaza keys individuales en Sequoia+).
# OJO: en esta maquina esta key no persiste — macOS la borra y deja el formato
# derivado de Show24Hour + la region. Se mantiene por si en otra version pega.
apply_default "Clock: formato HH:mm (DateFormat)" com.apple.menuextra.clock DateFormat -string "HH:mm"

# ── App Store ──────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] App Store debug menu enabled"
elif (
  defaults write com.apple.appstore ShowDebugMenu -bool true &&
    defaults write com.apple.appstore IncludeDebugMenu -bool true &&
    defaults write com.apple.appstore WebKitDeveloperExtras -bool true
) 2>/dev/null; then
  echo "[SET] App Store debug menu enabled"
else
  record_failure "App Store debug menu enabled"
fi

# Auto-update App Store apps (security: outdated apps = attack surface)
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] App Store auto-update + auto-restart"
elif (
  defaults write com.apple.commerce AutoUpdate -bool true &&
    defaults write com.apple.commerce AutoUpdateRestartRequired -bool true
) 2>/dev/null; then
  echo "[SET] App Store auto-update + auto-restart"
else
  record_failure "App Store auto-update + auto-restart"
fi

# ── Software Update ────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Software Update: daily check + auto critical installs"
elif (
  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true &&
    defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1 &&
    defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1 &&
    defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1 &&
    defaults write com.apple.SoftwareUpdate ConfigDataInstall -int 1
) 2>/dev/null; then
  echo "[SET] Software Update: daily check + auto critical installs"
else
  record_failure "Software Update: daily check + auto critical installs"
fi

# ── Spotlight ──────────────────────────────────────────────────────
apply_default "Spotlight suggestions disabled" com.apple.Spotlight SuggestionsEnabled -bool false

apply_default "Spotlight server suggestions disabled" com.apple.Spotlight ServerSuggestionsEnabled -bool false

apply_default "Spotlight menu bar icon hidden" com.apple.Spotlight MenuBarSpotlightIcon -bool false

# ── Sound ──────────────────────────────────────────────────────────
apply_default "Volume change feedback silent" -g com.apple.sound.beep.feedback -int 0

# ── Library ────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] chflags nohidden ~/Library"
elif chflags nohidden "$HOME/Library"; then
  echo "[SET] ~/Library visible"
else
  record_failure "${HOME}/Library visible"
fi

# Reduce Transparency: alivio de CPU de WindowServer observado en Sequoia, sin
# medicion propia en este repo — no se cita un porcentaje que nadie midio. En
# Tahoe la key quedo rota en 26.1 y 26.2 (dejaba sidebars, headers y titlebars
# translucidos, con texto superpuesto) y se arreglo en 26.3. Solo esa ventana
# se salta; de 26.3 en adelante vuelve a ser el alivio de siempre con Liquid
# Glass. Notar que activarla deshabilita el selector Clear/Tinted de Ajustes >
# Apariencia: son mutuamente excluyentes.
if [ "$MACOS_MAJOR" -eq 26 ] && [ "$MACOS_MINOR" -lt 3 ]; then
  echo "[SKIP] Reduce Transparency (roto en 26.0-26.2, arreglado en 26.3)"
else
  apply_default "Reduce Transparency (alivio de WindowServer)" com.apple.universalaccess reduceTransparency -bool true
fi

# ── Zoom de pantalla ───────────────────────────────────────────────
# ctrl + scroll hace zoom. 262144 es la mascara del modificador Control.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Zoom con ctrl + scroll"
elif (
  defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true &&
    defaults write com.apple.universalaccess closeViewScrollWheelModifiersInt -int 262144
) 2>/dev/null; then
  echo "[SET] Zoom con ctrl + scroll"
else
  record_failure "Zoom con ctrl + scroll"
fi

apply_default "Sin atajos de teclado para el zoom" com.apple.universalaccess closeViewHotkeysEnabled -bool false

# ── Control Center / barra de menu ─────────────────────────────────
# Barra de menu al minimo: reloj, Control Center y Sonido. El resto sigue
# accesible desde el BentoBox, no se desactiva nada.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Barra de menu minima (reloj + Control Center)"
elif (
  defaults write com.apple.controlcenter "NSStatusItem Visible BentoBox" -bool true &&
    defaults write com.apple.controlcenter "NSStatusItem Visible Clock" -bool true &&
    defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool false &&
    defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool false &&
    defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool true &&
    defaults write com.apple.controlcenter "NSStatusItem Visible NowPlaying" -bool false &&
    defaults write com.apple.controlcenter "NSStatusItem Visible FocusModes" -bool false &&
    defaults write com.apple.controlcenter "NSStatusItem Visible AudioVideoModule" -bool false &&
    defaults write com.apple.controlcenter "NSStatusItem Visible Timer" -bool false
) 2>/dev/null; then
  echo "[SET] Barra de menu minima (reloj + Control Center)"
else
  record_failure "Barra de menu minima (reloj + Control Center)"
fi

# PREFERENCIA PERSONAL. La barra de menu se oculta hasta que pasas el mouse
# arriba: mas espacio vertical. Ningun Mac sale de fabrica asi, y si usas
# Bartender u otro gestor de iconos revisa que no compita con el.
# Revertir: defaults delete NSGlobalDomain _HIHideMenuBar
apply_default "Menu bar auto-hide" NSGlobalDomain _HIHideMenuBar -bool true

# ══════════════════════════════════════════════════════════════════
# TIER 2 — requiere sudo
# ══════════════════════════════════════════════════════════════════
# Vivia como texto suelto en el README bajo "Recomendaciones con sudo" y
# nunca se ejecutaba. Cada item verifica el estado real antes de escribir;
# lo que ya esta bien en esta instalacion se reporta y no se toca. El firewall
# si se enciende desde aca cuando esta apagado; SIP, Gatekeeper y FileVault no
# se tocan nunca — solo se verifican mas abajo, por los limites tecnicos que
# ese bloque documenta. Todo el tier corre dentro de UNA sola sesion root
# (`sudo bash` con heredoc citado): con timestamp_timeout=0 instalado cada
# `sudo` suelto re-pide password por diseño (CIS 5.4), asi que N invocaciones
# sueltas son N prompts aunque el timestamp este caliente y `sudo -v` ya no
# ayuda. Una sola invocacion de `sudo` es un solo prompt. Ad-hoc sudo fuera
# del script sigue pidiendo password cada vez mientras el drop-in exista, por
# diseño.
if [ "$NO_SUDO" -eq 1 ]; then
  echo "=== Tier sudo saltado (--no-sudo) ==="
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "=== Tier sudo (dry-run, no pide password) ==="
  echo "[DRY] sudo bash (tier completo en una sesion root)"
  echo "[DRY] sudo DevToolsSecurity -enable (si developer mode no esta habilitado)"
  echo "[DRY] sudo pmset -a powernap 0 (si Power Nap sigue activo)"
  echo "[DRY] sudo pmset -b lowpowermode 1 + -c lowpowermode 0 (segun estado)"
  echo "[DRY] sudo pmset -c womp 1 (si AC no lo tiene ya en 1)"
  echo "[DRY] sudo pmset -b womp 0 (si bateria no lo tiene ya en 0)"
  echo "[DRY] sudo pmset -a proximitywake 1"
  echo "[DRY] sudo pmset -a autorestart 1 + systemsetup -setrestartfreeze on (si no esta configurado)"
  echo "[DRY] sudo systemsetup -setremotelogin off (si SSH esta prendido)"
  echo "[DRY] sudo systemsetup -setnetworktimeserver time.apple.com + -setusingnetworktime on (si NTP no apunta ahi)"
  echo "[DRY] sudo defaults write ...loginwindow LoginwindowText (si no hay banner)"
  echo "[DRY] sudo defaults write ...mDNSResponder NoMulticastAdvertisements (solo con --bonjour-off)"
  echo "[DRY] sudo chflags nohidden /Volumes (si esta oculto)"
  echo "[DRY] sudo defaults write ...loginwindow AdminHostInfo HostName (si no es HostName)"
  echo "[DRY] Touch ID para sudo via /etc/pam.d/sudo_local (si hay template y no hay config)"
  echo "[DRY] sudo socketfilterfw --setglobalstate on + --setstealthmode on (si estan apagados)"
  echo "[DRY] sudo socketfilterfw --add /usr/libexec/rapportd + --unblockapp (si falta en --listapps)"
  echo "[DRY] sudo socketfilterfw --add /usr/libexec/sharingd + --unblockapp (si falta en --listapps)"
  echo "[DRY] sudo install -m 0440 drop-in timestamp_timeout=0 en /etc/sudoers.d (dentro de la sesion root: si no hay timeout, validado con visudo -c)"
else
  # Una sola sesion root para todo el tier: UN solo prompt al inicio. Sin
  # keep-alive de fondo: el tier corre en segundos (~1-2 min con todo por
  # aplicar), muy por debajo de cualquier timeout, y un loop con trap sumaria
  # modos de fallo (huerfanos con set -e) sin beneficio real.
  # La sesion root NO usa `set -e` a proposito: cada item captura su propio
  # fallo (tier_apply/tier_fail) y el tier sigue; al final la sesion sale con
  # la cantidad de fallos como exit code y el padre lo suma a
  # DEFAULTS_FAILURES. Variables del usuario entran por un archivo env
  # temporal pasado como $1 (LOGIN_BANNER, BONJOUR_OFF, TIER_USER,
  # FIREWALL_CLI): `sudo VAR=x cmd` NO es fiable — sudoers con env_reset
  # (default macOS) puede descartarlas en silencio y el tier moriria en la
  # guarda. Los argv en cambio siempre llegan. El heredoc va citado
  # ('TIER_EOF') asi que nada se expande en la shell del usuario.
  echo "=== Tier sudo: una sola sesion root (tu password se pide una vez) ==="
  # El default del banner se resuelve aca, en la shell del usuario, antes de
  # pasarlo por argv: respeta LOGIN_BANNER exportado igual que antes.
  : "${LOGIN_BANNER:=Si encuentra este Mac, por favor escriba a tu-email@ejemplo.com. Se ofrece recompensa. Find My activado.}"
  FIREWALL_CLI=/usr/libexec/ApplicationFirewall/socketfilterfw
  _TIER_ENV=$(mktemp)
  {
    printf 'LOGIN_BANNER=%q\n' "$LOGIN_BANNER"
    printf 'BONJOUR_OFF=%q\n' "$BONJOUR_OFF"
    printf 'TIER_USER=%q\n' "$(id -un)"
    printf 'FIREWALL_CLI=%q\n' "$FIREWALL_CLI"
  } > "$_TIER_ENV"
  # set +e: el exit code de la sesion root se procesa a mano abajo; con
  # set -e activo un tier con fallos abortaria el script en vez de sumar.
  set +e
  sudo bash -s "$_TIER_ENV" <<'TIER_EOF'
set -u
# Guarda de env: si alguna variable no llego a la sesion root, fallar con
# mensaje claro en vez de operar con valores vacios.
source "$1"
: "${LOGIN_BANNER:?LOGIN_BANNER no llego a la sesion root}"
: "${BONJOUR_OFF:?BONJOUR_OFF no llego a la sesion root}"
: "${TIER_USER:?TIER_USER no llego a la sesion root}"
: "${FIREWALL_CLI:?FIREWALL_CLI no llego a la sesion root}"
TIER_FAILURES=0
tier_fail() {
  TIER_FAILURES=$((TIER_FAILURES + 1))
  echo "[FAIL] $1"
}
tier_apply() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[SET] $label"
  else
    tier_fail "$label"
  fi
}

  # Developer mode: sin esto Xcode y los debuggers piden auth cada vez que
  # se adjuntan a un proceso. La lectura de status no pide sudo.
  if DevToolsSecurity -status 2>/dev/null | grep -qi "enabled"; then
    echo "[SKIP] Developer mode ya habilitado"
  else
    tier_apply "Developer mode (DevToolsSecurity)" DevToolsSecurity -enable
  fi

  # Power Nap: despierta la Mac dormida para mail/iCloud/Time Machine —
  # bateria y snapshots de Time Machine de fondo sin que la pidas.
  #
  # Con powernap 0 la Mac dormida no despierta a sincronizar iCloud/Mail ni a
  # correr Time Machine. En una maquina con iPhone al lado y sin destino de
  # Time Machine configurado, eso no cuesta nada concreto.
  #
  # Lo que NO cuesta, aclarado porque es facil confundirlo: **ubicar la Mac en
  # Buscar sigue funcionando dormida**. Find My usa un mecanismo aparte
  # (Search Party) que emite beacons Bluetooth cifrados que recogen otros
  # equipos Apple cercanos, y no depende de powernap ni de womp. El limite ahi
  # es el estado de energia: una Mac apagada del todo no se encuentra, porque
  # Apple Silicon no tiene el beacon en apagado que si tiene un AirTag.
  # Revertir: sudo pmset -a powernap 1
  if pmset -g custom | grep -Eq "powernap[[:space:]]+1"; then
    tier_apply "Power Nap off (AC + bateria)" pmset -a powernap 0
  else
    echo "[SKIP] Power Nap ya desactivado"
  fi

  # Low Power Mode solo en bateria. En AC se fuerza apagado a proposito: en un
  # fanless capea CPU y GPU, y no tiene sentido pagar builds mas lentos cuando
  # hay enchufe. Con bateria el intercambio si conviene. Se usa `-b` y `-c` en
  # vez de `-a` justamente para que los dos lados queden distintos.
  if pmset -g custom | awk '/Battery Power/,/AC Power/' | grep -Eq "lowpowermode[[:space:]]+1"; then
    echo "[SKIP] Low Power Mode ya activo en bateria"
  else
    tier_apply "Low Power Mode en bateria" pmset -b lowpowermode 1
  fi
  if pmset -g custom | awk '/AC Power/,0' | grep -Eq "lowpowermode[[:space:]]+0"; then
    echo "[SKIP] Low Power Mode ya apagado en AC"
  else
    tier_apply "Low Power Mode apagado en AC" pmset -c lowpowermode 0
  fi

  # Wake for network access separado por fuente, mismo criterio que
  # lowpowermode: el costo de apagarlo solo vale la pena donde despertar
  # cuesta algo.
  #
  # COSTO CONCRETO de womp 0, distinto del de powernap: se pierden el bloqueo y
  # el borrado remotos mientras la Mac duerme. macOS lo dice con todas las
  # letras — "You won't be able to locate, lock, or erase this Mac while it's
  # asleep because Wake for network access is turned off". Ubicarla igual
  # funciona por el beacon Bluetooth, pero ese beacon solo reporta posicion: no
  # puede recibir una orden. Para bloquear o borrar hace falta que el equipo
  # despierte por red.
  #
  # En AC no hay bateria que preservar, asi que la capacidad se deja prendida.
  # En bateria si conviene apagarla: una maquina desatendida en una mochila no
  # deberia despertar por cada paquete unicast.
  #
  # `pmset -g cap` imprime solo la fuente ACTIVA: con bateria muestra la
  # seccion "Capabilities for Battery Power:" (verificado en este M3 Air
  # descargando: incluye womp) y con cargador muestra la de AC. womp existe
  # en ambas, y `pmset -b womp 0` persiste (visible en `pmset -g custom`) y
  # es funcional: es lo que apaga el wake por red cuando no hay enchufe.
  # Revertir por fuente: sudo pmset -c womp 0 (AC) / sudo pmset -b womp 1 (bateria)
  if pmset -g custom | awk '/AC Power/,0' | grep -Eq "womp[[:space:]]+1"; then
    echo "[SKIP] Wake for network ya activo en AC"
  else
    tier_apply "Wake for network activo en AC (lock/erase remoto)" pmset -c womp 1
  fi
  if pmset -g custom | awk '/Battery Power/,/AC Power/' | grep -Eq "womp[[:space:]]+0"; then
    echo "[SKIP] Wake for network ya apagado en bateria"
  else
    tier_apply "Wake for network apagado en bateria" pmset -b womp 0
  fi

  # proximitywake se aplica con `-a` y sin guard a proposito: no aparece ni en
  # `pmset -g custom` ni en `pmset -g cap`, asi que no hay estado que leer para
  # decidir un [SKIP], y despertar al acercar un dispositivo Apple no depende
  # de la fuente de poder. Solo tiene efecto en hardware compatible; pmset
  # acepta el write igual.
  tier_apply "Wake por proximidad de dispositivo Apple" pmset -a proximitywake 1

  # Auto-restart tras freeze o corte de luz. Verificado con el cargador
  # puesto: `pmset -g cap` no lista "autorestart" entre las capacidades de
  # este M3 Air (si aparece en un iMac). El write de abajo devuelve exito
  # igual — probable no-op de hardware, mismo patron que askForPassword en
  # screensaver. Se deja (es inocuo, sudo -a autorestart 1 no rompe nada) pero
  # no asumas que hizo algo solo porque no fallo.
  if pmset -g | grep -Eq "^ autorestart[[:space:]]+1$"; then
    echo "[SKIP] Auto-restart ya configurado"
  else
    tier_apply "Auto-restart en freeze/corte de luz (pmset)" pmset -a autorestart 1
    tier_apply "Auto-restart en freeze (systemsetup)" systemsetup -setrestartfreeze on
  fi

  # SSH remoto: solo se toca si esta prendido. Si lo usas para desarrollo,
  # no corras esto — dejalo en On a mano.
  if systemsetup -getremotelogin 2>/dev/null | grep -qi "On"; then
    tier_apply "SSH remoto apagado" systemsetup -setremotelogin off
  else
    echo "[SKIP] SSH remoto ya apagado"
  fi

  # NTP contra time.apple.com (CIS: hora confiable sostiene Kerberos, TLS y
  # firmas de backup). systemsetup tira warnings de deprecado en 13+ pero
  # sigue aplicando. Revertir: sudo systemsetup -setusingnetworktime off
  if systemsetup -getusingnetworktime 2>/dev/null | grep -qi "On" &&
    systemsetup -getnetworktimeserver 2>/dev/null | grep -q "time.apple.com"; then
    echo "[SKIP] NTP ya en time.apple.com"
  else
    tier_apply "NTP en time.apple.com" systemsetup -setnetworktimeserver time.apple.com
    tier_apply "Hora de red activada" systemsetup -setusingnetworktime on
  fi

  # Banner de login (CIS 5.8 / Apple HT203580: LoginwindowText es key
  # documentada del payload com.apple.loginwindow). Plantilla generica de
  # equipo extraviado: sirve igual para uso personal y para quien reutilice
  # este script. Personalizar con un email SECUNDARIO (nunca el Apple ID ni
  # el numero principal: el banner queda visible 24/7 en la pantalla de
  # bloqueo). O exportar LOGIN_BANNER antes de correr el script para usar
  # texto propio. No es PolicyBanner con aceptacion obligatoria. Con
  # FileVault el banner aparece despues del unlock, no en el login preboot.
  # Revertir: sudo defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText
  if defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null | grep -q .; then
    echo "[SKIP] Banner de login ya configurado"
  else
    tier_apply "Banner de login (equipo extraviado)" \
      defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText -string "$LOGIN_BANNER"
  fi

  # Bonjour multicast (CIS Benchmark Level 1) — opt-in explicito. Rompe
  # descubrimiento de impresoras Bonjour, servidores DLNA y Home Assistant en
  # la LAN. AirDrop/AirPlay no se ven afectados: usan AWDL, no mDNS multicast.
  if [ "$BONJOUR_OFF" -eq 1 ]; then
    if defaults read /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements 2>/dev/null | grep -q 1; then
      echo "[SKIP] Bonjour multicast ya desactivado"
    else
      tier_apply "Bonjour multicast desactivado (--bonjour-off)" \
        defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool YES
      killall mDNSResponder 2>/dev/null || true
    fi
  fi

  # /Volumes visible en Finder: util para debuggear mounts, DMGs y volumenes
  # de Docker.
  if [ "$(stat -f '%Sf' /Volumes)" = "-" ]; then
    echo "[SKIP] /Volumes ya visible"
  else
    tier_apply "/Volumes visible en Finder" chflags nohidden /Volumes
  fi

  if defaults read /Library/Preferences/com.apple.loginwindow AdminHostInfo 2>/dev/null | grep -qx "HostName"; then
    echo "[SKIP] Login Window muestra HostName"
  else
    tier_apply "Login Window muestra HostName" \
      defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
  fi

  # Touch ID para sudo — mecanismo oficial sudo_local de Apple (Sonoma+),
  # sobrevive updates de macOS. Idempotente: no pisa una config custom.
  if [ -f /etc/pam.d/sudo_local ]; then
    echo "[SKIP] Touch ID para sudo ya configurado (sudo_local)"
  elif [ -f /etc/pam.d/sudo_local.template ]; then
    if sed 's/^#auth/auth/' /etc/pam.d/sudo_local.template | tee /etc/pam.d/sudo_local >/dev/null; then
      echo "[SET] Touch ID para sudo activado (sudo_local)"
    else
      tier_fail "Touch ID para sudo (no se pudo escribir sudo_local)"
    fi
  else
    echo "[SKIP] Touch ID para sudo no disponible (requiere macOS 14+)"
  fi

  # ── Firewall: se enciende, no solo se avisa ──────────────────────
  # Encender el firewall es aditivo y reversible, asi que el script lo hace en
  # vez de limitarse a reportarlo. Stealth mode no responde ping ni ICMP: si
  # algun dia depuras la red de esta maquina desde afuera, apagalo con
  # `sudo socketfilterfw --setstealthmode off`.
  # FIREWALL_CLI llega por env desde la shell del usuario (ver guarda arriba).
  if "$FIREWALL_CLI" --getglobalstate 2>/dev/null | grep -qi enabled; then
    echo "[SKIP] Firewall ya encendido"
  else
    tier_apply "Firewall encendido" "$FIREWALL_CLI" --setglobalstate on
  fi
  if "$FIREWALL_CLI" --getstealthmode 2>/dev/null | grep -qi "stealth mode is on"; then
    echo "[SKIP] Stealth mode ya encendido"
  else
    tier_apply "Firewall stealth mode" "$FIREWALL_CLI" --setstealthmode on
  fi

  # ── Firewall: excepciones para discovery de continuidad ──────────
  # Con firewall + stealth on, rapportd (discovery de AirDrop/Handoff) y
  # sharingd (AirDrop/compartir) pueden quedar bloqueados. Se registran con
  # --add y se les permite entrante con --unblockapp: preserva AirDrop/Handoff
  # discovery con firewall on. Idempotente: si ya estan en --listapps, [SKIP].
  # Revertir: sudo "$FIREWALL_CLI" --remove /usr/libexec/rapportd (idem sharingd)
  for _fw_app in /usr/libexec/rapportd /usr/libexec/sharingd; do
    if "$FIREWALL_CLI" --listapps 2>/dev/null | grep -q "$_fw_app"; then
      echo "[SKIP] Firewall ya permite $_fw_app"
    else
      tier_apply "Firewall permite $_fw_app" "$FIREWALL_CLI" --add "$_fw_app"
      tier_apply "Firewall desbloquea $_fw_app" "$FIREWALL_CLI" --unblockapp "$_fw_app"
    fi
  done
  unset _fw_app

  # `id -un` NO sirve aca: dentro de la sesion root devuelve root. El
  # usuario invocante entra por env como TIER_USER (ver guarda arriba).
  if sysadminctl -secureTokenStatus "$TIER_USER" 2>&1 | grep -qi "ENABLED"; then
    echo "[OK] Secure Token enabled"
  else
    echo "[WARN] Secure Token: revisar con 'sysadminctl -secureTokenStatus'"
  fi
  if defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled 2>/dev/null | grep -q 1; then
    echo "[OK] HiDPI para monitores 4K habilitado"
  else
    echo "[SKIP] HiDPI no habilitado (solo hace falta con monitor 4K externo)"
  fi

  # Sudo sin grace period (CIS 5.4 + MITRE T1548.003: el timestamp de sudo
  # permite ejecutar sin password dentro de la ventana). Drop-in en
  # /etc/sudoers.d sin extension (macOS ignora los archivos con punto),
  # 0440 root:wheel, validado con visudo -c ANTES de instalar: si la
  # validacion falla no se instala nada. tty_tickets ya es default desde
  # Sierra, no hay nada que fijar.
  # El orden dentro del tier ya no importa: todo corre en la misma sesion
  # root, asi que instalarlo aca no invalida nada de esta corrida. OJO: a
  # partir de la proxima corrida cada sudo suelto —fuera del script, o el
  # `tmutil` del Tier 3 si falta alguna exclusion— pide password por diseño;
  # en corridas siguientes los guards hacen [SKIP] y no se nota.
  # Revertir: sudo rm /etc/sudoers.d/10_cis_timestamp_timeout
  if grep -Rhq "timestamp_timeout" /etc/sudoers /etc/sudoers.d/ 2>/dev/null; then
    echo "[SKIP] Sudo timeout ya configurado"
  elif [ ! -d /etc/sudoers.d ]; then
    echo "[WARN] Sudo timeout: no existe /etc/sudoers.d, no se toca sudoers (ver CIS 5.4)"
  else
    _sudoers_tmp="$(mktemp /tmp/sudoers_drop.XXXXXX)"
    printf '%s\n' "Defaults timestamp_timeout=0" >"$_sudoers_tmp"
    if visudo -cf "$_sudoers_tmp" >/dev/null 2>&1; then
      if install -o root -g wheel -m 0440 "$_sudoers_tmp" /etc/sudoers.d/10_cis_timestamp_timeout; then
        echo "[SET] Sudo timeout=0 (cada sudo pide password)"
      else
        tier_fail "Sudo timeout=0 (no se pudo instalar el drop-in)"
      fi
    else
      tier_fail "Sudo timeout=0 (visudo rechazo el drop-in, no se instalo nada)"
    fi
    rm -f "$_sudoers_tmp"
    unset _sudoers_tmp
  fi
# La sesion root sale con la cantidad de fallos: el padre la suma a
# DEFAULTS_FAILURES (ver abajo). Sin esto los [FAIL] se imprimirian pero el
# script terminaria en exit 0.
exit "$TIER_FAILURES"
TIER_EOF
  _tier_rc=$?
  set -e
  rm -f "$_TIER_ENV"
  unset _TIER_ENV
  # rc > 100 no puede ser un conteo de fallos (el tier tiene ~25 items):
  # es una muerte anormal (señal, sudo cancelado) y se reporta como tal.
  if [ "$_tier_rc" -gt 100 ]; then
    record_failure "Tier sudo (sesion root termino con rc=$_tier_rc)"
  else
    DEFAULTS_FAILURES=$((DEFAULTS_FAILURES + _tier_rc))
  fi
  unset _tier_rc FIREWALL_CLI
fi

# ══════════════════════════════════════════════════════════════════
# Verificacion de seguridad — corre SIEMPRE, tambien con --no-sudo
# ══════════════════════════════════════════════════════════════════
# Antes vivia dentro del tier 2, asi que `--no-sudo` terminaba sin reportar una
# sola linea de seguridad. Ninguna de estas lecturas necesita privilegios
# (verificado ejecutandolas sin sudo), asi que gatearlas dejaba ciego justo al
# modo pensado para correr sin ellos.
#
# Lo que queda como aviso y no como accion es porque no se puede automatizar,
# no por prudencia:
#   FileVault   `fdesetup enable` genera una llave de recuperacion. Una corrida
#               no interactiva la descarta, y sin esa llave un olvido de
#               password deja el disco irrecuperable. Se activa a mano.
#   SIP         `csrutil enable` responde "This tool needs to be executed from
#               Recovery OS". Imposible desde el sistema corriendo.
#   Gatekeeper  `spctl --master-enable` dejo de existir en Sequoia ("This
#               operation is no longer supported"). Solo se re-arma desde
#               Ajustes > Privacidad y seguridad.
#   Bloqueo     `sysadminctl -screenLock` exige `-password <password>` en
#               claro. No se le pasa la password a un script.
echo "=== Verificacion de seguridad (solo lectura) ==="
if fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
  echo "[OK] FileVault On"
else
  echo "[WARN] FileVault apagado: activalo en Ajustes > Privacidad y seguridad" \
    "y guarda la llave de recuperacion"
fi
if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -qi enabled; then
  echo "[OK] Firewall enabled"
else
  echo "[WARN] Firewall apagado: corre el script sin --no-sudo para encenderlo"
fi
if /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | grep -qi "stealth mode is on"; then
  echo "[OK] Firewall stealth mode on"
else
  echo "[WARN] Stealth mode apagado: corre el script sin --no-sudo para encenderlo"
fi
if csrutil status 2>/dev/null | grep -qi "enabled"; then
  echo "[OK] SIP enabled"
else
  echo "[WARN] SIP disabled — solo se reactiva desde Recovery OS"
fi
if spctl --status 2>/dev/null | grep -qi "assessments enabled"; then
  echo "[OK] Gatekeeper enabled"
else
  echo "[WARN] Gatekeeper apagado — desde Sequoia solo se re-arma en Ajustes"
fi
if sysadminctl -screenLock status 2>&1 | grep -qi "immediate"; then
  echo "[OK] Bloqueo de pantalla inmediato"
else
  echo "[WARN] Bloqueo de pantalla: revisar en Ajustes > Pantalla bloqueada"
fi
# Sharing + guest + auto-login: todo legible sin sudo. Screen Sharing, Remote
# Management y Remote Apple Events jamas se habilitaron si sus plists ni
# existen; si existen se revisan en GUI. El estado on/off de File Sharing en
# si requiere sudo (ya se cubre SSH en Tier 2), aca solo se listan los share
# points SMB como dato. Checklist completa en README.
if [ "$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo 0)" = "0" ]; then
  echo "[OK] Cuenta de invitado desactivada"
else
  echo "[WARN] Cuenta de invitado activa: desactivar en Ajustes > Usuarios y grupos"
fi
if defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser >/dev/null 2>&1; then
  echo "[WARN] Auto-login activo ($(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null)): desactivar en Ajustes > Usuarios y grupos"
else
  echo "[OK] Sin auto-login"
fi
for _share_plist in com.apple.screensharing com.apple.RemoteManagement com.apple.AppleEvents; do
  if [ -e "/Library/Preferences/${_share_plist}.plist" ]; then
    echo "[--] ${_share_plist}: plist presente, revisar servicio en Ajustes > General > Compartir"
  fi
done
unset _share_plist
if [ ! -e /Library/Preferences/com.apple.screensharing.plist ] &&
  [ ! -e /Library/Preferences/com.apple.RemoteManagement.plist ] &&
  [ ! -e /Library/Preferences/com.apple.AppleEvents.plist ]; then
  echo "[OK] Screen Sharing / Remote Management / Remote Apple Events sin rastros de habilitacion"
fi
if cupsctl 2>/dev/null | grep -q "_share_printers=0"; then
  echo "[OK] Printer sharing apagado"
else
  echo "[WARN] Printer sharing: revisar en Ajustes > General > Compartir"
fi
_SMB_SHARES="$(sharing -l 2>/dev/null | grep -c "shared:" || true)"
if [ -n "$_SMB_SHARES" ] && [ "$_SMB_SHARES" -gt 0 ]; then
  echo "[--] ${_SMB_SHARES} share point(s) SMB (ej: carpeta Publica por defecto). File Sharing on/off en Ajustes > General > Compartir"
fi
unset _SMB_SHARES
# Backup. Va aca y no en un tier opcional porque en la practica es el control
# que mas importa: FileVault sin backup no protege los datos, los vuelve
# irrecuperables si el SSD muere o se pierde la password. El script no puede
# configurarlo (necesita un disco o destino de red real), asi que avisa.
# El patron va anclado a inicio de linea: `Name` cubre destinos USB y `URL` los
# de red (AFP/SMB). Sin anclar, cualquier mensaje de error que mencione esas
# palabras daria un falso [OK] y el aviso desapareceria justo cuando importa.
if tmutil destinationinfo 2>/dev/null | grep -qiE "^[[:space:]]*(Name|URL)[[:space:]]*:"; then
  echo "[OK] Time Machine con destino configurado"
  # Frescura del ultimo backup: el path termina en YYYY-MM-DD-HHMMSS.
  _TM_LATEST="$(tmutil latestbackup 2>/dev/null | tail -n 1)"
  _TM_DATE="$(printf '%s' "${_TM_LATEST##*/}" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' || true)"
  if [ -z "$_TM_DATE" ]; then
    echo "[WARN] Time Machine con destino pero sin backup completado (correr un backup a mano)"
  else
    _TM_EPOCH="$(date -j -f "%Y-%m-%d-%H%M%S" "$_TM_DATE" "+%s" 2>/dev/null || true)"
    if [ -n "$_TM_EPOCH" ] && [ "$((($(date +%s) - _TM_EPOCH) / 86400))" -gt 7 ]; then
      echo "[WARN] Ultimo backup Time Machine hace mas de 7 dias ($_TM_DATE)"
    elif [ -n "$_TM_EPOCH" ]; then
      echo "[OK] Ultimo backup Time Machine: $_TM_DATE"
    else
      echo "[--] Ultimo backup Time Machine: $_TM_LATEST (fecha no parseable)"
    fi
    unset _TM_EPOCH
  fi
  unset _TM_LATEST _TM_DATE
  # Cifrado del destino: tmutil no siempre expone el campo segun el tipo de
  # destino, asi que lo desconocido se reporta y no se inventa. Jamas
  # setdestination desde aca: apunta a hardware real.
  _TM_ENC="$(tmutil destinationinfo 2>/dev/null | grep -i "encrypt" || true)"
  if [ -z "$_TM_ENC" ]; then
    echo "[--] TM cifrado: tmutil no lo expone para este destino, revisar en Ajustes > General > Time Machine"
  elif printf '%s' "$_TM_ENC" | grep -qi "yes"; then
    echo "[OK] Destino Time Machine cifrado"
  else
    echo "[WARN] Destino Time Machine sin cifrar ($_TM_ENC)"
  fi
  unset _TM_ENC
else
  echo "[WARN] Sin backup configurado. Con FileVault activo, un SSD muerto o" \
    "una password olvidada = datos perdidos. Ajustes > General > Time Machine."
fi

# Espacio libre. Se lee de `diskutil apfs list` y no de `df`: df reporta contra
# el snapshot sellado del sistema y da un numero que no es el que el kernel le
# entrega a una app. El umbral de 20% es heuristica de comunidad para dejar
# aire a swap, snapshots de APFS e indexado — Apple no publica un minimo.
# La linea trae dos grupos entre parentesis, "(160.3 GB)" y "(32.4% free)".
# Se extrae el que tiene el signo de porcentaje, no una posicion fija. Se usa
# grep -oE y no awk con match(s,r,arr): esa forma de match es de gawk y macOS
# trae BSD awk, donde falla.
FREE_PCT="$(diskutil apfs list 2>/dev/null |
  grep -m1 "Capacity Not Allocated" |
  grep -oE '[0-9]+\.?[0-9]*% free' |
  grep -oE '^[0-9]+')"
if [ -z "$FREE_PCT" ]; then
  echo "[--] Espacio libre: no se pudo leer de diskutil"
elif [ "$FREE_PCT" -lt 20 ]; then
  echo "[WARN] Solo ${FREE_PCT}% libre. Bajo 20% Tahoe pelea por swap," \
    "snapshots e indexado. Liberar espacio o 'tmutil thinlocalsnapshots'."
else
  echo "[OK] Espacio libre ${FREE_PCT}%"
fi

# Servicios escuchando en todas las interfaces. Esto es lo que decide si el
# firewall importa en esta maquina o no: con cero listeners el exposure es
# teorico, con listeners reales el firewall y el stealth mode hacen trabajo.
# Se mide en vez de asumirse. ControlCenter en 5000/7000 = AirPlay Receiver,
# que es la superficie de AirBorne (17 CVEs, CVE-2025-24252 es RCE zero-click
# en la misma red) y ademas se come el puerto 5000 que usa medio mundo para
# desarrollo. Es solo lectura: apagarlo es decision del usuario.
# `+c 0` desactiva el truncado de nombres a 9 caracteres, que convertia
# ControlCenter en "ControlCe". Se invoca lsof UNA vez y se reusa: con dos
# llamadas, el resumen y el test de AirPlay pueden discrepar si un proceso
# aparece o muere entre medio. La cantidad nunca se fija en el codigo, varia
# con lo que este corriendo.
LISTEN_RAW="$(lsof +c 0 -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk '$9 ~ /^\*:/')"
# lsof escapa los espacios del nombre como \x20 ("Stream\x20Deck"). Se
# desescapan y la lista va separada por comas, porque con nombres que tienen
# espacios una lista separada por espacios es ambigua.
LISTENERS="$(printf '%s\n' "$LISTEN_RAW" | awk 'NF {print $1}' | sort -u |
  sed 's/\\x20/ /g' | paste -sd ',' - | sed 's/,/, /g')"
if [ -z "$LISTENERS" ]; then
  echo "[OK] Sin servicios escuchando en todas las interfaces"
else
  echo "[--] Escuchando en todas las interfaces: ${LISTENERS}"
  # No se avisa por AirPlay Receiver (ControlCenter en 5000/7000): es parte del
  # ecosistema y aca se usa. Vale saber que existio AirBorne (17 CVEs, con
  # CVE-2025-24252 como RCE zero-click en la misma red), parchado desde 15.4 —
  # por eso el firewall con stealth mode importa en esta maquina y no es
  # decorativo. Si alguna vez choca el puerto 5000 con un server local, la
  # causa es esta y se apaga en Ajustes > General > AirDrop y Handoff.
fi

# ══════════════════════════════════════════════════════════════════
# TIER 3 — exclusiones de indexado sobre el arbol de desarrollo
# ══════════════════════════════════════════════════════════════════
# La ganancia real y medible en una maquina de desarrollo: Sequoia tiene una
# regresion documentada de indexado de Spotlight con CPU/IO altos, y el arbol
# de desarrollo (node_modules, builds, DerivedData) es lo que peor se
# comporta. `tmutil disablelocal` ya no existe desde High Sierra — esto es
# el reemplazo real. La parte de Spotlight (.metadata_never_index) no
# requiere sudo; la de Time Machine si — `tmutil addexclusion` sale con
# "requires root privileges" sin el (verificado, exit 80), asi que se salta
# con --no-sudo igual que el tier 2. No crea directorios: si la ruta no
# existe, se saltea. Con timestamp_timeout=0 instalado, cada exclusion que
# falte pide password una vez (el guard `isexcluded` es sin sudo y no pide
# nada); si todo ya esta excluido este tier no pide password.
echo "=== Tier 3: exclusiones de Spotlight (siempre) y Time Machine (requiere sudo) ==="
DEV_EXCLUDE_PATHS=(
  "$HOME/Developer"
  "$HOME/Library/Developer/Xcode/DerivedData"
  "$HOME/Library/Caches"
  "$HOME/.cache"
  "$HOME/go/pkg"
  "$HOME/Library/Containers/com.docker.docker"
)

for p in "${DEV_EXCLUDE_PATHS[@]}"; do
  if [ ! -e "$p" ]; then
    echo "[SKIP] $p no existe"
    continue
  fi

  if [ -f "$p/.metadata_never_index" ]; then
    echo "[SKIP] Spotlight ya excluye $p"
  elif [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] touch $p/.metadata_never_index"
  else
    if touch "$p/.metadata_never_index" 2>/dev/null; then
      echo "[SET] Spotlight excluye $p"
    else
      record_failure "Spotlight excluye $p"
    fi
  fi

  if [ "$NO_SUDO" -eq 1 ]; then
    echo "[SKIP] Time Machine excluye $p (--no-sudo)"
  elif [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] sudo tmutil addexclusion -p $p"
  elif tmutil isexcluded "$p" 2>/dev/null | grep -q "\[Excluded\]"; then
    echo "[SKIP] Time Machine ya excluye $p"
  else
    if sudo tmutil addexclusion -p "$p" >/dev/null 2>&1; then
      echo "[SET] Time Machine excluye $p"
    else
      record_failure "Time Machine excluye $p"
    fi
  fi
done

# Snapshots locales huerfanos: solo se reportan, no se borra nada. El
# reemplazo real de `tmutil disablelocal` (removido en High Sierra) es
# `tmutil thinlocalsnapshots`, y borrar snapshots sin mirar antes cuales hay
# es una operacion irreversible que este script no toma por vos.
SNAPSHOT_COUNT="$(tmutil listlocalsnapshots / 2>/dev/null | grep -c com.apple.TimeMachine || true)"
if [ "${SNAPSHOT_COUNT:-0}" -gt 0 ]; then
  echo "[INFO] $SNAPSHOT_COUNT snapshot(s) local(es) en /. Revisar con:" \
    "tmutil listlocalsnapshots / — liberar con:" \
    "sudo tmutil thinlocalsnapshots / <bytes> 4"
else
  echo "[OK] Sin snapshots locales huerfanos en /"
fi

# ── Reiniciar servicios ────────────────────────────────────────────
# --dry-run no debe tocar la sesion real: sin esto un dry-run mataba Dock y
# Finder igual, aunque ningun defaults write se hubiera ejecutado.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Reiniciar Dock, Finder, SystemUIServer, WindowManager, Clock, cfprefsd y NotificationCenter"
else
  killall Dock 2>/dev/null && echo "[OK] Dock restarted"
  killall Finder 2>/dev/null && echo "[OK] Finder restarted"
  killall SystemUIServer 2>/dev/null && echo "[OK] SystemUIServer restarted"
  # Las keys de com.apple.WindowManager (tiling, Stage Manager, widgets) no
  # toman efecto hasta que su daemon reinicia. Es un proceso distinto de
  # WindowServer: matarlo relanza el daemon, no cierra la sesion.
  killall WindowManager 2>/dev/null && echo "[OK] WindowManager restarted"
  killall "Clock" "WorldClockWidget" 2>/dev/null || true
  killall cfprefsd 2>/dev/null && echo "[OK] cfprefsd restarted"
  killall NotificationCenter 2>/dev/null && echo "[OK] NotificationCenter restarted"
fi

if [ "$DEFAULTS_FAILURES" -gt 0 ]; then
  echo "=== $DEFAULTS_FAILURES defaults operation(s) failed ===" >&2
  exit 1
fi

echo "=== Done ==="
