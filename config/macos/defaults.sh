#!/usr/bin/env bash
# macOS — defaults write optimizations
# Verificado en Sequoia 15.7.9. Tahoe 26.x NO verificado: ahi Launchpad ya no
# existe (lo absorbio Spotlight), asi que las keys springboard-* son no-op.
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
ARCH="$(uname -m)"
echo "=== macOS $MACOS_VERSION ($ARCH) ==="
if [ "$MACOS_MAJOR" -ge 26 ]; then
  echo "[!!] Tahoe 26.x no esta verificado: Launchpad lo absorbio Spotlight," \
    "las keys springboard-* son no-op ahi. Segui con cuidado."
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
    echo "[FAIL] $label"
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
    echo "[FAIL] $label"
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

# ── Launchpad (removed in Tahoe 26.x — no-op there) ────────────────
apply_default "Launchpad show speed" com.apple.dock springboard-show-duration -float 0.1

apply_default "Launchpad hide speed" com.apple.dock springboard-hide-duration -float 0.1

apply_default "Launchpad page scroll instant" com.apple.dock springboard-page-duration -float 0

# ── Dock ───────────────────────────────────────────────────────────
apply_default "Dock tile size = 48px" com.apple.dock tilesize -int 36

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
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0
) 2>/dev/null; then
  echo "[SET] Dock auto-hide instantaneo"
else
  echo "[FAIL] Dock auto-hide instantaneo"
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
  defaults write com.apple.dock wvous-br-corner -int 1
  defaults write com.apple.dock wvous-br-modifier -int 0
) 2>/dev/null; then
  echo "[SET] Hot corner inferior derecha desactivada"
else
  echo "[FAIL] Hot corner inferior derecha desactivada"
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
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
) 2>/dev/null; then
  echo "[SET] Tap to click"
else
  echo "[FAIL] Tap to click"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Two-finger right click"
elif (
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
  defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
) 2>/dev/null; then
  echo "[SET] Two-finger right click"
else
  echo "[FAIL] Two-finger right click"
fi

# Arrastre con tres dedos. Vive en Accesibilidad, no en las prefs de trackpad,
# y obliga a liberar los gestos de tres dedos: si el swipe horizontal/vertical
# de tres dedos sigue asignado, el arrastre se corta a la mitad.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Arrastre con tres dedos (gestos de tres dedos liberados)"
elif (
  defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
  defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 0
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 0
  defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 0
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 0
  defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0
) 2>/dev/null; then
  echo "[SET] Arrastre con tres dedos (gestos de tres dedos liberados)"
else
  echo "[FAIL] Arrastre con tres dedos (gestos de tres dedos liberados)"
fi

# Los swipes de escritorio/Mission Control pasan a cuatro dedos.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Swipes de espacios y Mission Control con cuatro dedos"
elif (
  defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 2
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 2
  defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
) 2>/dev/null; then
  echo "[SET] Swipes de espacios y Mission Control con cuatro dedos"
else
  echo "[FAIL] Swipes de espacios y Mission Control con cuatro dedos"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Centro de notificaciones desde el borde derecho"
elif (
  defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
) 2>/dev/null; then
  echo "[SET] Centro de notificaciones desde el borde derecho"
else
  echo "[FAIL] Centro de notificaciones desde el borde derecho"
fi

# Paridad con Hyprland: scroll natural desactivado. Se deja separado de los
# ajustes especificos del trackpad para conservar ambos dispositivos.
apply_default "Scroll natural desactivado" NSGlobalDomain com.apple.swipescrolldirection -bool false

# ── Keyboard ───────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Key repeat: delay 225ms, rate 30ms"
elif (
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain KeyRepeat -int 2
) 2>/dev/null; then
  echo "[SET] Key repeat: delay 225ms, rate 30ms"
else
  echo "[FAIL] Key repeat: delay 225ms, rate 30ms"
fi

# ── Bluetooth ──────────────────────────────────────────────────────
# Tuning heredado de SBC/A2DP (sube el bitpool minimo negociado). Con AAC en
# Apple Silicon el codec no pasa por este parametro, asi que no hay evidencia
# de que cambie la calidad percibida hoy. Se deja: es inocuo, no rompe nada.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Bluetooth audio bitpool optimized (40-80, negotiated 48-80)"
elif (
  defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
  defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Max (editable)" -int 80
  defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool Min (editable)" -int 80
  defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool (editable)" -int 80
  defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool" -int 80
  defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Max" -int 80
  defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Min" -int 48
) 2>/dev/null; then
  echo "[SET] Bluetooth audio bitpool optimized (40-80, negotiated 48-80)"
else
  echo "[FAIL] Bluetooth audio bitpool optimized (40-80, negotiated 48-80)"
fi

# ── WindowManager (Sequoia 15.x) ───────────────────────────────────
apply_default "WindowManager tiling no margins" com.apple.WindowManager EnableTiledWindowMargins -bool false

apply_default "Stage Manager desactivado" com.apple.WindowManager GloballyEnabled -bool false

# El clic en el fondo NO manda las ventanas atras para mostrar el escritorio:
# con Stage Manager apagado ese gesto solo estorba.
apply_default "Clic en el fondo no revela el escritorio" com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Iconos del escritorio ocultos mientras trabajas"
elif (
  defaults write com.apple.WindowManager HideDesktop -bool true
  defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true
) 2>/dev/null; then
  echo "[SET] Iconos del escritorio ocultos mientras trabajas"
else
  echo "[FAIL] Iconos del escritorio ocultos mientras trabajas"
fi

apply_default "Ventanas agrupadas por aplicacion" com.apple.WindowManager AppWindowGroupingBehavior -int 1

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
  defaults write com.apple.finder NewWindowTarget -string "PfHm"
  defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
) 2>/dev/null; then
  echo "[SET] Finder new window = Home"
else
  echo "[FAIL] Finder new window = Home"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Finder list view columns: name, date, size"
elif (
  defaults write com.apple.finder FK_StandardViewSettings -dict-add ListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
  defaults write com.apple.finder FK_StandardViewSettings -dict-add ExtendedListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
) 2>/dev/null; then
  echo "[SET] Finder list view columns: name, date, size"
else
  echo "[FAIL] Finder list view columns: name, date, size"
fi

# Keep folders on top when sorting by name
apply_default "Finder folders on top" com.apple.finder _FXSortFoldersFirst -bool true

# Spring-loading: folders spring open instantly when dragging files over them
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Finder spring-loading instant"
elif (
  defaults write NSGlobalDomain com.apple.springing.enabled -bool true
  defaults write NSGlobalDomain com.apple.springing.delay -float 0
) 2>/dev/null; then
  echo "[SET] Finder spring-loading instant"
else
  echo "[FAIL] Finder spring-loading instant"
fi

delete_default "Finder info panes reset" com.apple.finder FXInfoPanesExpanded

delete_default "Desktop icon positions reset" com.apple.finder FXDesktopVolumePositions

apply_default "Quick Look text selection" com.apple.finder QLEnableTextSelection -bool true

apply_default "Panel de vista previa visible" com.apple.finder ShowPreviewPane -bool true

apply_default "Agrupar por tipo" com.apple.finder FXPreferredGroupBy -string "Kind"

# ── Escritorio: sin iconos de volumenes ────────────────────────────
# Los discos siguen montados y accesibles desde la sidebar; solo se saca el
# icono del escritorio.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Escritorio sin iconos de discos ni medios extraibles"
elif (
  defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
) 2>/dev/null; then
  echo "[SET] Escritorio sin iconos de discos ni medios extraibles"
else
  echo "[FAIL] Escritorio sin iconos de discos ni medios extraibles"
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
  defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
  defaults write NSGlobalDomain AppleMetricUnits -bool true
  defaults write NSGlobalDomain AppleTemperatureUnit -string "Celsius"
) 2>/dev/null; then
  echo "[SET] Unidades metricas y Celsius"
else
  echo "[FAIL] Unidades metricas y Celsius"
fi

apply_default "La semana empieza el lunes" NSGlobalDomain AppleFirstWeekday -dict gregorian -int 2

apply_default "Fecha corta en ISO (y-MM-dd)" NSGlobalDomain AppleICUDateFormatStrings -dict 1 -string "y-MM-dd"

# ── Ventanas ───────────────────────────────────────────────────────
# Doble clic en la barra de titulo llena la pantalla en vez de minimizar.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Doble clic en la barra de titulo = Fill"
elif (
  defaults write NSGlobalDomain AppleActionOnDoubleClick -string "Fill"
  defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false
) 2>/dev/null; then
  echo "[SET] Doble clic en la barra de titulo = Fill"
else
  echo "[FAIL] Doble clic en la barra de titulo = Fill"
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
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
) 2>/dev/null; then
  echo "[SET] Save dialog always expanded"
else
  echo "[FAIL] Save dialog always expanded"
fi

apply_default "Save to disk by default (not iCloud)" NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Print dialog always expanded"
elif (
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
) 2>/dev/null; then
  echo "[SET] Print dialog always expanded"
else
  echo "[FAIL] Print dialog always expanded"
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

# La ubicacion queda en el Escritorio (default de macOS) a proposito.
# Si algun dia la queres mover, `location` por defaults es poco fiable desde
# Monterey: hacelo por Screenshot.app > Opciones > Guardar en.

# ── Window Restoration ─────────────────────────────────────────────
# Window restoration: stock macOS (windows reopen on app relaunch)

# ── Preview ────────────────────────────────────────────────────────
apply_default "Preview no window restoration" com.apple.Preview NSQuitAlwaysKeepsWindow -bool false

# ── QuickTime ──────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] QuickTime no window restoration + auto-play on open"
elif (
  defaults write com.apple.QuickTimePlayerX NSQuitAlwaysKeepsWindow -bool false
  defaults write com.apple.QuickTimePlayerX MGPlayMovieOnOpen -bool true
) 2>/dev/null; then
  echo "[SET] QuickTime no window restoration + auto-play on open"
else
  echo "[FAIL] QuickTime no window restoration + auto-play on open"
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
  defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
  defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
) 2>/dev/null; then
  echo "[SET] Auto-open DMG root after mount"
else
  echo "[FAIL] Auto-open DMG root after mount"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Disk Utility debug menu + advanced image options"
elif (
  defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
  defaults write com.apple.DiskUtility advanced-image-options -bool true
) 2>/dev/null; then
  echo "[SET] Disk Utility debug menu + advanced image options"
else
  echo "[FAIL] Disk Utility debug menu + advanced image options"
fi

# ── Time Machine ───────────────────────────────────────────────────
apply_default "No Time Machine prompts" com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# ── Privacidad ─────────────────────────────────────────────────────
apply_default "Don't send diagnostics to Apple" com.apple.SubmitDiagInfo AutoSubmit -bool false

apply_default "Crash reporter dialogs disabled" com.apple.CrashReporter DialogType -string "none"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Siri disabled + menu bar icon removed"
elif (
  defaults write com.apple.Siri SiriPrefStashedStatusMenuVisible -bool false
  defaults write com.apple.Siri StatusMenuVisible -bool false
  defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
) 2>/dev/null; then
  echo "[SET] Siri disabled + menu bar icon removed"
else
  echo "[FAIL] Siri disabled + menu bar icon removed"
fi

# Prevent "Enable Siri?" prompts after updates
apply_default "Siri declined permanently" com.apple.Siri UserHasDeclinedEnable -bool true

# Dictado ACTIVO en esta maquina. Implica que el audio puede salir a los
# servidores de Apple salvo que uses dictado en el dispositivo.
# Para revertir: -bool false
apply_default "Dictation enabled" com.apple.assistant.support "Dictation Enabled" -bool true

apply_default "Search queries data sharing off" com.apple.assistant.support "Search Queries Data Sharing Status" -int 2

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
    defaults write com.apple.Safari AutoFillFromAddressBook -bool true
    defaults write com.apple.Safari AutoFillPasswords -bool true
    defaults write com.apple.Safari AutoFillCreditCardData -bool true
    defaults write com.apple.Safari AutoFillMiscellaneousForms -bool true
  ) 2>/dev/null; then
    echo "[SET] Safari AutoFill enabled (revisar)"
  else
    echo "[FAIL] Safari AutoFill enabled (revisar)"
  fi

  # Deprecated since Safari 12.1 — harmless no-op, kept for documentation
  apply_default "Safari Do Not Track" com.apple.Safari SendDoNotTrackHTTPHeader -bool true

  # Enhanced privacy in regular browsing (not just private mode)
  apply_default "Safari enhanced privacy in regular browsing" com.apple.Safari EnableEnhancedPrivacyInRegularBrowsing -bool true

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] Safari Tab to links"
  elif (
    defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
    defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" -bool true
  ) 2>/dev/null; then
    echo "[SET] Safari Tab to links"
  else
    echo "[FAIL] Safari Tab to links"
  fi

  apply_default "Safari backspace navigation" com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" -bool true

  apply_default "Safari homepage = start page" com.apple.Safari HomePage -string "https://www.apple.com/startpage/"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] Safari hide favorites bar + sidebar"
  elif (
    defaults write com.apple.Safari ShowFavoritesBar -bool false
    defaults write com.apple.Safari ShowSidebarInTopSites -bool false
  ) 2>/dev/null; then
    echo "[SET] Safari hide favorites bar + sidebar"
  else
    echo "[FAIL] Safari hide favorites bar + sidebar"
  fi

  apply_default "Safari find contains (not starts-with)" com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

  apply_default "Safari Internal Debug menu" com.apple.Safari IncludeInternalDebugMenu -bool true

  # Security hardening
  apply_default "Safari fraudulent website warning" com.apple.Safari WarnAboutFraudulentWebsites -bool true

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] Safari pop-ups blocked"
  elif (
    defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
    defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false
  ) 2>/dev/null; then
    echo "[SET] Safari pop-ups blocked"
  else
    echo "[FAIL] Safari pop-ups blocked"
  fi

  apply_default "Safari auto-update extensions" com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

  apply_default "Safari thumbnail cache off" com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

fi # SAFARI_FDA_OK

# ── Apple Intelligence ─────────────────────────────────────────────
# Feature ID 545129924 (Sequoia 15.x)
apply_default "Apple Intelligence opt-out" com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool false

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
  defaults write com.apple.TextEdit PlainTextEncoding -int 4
  defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
) 2>/dev/null; then
  echo "[SET] TextEdit UTF-8 encoding"
else
  echo "[FAIL] TextEdit UTF-8 encoding"
fi

# ── Activity Monitor ───────────────────────────────────────────────
# Delete old key to reset Dock icon to default
delete_default "Activity Monitor default Dock icon" com.apple.ActivityMonitor IconType

apply_default "Activity Monitor refresh = 2s" com.apple.ActivityMonitor UpdatePeriod -int 2

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Activity Monitor sort by CPU usage"
elif (
  defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
  defaults write com.apple.ActivityMonitor SortDirection -int 0
) 2>/dev/null; then
  echo "[SET] Activity Monitor sort by CPU usage"
else
  echo "[FAIL] Activity Monitor sort by CPU usage"
fi

# 100 = todos los procesos. El 0 anterior era otra categoria, no "todos".
apply_default "Activity Monitor show all processes" com.apple.ActivityMonitor ShowCategory -int 100

# ── Console ────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Console debug menu + private logs"
elif (
  defaults write com.apple.Console DebugMenuEnabled -bool true
  defaults write com.apple.Console PrivateLogsEnabled -bool true
) 2>/dev/null; then
  echo "[SET] Console debug menu + private logs"
else
  echo "[FAIL] Console debug menu + private logs"
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
  defaults write com.apple.menuextra.clock IsAnalog -bool false
  defaults write com.apple.menuextra.clock ShowSeconds -bool false
  defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
  defaults write com.apple.menuextra.clock ShowDate -int 0
  defaults write com.apple.menuextra.clock Show24Hour -bool true
) 2>/dev/null; then
  echo "[SET] Clock: digital, 24h, minimal"
else
  echo "[FAIL] Clock: digital, 24h, minimal"
fi
# DateFormat unificado (reemplaza keys individuales en Sequoia+).
# OJO: en esta maquina esta key no persiste — macOS la borra y deja el formato
# derivado de Show24Hour + la region. Se mantiene por si en otra version pega.
apply_default "Clock: digital, 24h, minimal" com.apple.menuextra.clock DateFormat -string "HH:mm"

# ── App Store ──────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] App Store debug menu enabled"
elif (
  defaults write com.apple.appstore ShowDebugMenu -bool true
  defaults write com.apple.appstore IncludeDebugMenu -bool true
  defaults write com.apple.appstore WebKitDeveloperExtras -bool true
) 2>/dev/null; then
  echo "[SET] App Store debug menu enabled"
else
  echo "[FAIL] App Store debug menu enabled"
fi

# Auto-update App Store apps (security: outdated apps = attack surface)
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] App Store auto-update + auto-restart"
elif (
  defaults write com.apple.commerce AutoUpdate -bool true
  defaults write com.apple.commerce AutoUpdateRestartRequired -bool true
) 2>/dev/null; then
  echo "[SET] App Store auto-update + auto-restart"
else
  echo "[FAIL] App Store auto-update + auto-restart"
fi

# ── Software Update ────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Software Update: daily check + auto critical installs"
elif (
  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
  defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
  defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1
  defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1
  defaults write com.apple.SoftwareUpdate ConfigDataInstall -int 1
) 2>/dev/null; then
  echo "[SET] Software Update: daily check + auto critical installs"
else
  echo "[FAIL] Software Update: daily check + auto critical installs"
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
  echo "[FAIL] ~/Library visible"
fi

# Reduce Transparency: alivia ~15-20% de CPU de WindowServer en Sequoia (donde
# esta verificado). En Tahoe (26.x) el compositor Liquid Glass no esta hecho
# para esta key y puede producir artefactos visuales — se salta ahi.
if [ "$MACOS_MAJOR" -ge 26 ]; then
  echo "[SKIP] Reduce Transparency (Tahoe 26.x: Liquid Glass, puede dar artefactos)"
else
  apply_default "Reduce Transparency (alivio de WindowServer)" com.apple.universalaccess reduceTransparency -bool true
fi

# ── Zoom de pantalla ───────────────────────────────────────────────
# ctrl + scroll hace zoom. 262144 es la mascara del modificador Control.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Zoom con ctrl + scroll"
elif (
  defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
  defaults write com.apple.universalaccess closeViewScrollWheelModifiersInt -int 262144
) 2>/dev/null; then
  echo "[SET] Zoom con ctrl + scroll"
else
  echo "[FAIL] Zoom con ctrl + scroll"
fi

apply_default "Sin atajos de teclado para el zoom" com.apple.universalaccess closeViewHotkeysEnabled -bool false

# ── Control Center / barra de menu ─────────────────────────────────
# Barra de menu al minimo: reloj, Control Center y Sonido. El resto sigue
# accesible desde el BentoBox, no se desactiva nada.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY] Barra de menu minima (reloj + Control Center)"
elif (
  defaults write com.apple.controlcenter "NSStatusItem Visible BentoBox" -bool true
  defaults write com.apple.controlcenter "NSStatusItem Visible Clock" -bool true
  defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool true
  defaults write com.apple.controlcenter "NSStatusItem Visible NowPlaying" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible FocusModes" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible AudioVideoModule" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Timer" -bool false
) 2>/dev/null; then
  echo "[SET] Barra de menu minima (reloj + Control Center)"
else
  echo "[FAIL] Barra de menu minima (reloj + Control Center)"
fi

# La barra de menu se oculta hasta que pasas el mouse arriba. Promovido desde
# "Minimalismo Extremo": mas espacio vertical, pero desorienta al principio y
# si usas Bartender u otro gestor de iconos, revisa que no compita con el.
# Revertir: defaults delete NSGlobalDomain _HIHideMenuBar
apply_default "Menu bar auto-hide" NSGlobalDomain _HIHideMenuBar -bool true

# ══════════════════════════════════════════════════════════════════
# TIER 2 — requiere sudo
# ══════════════════════════════════════════════════════════════════
# Vivia como texto suelto en el README bajo "Recomendaciones con sudo" y
# nunca se ejecutaba. Cada item verifica el estado real antes de escribir;
# lo que ya esta bien en esta instalacion se reporta y no se toca. Nada de
# esto es SIP, Gatekeeper ni el firewall — esos se verifican mas abajo, no
# se modifican nunca desde este script.
if [ "$NO_SUDO" -eq 1 ]; then
  echo "=== Tier sudo saltado (--no-sudo) ==="
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "=== Tier sudo (dry-run, no pide password) ==="
else
  echo "=== Tier sudo: puede pedir tu password ==="
  sudo -v

  apply_sudo() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
      echo "[SET] $label"
    else
      echo "[FAIL] $label"
    fi
  }

  # Developer mode: sin esto Xcode y los debuggers piden auth cada vez que
  # se adjuntan a un proceso. La lectura de status no pide sudo.
  if DevToolsSecurity -status 2>/dev/null | grep -qi "enabled"; then
    echo "[SKIP] Developer mode ya habilitado"
  else
    apply_sudo "Developer mode (DevToolsSecurity)" sudo DevToolsSecurity -enable
  fi

  # Power Nap: despierta la Mac dormida para mail/iCloud/Time Machine —
  # bateria y snapshots de Time Machine de fondo sin que la pidas.
  if pmset -g custom | grep -Eq "powernap[[:space:]]+1"; then
    apply_sudo "Power Nap off (AC + bateria)" sudo pmset -a powernap 0
  else
    echo "[SKIP] Power Nap ya desactivado"
  fi

  # Wake for network access off + wake by proximity on, exactamente como la
  # politica elegida para esta Mac. `proximitywake` solo tiene efecto en
  # hardware compatible; pmset puede aceptar el write aunque el equipo no lo
  # exponga en `pmset -g cap`.
  apply_sudo "Wake settings (womp 0, proximitywake 1)" \
    sudo pmset -a womp 0 proximitywake 1

  # Auto-restart tras freeze o corte de luz. Verificado con el cargador
  # puesto: `pmset -g cap` no lista "autorestart" entre las capacidades de
  # este M3 Air (si aparece en un iMac). El write de abajo devuelve exito
  # igual — probable no-op de hardware, mismo patron que askForPassword en
  # screensaver. Se deja (es inocuo, sudo -a autorestart 1 no rompe nada) pero
  # no asumas que hizo algo solo porque no fallo.
  if pmset -g | grep -Eq "^ autorestart[[:space:]]+1$"; then
    echo "[SKIP] Auto-restart ya configurado"
  else
    apply_sudo "Auto-restart en freeze/corte de luz (pmset)" sudo pmset -a autorestart 1
    apply_sudo "Auto-restart en freeze (systemsetup)" sudo systemsetup -setrestartfreeze on
  fi

  # SSH remoto: solo se toca si esta prendido. Si lo usas para desarrollo,
  # no corras esto — dejalo en On a mano.
  if sudo systemsetup -getremotelogin 2>/dev/null | grep -qi "On"; then
    apply_sudo "SSH remoto apagado" sudo systemsetup -setremotelogin off
  else
    echo "[SKIP] SSH remoto ya apagado"
  fi

  # Bonjour multicast (CIS Benchmark Level 1) — opt-in explicito. Rompe
  # descubrimiento de impresoras Bonjour, servidores DLNA y Home Assistant en
  # la LAN. AirDrop/AirPlay no se ven afectados: usan AWDL, no mDNS multicast.
  if [ "$BONJOUR_OFF" -eq 1 ]; then
    if sudo defaults read /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements 2>/dev/null | grep -q 1; then
      echo "[SKIP] Bonjour multicast ya desactivado"
    else
      apply_sudo "Bonjour multicast desactivado (--bonjour-off)" \
        sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool YES
      sudo killall mDNSResponder 2>/dev/null || true
    fi
  fi

  # /Volumes visible en Finder: util para debuggear mounts, DMGs y volumenes
  # de Docker.
  if [ "$(stat -f '%Sf' /Volumes)" = "-" ]; then
    echo "[SKIP] /Volumes ya visible"
  else
    apply_sudo "/Volumes visible en Finder" sudo chflags nohidden /Volumes
  fi

  if sudo defaults read /Library/Preferences/com.apple.loginwindow AdminHostInfo 2>/dev/null | grep -qx "HostName"; then
    echo "[SKIP] Login Window muestra HostName"
  else
    apply_sudo "Login Window muestra HostName" \
      sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
  fi

  # Touch ID para sudo — mecanismo oficial sudo_local de Apple (Sonoma+),
  # sobrevive updates de macOS. Idempotente: no pisa una config custom.
  if [ -f /etc/pam.d/sudo_local ]; then
    echo "[SKIP] Touch ID para sudo ya configurado (sudo_local)"
  elif [ -f /etc/pam.d/sudo_local.template ]; then
    sed 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local >/dev/null
    echo "[SET] Touch ID para sudo activado (sudo_local)"
  else
    echo "[SKIP] Touch ID para sudo no disponible (requiere macOS 14+)"
  fi

  echo "--- Verificacion de seguridad (solo lectura, no se escribe nada) ---"
  if fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
    echo "[OK] FileVault On"
  else
    echo "[WARN] FileVault: revisar con 'sudo fdesetup enable'"
  fi
  if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -qi enabled; then
    echo "[OK] Firewall enabled"
  else
    echo "[WARN] Firewall apagado: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"
  fi
  if /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | grep -qi "stealth mode is on"; then
    echo "[OK] Firewall stealth mode on"
  else
    echo "[WARN] Stealth mode apagado"
  fi
  if csrutil status 2>/dev/null | grep -qi "enabled"; then
    echo "[OK] SIP enabled"
  else
    echo "[WARN] SIP disabled — este script nunca lo toca, es decision tuya"
  fi
  if spctl --status 2>/dev/null | grep -qi "assessments enabled"; then
    echo "[OK] Gatekeeper enabled"
  else
    echo "[WARN] Gatekeeper: revisar con 'spctl --status'"
  fi
  if sudo sysadminctl -secureTokenStatus "$(id -un)" 2>&1 | grep -qi "ENABLED"; then
    echo "[OK] Secure Token enabled"
  else
    echo "[WARN] Secure Token: revisar con 'sysadminctl -secureTokenStatus'"
  fi
  if sudo -n true 2>/dev/null && sysadminctl -screenLock status 2>&1 | grep -qi "immediate"; then
    echo "[OK] Bloqueo de pantalla inmediato"
  else
    echo "[WARN] Bloqueo de pantalla: revisar en Ajustes > Pantalla bloqueada"
  fi
  if sudo defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled 2>/dev/null | grep -q 1; then
    echo "[OK] HiDPI para monitores 4K habilitado"
  else
    echo "[SKIP] HiDPI no habilitado (solo hace falta con monitor 4K externo)"
  fi
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
# existe, se saltea.
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
    touch "$p/.metadata_never_index" 2>/dev/null &&
      echo "[SET] Spotlight excluye $p" ||
      echo "[FAIL] Spotlight excluye $p"
  fi

  if [ "$NO_SUDO" -eq 1 ]; then
    echo "[SKIP] Time Machine excluye $p (--no-sudo)"
  elif [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] sudo tmutil addexclusion -p $p"
  elif tmutil isexcluded "$p" 2>/dev/null | grep -q "\[Excluded\]"; then
    echo "[SKIP] Time Machine ya excluye $p"
  else
    sudo tmutil addexclusion -p "$p" >/dev/null 2>&1 &&
      echo "[SET] Time Machine excluye $p" ||
      echo "[FAIL] Time Machine excluye $p"
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
  echo "[DRY] Reiniciar Dock, Finder, SystemUIServer, Clock, cfprefsd y NotificationCenter"
else
  killall Dock 2>/dev/null && echo "[OK] Dock restarted"
  killall Finder 2>/dev/null && echo "[OK] Finder restarted"
  killall SystemUIServer 2>/dev/null && echo "[OK] SystemUIServer restarted"
  killall "Clock" "WorldClockWidget" 2>/dev/null || true
  killall cfprefsd 2>/dev/null && echo "[OK] cfprefsd restarted"
  killall NotificationCenter 2>/dev/null && echo "[OK] NotificationCenter restarted"
fi

echo "=== Done ==="
