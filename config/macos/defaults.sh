#!/usr/bin/env bash
# macOS — defaults write optimizations
# Verificado en Sequoia 15.7.9. Tahoe 26.x NO verificado: ahi Launchpad ya no
# existe (lo absorbio Spotlight), asi que las keys springboard-* son no-op.
# 265 defaults write, 3 defaults delete, 54 secciones
# Apply: chmod +x defaults.sh && ./defaults.sh
#
# Reconciliado contra el estado real de la maquina: los valores de aca son los
# que la Mac tiene hoy, no los que el script proponia originalmente. Donde el
# valor vivo baja la privacidad respecto del original hay un comentario
# "Para revertir:" con el valor endurecido.
set -euo pipefail

echo "=== Aplicando defaults de macOS ==="

# ── Animaciones de ventanas ────────────────────────────────────────
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
echo "[OK] Window resize instant"

# Window animations: stock macOS (animations are part of the experience)
# NSAutomaticWindowAnimationsEnabled kept at default (true)

defaults write NSGlobalDomain NSDocumentRevisionsWindowTransformAnimation -bool false
echo "[OK] Document revisions animation disabled"

defaults write NSGlobalDomain NSToolbarFullScreenAnimationDuration -float 0
echo "[OK] Full-screen toolbar animation instant"

# Column view animation: stock macOS (smooth navigation feel)

# Scroll: stock macOS (smooth scrolling + elastic feel are iconic)

# ── Quick Look ─────────────────────────────────────────────────────
defaults write -g QLPanelAnimationDuration -float 0
echo "[OK] Quick Look animation = 0"

# Cursor magnification: stock macOS (no perf/security/stability impact)

# ── Mission Control ────────────────────────────────────────────────
defaults write com.apple.dock expose-animation-duration -float 0.1
echo "[OK] Mission Control speed"

# Escritorios en orden fijo: sin esto Mission Control los reordena por uso
# reciente y los atajos ctrl+numero dejan de apuntar siempre al mismo.
defaults write com.apple.dock mru-spaces -bool false
echo "[OK] Escritorios en orden fijo"

defaults write com.apple.dock workspaces-auto-swoosh -bool false
echo "[OK] Sin cambio automatico de escritorio al activar una app"

# ── Launchpad (removed in Tahoe 26.x — no-op there) ────────────────
defaults write com.apple.dock springboard-show-duration -float 0.1
echo "[OK] Launchpad show speed"

defaults write com.apple.dock springboard-hide-duration -float 0.1
echo "[OK] Launchpad hide speed"

defaults write com.apple.dock springboard-page-duration -float 0
echo "[OK] Launchpad page scroll instant"

# ── Dock ───────────────────────────────────────────────────────────
defaults write com.apple.dock tilesize -int 48
echo "[OK] Dock tile size = 48px"

defaults write com.apple.dock mineffect -string "scale"
echo "[OK] Dock minimize effect = scale"

defaults write com.apple.dock minimize-to-application -bool false
echo "[OK] Minimize to separate Dock slot (not into app icon)"

defaults write com.apple.dock show-recents -bool false
echo "[OK] No recent apps in Dock"

defaults write com.apple.dock scroll-to-open -bool true
echo "[OK] Dock scroll to Exposé"

# ── Dock: auto-hide instantaneo ────────────────────────────────────
# El README ya prometia "auto-hide instantaneo (sin delay)" pero el script
# nunca lo escribia. Los tres van juntos: sin delay y sin animacion de salida.
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
echo "[OK] Dock auto-hide instantaneo"

defaults write com.apple.dock launchanim -bool false
echo "[OK] Sin animacion de rebote al abrir apps"

defaults write com.apple.dock no-bouncing -bool true
echo "[OK] Iconos del Dock no rebotan por notificacion"

defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
echo "[OK] Spring-load all Dock items"

defaults write com.apple.dock showhidden -bool true
echo "[OK] Dock show hidden app icons"

defaults write com.apple.dock mouse-over-hilite-stack -bool true
echo "[OK] Dock highlight stacks on hover"

# Esquina inferior derecha sin accion (1 = ninguna), sin modificador.
defaults write com.apple.dock wvous-br-corner -int 1
defaults write com.apple.dock wvous-br-modifier -int 0
echo "[OK] Hot corner inferior derecha desactivada"

# ── Trackpad ───────────────────────────────────────────────────────
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 1.5
echo "[OK] Trackpad tracking speed"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
echo "[OK] Tap to click"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
echo "[OK] Two-finger right click"

# Arrastre con tres dedos. Vive en Accesibilidad, no en las prefs de trackpad,
# y obliga a liberar los gestos de tres dedos: si el swipe horizontal/vertical
# de tres dedos sigue asignado, el arrastre se corta a la mitad.
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0
echo "[OK] Arrastre con tres dedos (gestos de tres dedos liberados)"

# Los swipes de escritorio/Mission Control pasan a cuatro dedos.
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
echo "[OK] Swipes de espacios y Mission Control con cuatro dedos"

defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
echo "[OK] Centro de notificaciones desde el borde derecho"

# ── Keyboard ───────────────────────────────────────────────────────
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain KeyRepeat -int 2
echo "[OK] Key repeat: delay 225ms, rate 30ms"

# ── Bluetooth ──────────────────────────────────────────────────────
# Default min ~40; boost to 48 for better audio quality
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Max (editable)" -int 80
defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool Min (editable)" -int 80
defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool (editable)" -int 80
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool" -int 80
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Max" -int 80
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Min" -int 48
echo "[OK] Bluetooth audio bitpool optimized (40-80, negotiated 48-80)"

# ── WindowManager (Sequoia 15.x) ───────────────────────────────────
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
echo "[OK] WindowManager tiling no margins"

defaults write com.apple.WindowManager GloballyEnabled -bool false
echo "[OK] Stage Manager desactivado"

# El clic en el fondo NO manda las ventanas atras para mostrar el escritorio:
# con Stage Manager apagado ese gesto solo estorba.
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
echo "[OK] Clic en el fondo no revela el escritorio"

defaults write com.apple.WindowManager HideDesktop -bool true
defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true
echo "[OK] Iconos del escritorio ocultos mientras trabajas"

defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 1
echo "[OK] Ventanas agrupadas por aplicacion"

# ── Finder ─────────────────────────────────────────────────────────
defaults write com.apple.finder DisableAllAnimations -bool true
echo "[OK] Finder animations disabled"

defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
echo "[OK] Finder default list view"

defaults write com.apple.finder AppleShowAllFiles -bool true
echo "[OK] Finder show hidden files"

defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
echo "[OK] No extension change warning"

defaults write com.apple.finder FinderSpawnTab -bool true
echo "[OK] Finder open in tabs"

defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
echo "[OK] Finder search current folder"

defaults write com.apple.finder ShowStatusBar -bool true
echo "[OK] Finder status bar"

defaults write com.apple.finder ShowPathbar -bool true
echo "[OK] Finder path bar"

# Titulo de la ventana: stock macOS (solo el nombre de la carpeta).
# _FXShowPosixPathInTitle mostraria la ruta completa "/Users/sebastian/Developer"
# en vez de "Developer". La barra de ruta de abajo (ShowPathbar) ya da esa
# informacion sin ocupar el titulo.

defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true
echo "[OK] Sidebar devices section"

defaults write com.apple.finder SidebarPlacesSectionDisclosedState -bool true
echo "[OK] Sidebar places section"

defaults write com.apple.finder SidebarShowingiCloudDesktop -bool true
echo "[OK] iCloud Desktop visible en la sidebar"

defaults write com.apple.finder SidebariCloudDriveSectionDisclosedState -bool false
echo "[OK] Seccion iCloud Drive colapsada"

# PfHm = Home folder (not Recents)
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
echo "[OK] Finder new window = Home"

defaults write com.apple.finder FK_StandardViewSettings -dict-add ListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
defaults write com.apple.finder FK_StandardViewSettings -dict-add ExtendedListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
echo "[OK] Finder list view columns: name, date, size"

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true
echo "[OK] Finder folders on top"

# Spring-loading: folders spring open instantly when dragging files over them
defaults write NSGlobalDomain com.apple.springing.enabled -bool true
defaults write NSGlobalDomain com.apple.springing.delay -float 0
echo "[OK] Finder spring-loading instant"

defaults delete com.apple.finder FXInfoPanesExpanded 2>/dev/null || true
echo "[OK] Finder info panes reset"

defaults delete com.apple.finder FXDesktopVolumePositions 2>/dev/null || true
echo "[OK] Desktop icon positions reset"

defaults write com.apple.finder QLEnableTextSelection -bool true
echo "[OK] Quick Look text selection"

defaults write com.apple.finder ShowPreviewPane -bool true
echo "[OK] Panel de vista previa visible"

defaults write com.apple.finder FXPreferredGroupBy -string "Kind"
echo "[OK] Agrupar por tipo"

# ── Escritorio: sin iconos de volumenes ────────────────────────────
# Los discos siguen montados y accesibles desde la sidebar; solo se saca el
# icono del escritorio.
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
echo "[OK] Escritorio sin iconos de discos ni medios extraibles"

# ── Papelera ───────────────────────────────────────────────────────
defaults write com.apple.finder WarnOnEmptyTrash -bool false
echo "[OK] Sin confirmacion al vaciar la papelera"

defaults write com.apple.finder FXRemoveOldTrashItems -bool true
echo "[OK] Papelera se vacia sola pasados 30 dias"

# ── Network Browser ────────────────────────────────────────────────
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true
echo "[OK] Network browser show all interfaces"

# ── .DS_Store ──────────────────────────────────────────────────────
# Requires logout to take effect
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
echo "[OK] No .DS_Store on network volumes"

defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
echo "[OK] No .DS_Store on USB drives"

# ── Archive Utility ────────────────────────────────────────────────
defaults write com.apple.archiveutility "com.apple.archiveutility.disable-resourceforks" -bool true
echo "[OK] Archive Utility no __MACOSX folders"

defaults write com.apple.archiveutility "dearchive-into-subfolder" -bool false
echo "[OK] Archive Utility extract in current folder"

defaults write com.apple.archiveutility "move-archive-to-trash" -bool true
echo "[OK] Archive Utility auto-trash after extract"

# ── Apariencia ─────────────────────────────────────────────────────
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
echo "[OK] Modo oscuro"

defaults write NSGlobalDomain AppleHighlightColor -string "0.847059 0.847059 0.862745 Graphite"
echo "[OK] Color de seleccion grafito"

defaults write NSGlobalDomain AppleReduceDesktopTinting -bool false
echo "[OK] Tinte del fondo en las ventanas activo"

defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1
echo "[OK] Iconos chicos en sidebars"

# ── Region: Chile (metrico, ISO, semana en lunes) ──────────────────
defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
defaults write NSGlobalDomain AppleMetricUnits -bool true
defaults write NSGlobalDomain AppleTemperatureUnit -string "Celsius"
echo "[OK] Unidades metricas y Celsius"

defaults write NSGlobalDomain AppleFirstWeekday -dict gregorian -int 2
echo "[OK] La semana empieza el lunes"

defaults write NSGlobalDomain AppleICUDateFormatStrings -dict 1 -string "y-MM-dd"
echo "[OK] Fecha corta en ISO (y-MM-dd)"

# ── Ventanas ───────────────────────────────────────────────────────
# Doble clic en la barra de titulo llena la pantalla en vez de minimizar.
defaults write NSGlobalDomain AppleActionOnDoubleClick -string "Fill"
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false
echo "[OK] Doble clic en la barra de titulo = Fill"

# Mover una ventana desde cualquier punto con ctrl+cmd, sin apuntarle a la barra.
defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool true
echo "[OK] Arrastrar ventanas con ctrl+cmd desde cualquier lugar"

# Clic en la barra de scroll salta a esa posicion en vez de avanzar una pagina.
defaults write NSGlobalDomain AppleScrollerPagingBehavior -bool true
echo "[OK] Clic en el scroll salta a la posicion"

# Sin swipe de dos dedos para atras/adelante: se dispara solo al hacer scroll
# horizontal dentro de una pagina.
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false
echo "[OK] Sin navegacion atras/adelante por swipe"

# Las apps en segundo plano no se suspenden.
defaults write NSGlobalDomain NSAppSleepDisabled -bool true
echo "[OK] App Nap desactivado"

# ── Global ─────────────────────────────────────────────────────────
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
echo "[OK] Show all file extensions"

defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"
echo "[OK] Scroll bars visible on scroll"

defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true
echo "[OK] Show invisible characters"

defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
echo "[OK] Auto-capitalization off"

defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
echo "[OK] Smart dashes off"

defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
echo "[OK] Auto-period off"

defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
echo "[OK] Smart quotes off"

defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
echo "[OK] Spelling correction off"

defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false
echo "[OK] Web spelling correction off"

# Tab navega TODOS los controles, no solo campos de texto. Es lo que hace
# utilizables los dialogos sin mouse.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
echo "[OK] Navegacion completa por teclado"

defaults write NSGlobalDomain NSAutomaticTextCompletionEnabled -bool false
echo "[OK] Auto text completion off"

# Apple Intelligence inline predictions (Sequoia+)
defaults write NSGlobalDomain NSAutomaticInlinePredictionEnabled -bool false
echo "[OK] Inline predictions off"

defaults write NSGlobalDomain NSToolbarTitleViewRolloverDelay -float 0
echo "[OK] Toolbar title rollover instant"

# ── Diálogos Save/Print ────────────────────────────────────────────
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
echo "[OK] Save dialog always expanded"

defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
echo "[OK] Save to disk by default (not iCloud)"

defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
echo "[OK] Print dialog always expanded"

defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
echo "[OK] Print dialog auto-close after job"

# ── Screensaver ────────────────────────────────────────────────────
# idleTime vive en el dominio por-host: el dominio plano se escribe pero macOS
# no lo lee. Verificado en 15.7.9 — el valor efectivo esta en
# ~/Library/Preferences/ByHost/com.apple.screensaver.<UUID>.plist
defaults -currentHost write com.apple.screensaver idleTime -int 300
echo "[OK] Salvapantallas a los 5 min"

# NO-OP desde macOS 10.13.4: estas dos keys se escriben pero el sistema dejo de
# leerlas. El bloqueo inmediato se configura en Ajustes > Pantalla bloqueada, y
# se verifica con `sysadminctl -screenLock status` (debe decir "immediate").
# Se dejan porque documentan la intencion, no porque hagan algo.
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
echo "[--] askForPassword: no-op, configurar en Ajustes (ver comentario)"

# ── Screenshots ────────────────────────────────────────────────────
defaults write com.apple.screencapture disable-shadow -bool true
echo "[OK] Screenshot shadows off"

defaults write com.apple.screencapture type -string "png"
echo "[OK] Capturas en PNG"

# Nombre corto: "Screenshot.png" en vez de "Screenshot 2026-08-15 at 04.01.36".
defaults write com.apple.screencapture include-date -bool false
echo "[OK] Capturas sin fecha en el nombre"

# La ubicacion queda en el Escritorio (default de macOS) a proposito.
# Si algun dia la queres mover, `location` por defaults es poco fiable desde
# Monterey: hacelo por Screenshot.app > Opciones > Guardar en.

# ── Window Restoration ─────────────────────────────────────────────
# Window restoration: stock macOS (windows reopen on app relaunch)

# ── Preview ────────────────────────────────────────────────────────
defaults write com.apple.Preview NSQuitAlwaysKeepsWindow -bool false
echo "[OK] Preview no window restoration"

# ── QuickTime ──────────────────────────────────────────────────────
defaults write com.apple.QuickTimePlayerX NSQuitAlwaysKeepsWindow -bool false
defaults write com.apple.QuickTimePlayerX MGPlayMovieOnOpen -bool true
echo "[OK] QuickTime no window restoration + auto-play on open"

# ── Mail ───────────────────────────────────────────────────────────
defaults write com.apple.mail DisableReplyAnimations -bool true
echo "[OK] Mail reply animations off"

defaults write com.apple.mail DisableSendAnimations -bool true
echo "[OK] Mail send animations off"

# Copy email address without person's name (user@domain.com, not "John Doe <user@domain.com>")
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false
echo "[OK] Mail copy email without name"

defaults write com.apple.mail DisableInlineAttachmentViewing -bool true
echo "[OK] Mail inline attachments off"

defaults write com.apple.mail PreferPlainText -bool true
echo "[OK] Mail plain text compose"

# Mail spell check: stock macOS (spell checking is useful, no security impact)

# ── Messages ───────────────────────────────────────────────────────
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticEmojiSubstitutionEnablediMessage" -bool false
echo "[OK] Messages: auto-emoji off"

defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false
echo "[OK] Messages: smart quotes off"

# ── Disk Utility ───────────────────────────────────────────────────
# Skipping DMG verification disable for security
echo "[SKIP] DMG verification kept at system default (security)"

defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
echo "[OK] Auto-open DMG root after mount"

defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
defaults write com.apple.DiskUtility advanced-image-options -bool true
echo "[OK] Disk Utility debug menu + advanced image options"

# ── Time Machine ───────────────────────────────────────────────────
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
echo "[OK] No Time Machine prompts"

# ── Privacidad ─────────────────────────────────────────────────────
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false
echo "[OK] Don't send diagnostics to Apple"

defaults write com.apple.CrashReporter DialogType -string "none"
echo "[OK] Crash reporter dialogs disabled"

defaults write com.apple.Siri SiriPrefStashedStatusMenuVisible -bool false
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
echo "[OK] Siri disabled + menu bar icon removed"

# Prevent "Enable Siri?" prompts after updates
defaults write com.apple.Siri UserHasDeclinedEnable -bool true
echo "[OK] Siri declined permanently"

# Dictado ACTIVO en esta maquina. Implica que el audio puede salir a los
# servidores de Apple salvo que uses dictado en el dispositivo.
# Para revertir: -bool false
defaults write com.apple.assistant.support "Dictation Enabled" -bool true
echo "[OK] Dictation enabled"

defaults write com.apple.assistant.support "Search Queries Data Sharing Status" -int 2
echo "[OK] Search queries data sharing off"

defaults write com.apple.assistant.support "Siri Data Sharing Opt-In Status" -int 2
echo "[OK] Siri data sharing opt-out"

defaults write com.apple.suggestions SiriSuggestionsEnabled -bool false
echo "[OK] Siri suggestions engine off"

defaults write com.apple.assistant.support "Assistant Enabled" -bool false
echo "[OK] Siri Assistant core disabled"

defaults write com.apple.appleseed.FeedbackAssistant Autogather -bool false
echo "[OK] Feedback Assistant no auto-gather"

# IDFA (Identifier for Advertisers) — cross-app tracking.
# ACTIVO en esta maquina (=1). El script lo desactivaba y algo lo volvio a
# encender: o lo cambiaste en Ajustes, o se reseteo en una actualizacion.
# Las otras dos keys de AdLib abajo SI siguen restringidas.
# Para revertir: -int 0
defaults write com.apple.AdLib allowIdentifierForAdvertising -int 1
echo "[OK] Advertising identifier enabled (revisar)"

defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false
echo "[OK] Apple personalized advertising off"

defaults write com.apple.AdLib forceLimitAdTracking -bool true
echo "[OK] Ad tracking force-limited"

# ── Telemetría ─────────────────────────────────────────────────────
defaults write com.apple.SubmitDiagInfo ThirdPartyDataSubmit -bool false
echo "[OK] Third-party diagnostic data off"

defaults write com.apple.analyticsd AnalyticsEnabled -bool false
echo "[OK] Analytics disabled"

defaults write com.apple.iCloud EnableAnalytics -bool false
echo "[OK] iCloud analytics off"

defaults write com.apple.UsageTracking CoreDonationsEnabled -bool false
echo "[OK] Core donations tracking off"

defaults write com.apple.UsageTracking UDCAutomationEnabled -bool false
echo "[OK] UDC automation off"

defaults write com.apple.appstore SendDiagnosticData -bool false
echo "[OK] App Store diagnostic data off"

# ── Apps: anonymous usage ──────────────────────────────────────────
defaults write com.apple.Maps UserSelectedAnonymousUsageOptIn -bool false
echo "[OK] Maps anonymous usage off"

defaults write com.apple.Health UserSelectedAnonymousUsageOptIn -bool false
echo "[OK] Health anonymous usage off"

defaults write com.apple.imessage UserSelectedAnonymousUsageOptIn -bool false
echo "[OK] iMessage anonymous usage off"

defaults write com.apple.Photos UserSelectedAnonymousUsageOptIn -bool false
echo "[OK] Photos anonymous usage off"

# Handoff logging only — Handoff itself stays enabled
defaults write -g NSUserActivityLoggingEnabled -bool false
echo "[OK] Handoff activity logging off"

# ── Image Capture ──────────────────────────────────────────────────
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
echo "[OK] Image Capture no auto-launch"

# ── Safari / WebKit ────────────────────────────────────────────────
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true
echo "[OK] WebKit developer extras"

# Desactivado en esta maquina. Safari 17+ unifico esto en "Funciones para
# desarrolladores web"; los menus Debug e Internal Debug de mas abajo si estan.
defaults write com.apple.Safari IncludeDevelopMenu -bool false
echo "[OK] Safari Develop menu off"

defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
echo "[OK] Safari WebKit dev extras"

defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
echo "[OK] Safari full URL in address bar"

defaults write com.apple.Safari UniversalSearchEnabled -bool false
echo "[OK] Safari universal search off"

defaults write com.apple.Safari SuppressSearchSuggestions -bool true
echo "[OK] Safari search suggestions off"

defaults write com.apple.Safari SearchSuggestionsEnabled -bool false
echo "[OK] Safari search suggestions disabled"

defaults write com.apple.Safari PreloadTopHit -bool false
echo "[OK] Safari preload top hit off"

defaults write com.apple.Safari IncludeDebugMenu -bool true
echo "[OK] Safari Debug menu"

defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
echo "[OK] Safari WebKit2 dev extras"

defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false
echo "[OK] Safari spelling correction off"

defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
echo "[OK] Safari never auto-open downloads"

# AutoFill ACTIVO en esta maquina, incluidos contrasenas y tarjetas. Comodo,
# pero significa que Safari rellena credenciales sin pedir confirmacion.
# Para revertir: los cuatro a -bool false
defaults write com.apple.Safari AutoFillFromAddressBook -bool true
defaults write com.apple.Safari AutoFillPasswords -bool true
defaults write com.apple.Safari AutoFillCreditCardData -bool true
defaults write com.apple.Safari AutoFillMiscellaneousForms -bool true
echo "[OK] Safari AutoFill enabled (revisar)"

# Deprecated since Safari 12.1 — harmless no-op, kept for documentation
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true
echo "[OK] Safari Do Not Track"

# Enhanced privacy in regular browsing (not just private mode)
defaults write com.apple.Safari EnableEnhancedPrivacyInRegularBrowsing -bool true
echo "[OK] Safari enhanced privacy in regular browsing"

defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" -bool true
echo "[OK] Safari Tab to links"

defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" -bool true
echo "[OK] Safari backspace navigation"

defaults write com.apple.Safari HomePage -string "https://www.apple.com/startpage/"
echo "[OK] Safari homepage = start page"

defaults write com.apple.Safari ShowFavoritesBar -bool false
defaults write com.apple.Safari ShowSidebarInTopSites -bool false
echo "[OK] Safari hide favorites bar + sidebar"

defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false
echo "[OK] Safari find contains (not starts-with)"

defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
echo "[OK] Safari Internal Debug menu"

# Security hardening
defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true
echo "[OK] Safari fraudulent website warning"

defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false
echo "[OK] Safari pop-ups blocked"

defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true
echo "[OK] Safari auto-update extensions"

defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2
echo "[OK] Safari thumbnail cache off"

# ── Apple Intelligence ─────────────────────────────────────────────
# Feature ID 545129924 (Sequoia 15.x)
defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool false
echo "[OK] Apple Intelligence opt-out"

# ── Xcode & Simulator ──────────────────────────────────────────────
defaults write com.apple.dt.Xcode ShowDVTDebugMenu -bool YES
echo "[OK] Xcode DVT debug menu"

defaults write com.apple.dt.Xcode XcodeCloudUpsellPromptEnabled -bool false
echo "[OK] Xcode Cloud upsell suppressed"

defaults write com.apple.dt.Xcode IDEIndexerActivityShowNumericProgress -bool true
echo "[OK] Xcode indexing numeric progress"

defaults write com.apple.dt.Xcode IDEFileExtensionDisplayMode -int 1
echo "[OK] Xcode file extensions visible"

defaults write com.apple.dt.Xcode DVTEnableDockIconVersionNumber -bool YES
echo "[OK] Xcode build version in Dock icon"

defaults write com.apple.dt.Xcode IDEDisableStateRestoration -bool YES
echo "[OK] Xcode no state restoration on launch"

defaults write com.apple.dt.Xcode ApplePersistenceIgnoreState -bool YES
echo "[OK] Xcode no auto-reopen last project"

defaults write com.apple.iphonesimulator ShowSingleTouches -int 1
echo "[OK] Simulator show touches"

# Parallel build: usa todos los cores disponibles (no limitar a 1-2)
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks -int 0
echo "[OK] Xcode parallel build (max cores)"

# ── Terminal ───────────────────────────────────────────────────────
defaults write com.apple.Terminal ShowLineMarks -int 0
echo "[OK] Terminal hide line marks"

defaults write com.apple.Terminal SecureKeyboardEntry -bool true
echo "[OK] Terminal Secure Keyboard Entry"

# UTF-8 only (prevents fallback to legacy encodings like MacRoman)
defaults write com.apple.Terminal StringEncodings -array 4
echo "[OK] Terminal UTF-8 only"

# ── TextEdit ───────────────────────────────────────────────────────
defaults write com.apple.TextEdit RichText -bool false
echo "[OK] TextEdit plain text default"

defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
echo "[OK] TextEdit UTF-8 encoding"

# ── Activity Monitor ───────────────────────────────────────────────
# Delete old key to reset Dock icon to default
defaults delete com.apple.ActivityMonitor IconType 2>/dev/null || true
echo "[OK] Activity Monitor default Dock icon"

defaults write com.apple.ActivityMonitor UpdatePeriod -int 2
echo "[OK] Activity Monitor refresh = 2s"

defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0
echo "[OK] Activity Monitor sort by CPU usage"

# 100 = todos los procesos. El 0 anterior era otra categoria, no "todos".
defaults write com.apple.ActivityMonitor ShowCategory -int 100
echo "[OK] Activity Monitor show all processes"

# ── Console ────────────────────────────────────────────────────────
defaults write com.apple.Console DebugMenuEnabled -bool true
defaults write com.apple.Console PrivateLogsEnabled -bool true
echo "[OK] Console debug menu + private logs"

# ── Help Viewer ────────────────────────────────────────────────────
defaults write com.apple.helpviewer DevMode -bool true
echo "[OK] Help Viewer doesn't float on top"

# ── Calendar ───────────────────────────────────────────────────────
defaults write com.apple.iCal IncludeDebugMenu -bool true
echo "[OK] Calendar debug menu"

# ── Notification Center ────────────────────────────────────────────
defaults write com.apple.notificationcenterui bannerTime -int 3
echo "[OK] Notification banner time = 3s"

# ── Login Window ───────────────────────────────────────────────────
defaults write com.apple.loginwindow SHOWFULLNAME -bool true
echo "[OK] Login window show full name"

# ── Menu Bar ───────────────────────────────────────────────────────
defaults write com.apple.menuextra.battery ShowPercent -bool true
echo "[OK] Battery percentage in menu bar"

defaults write com.apple.menuextra.clock IsAnalog -bool false
defaults write com.apple.menuextra.clock ShowSeconds -bool false
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
defaults write com.apple.menuextra.clock ShowDate -int 0
defaults write com.apple.menuextra.clock Show24Hour -bool true
# DateFormat unificado (reemplaza keys individuales en Sequoia+).
# OJO: en esta maquina esta key no persiste — macOS la borra y deja el formato
# derivado de Show24Hour + la region. Se mantiene por si en otra version pega.
defaults write com.apple.menuextra.clock DateFormat -string "HH:mm"
echo "[OK] Clock: digital, 24h, minimal"

# ── App Store ──────────────────────────────────────────────────────
defaults write com.apple.appstore ShowDebugMenu -bool true
defaults write com.apple.appstore IncludeDebugMenu -bool true
defaults write com.apple.appstore WebKitDeveloperExtras -bool true
echo "[OK] App Store debug menu enabled"

# Auto-update App Store apps (security: outdated apps = attack surface)
defaults write com.apple.commerce AutoUpdate -bool true
defaults write com.apple.commerce AutoUpdateRestartRequired -bool true
echo "[OK] App Store auto-update + auto-restart"

# ── Software Update ────────────────────────────────────────────────
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1
defaults write com.apple.SoftwareUpdate ConfigDataInstall -int 1
echo "[OK] Software Update: daily check + auto critical installs"

# ── Spotlight ──────────────────────────────────────────────────────
defaults write com.apple.Spotlight SuggestionsEnabled -bool false
echo "[OK] Spotlight suggestions disabled"

defaults write com.apple.Spotlight ServerSuggestionsEnabled -bool false
echo "[OK] Spotlight server suggestions disabled"

defaults write com.apple.Spotlight MenuBarSpotlightIcon -bool false
echo "[OK] Spotlight menu bar icon hidden"

# ── Sound ──────────────────────────────────────────────────────────
defaults write -g com.apple.sound.beep.feedback -int 0
echo "[OK] Volume change feedback silent"

# ── Library ────────────────────────────────────────────────────────
chflags nohidden ~/Library
echo "[OK] ~/Library visible"

# Tahoe Liquid Glass: stock macOS (transparency/glass aesthetic is iconic)
# Tahoe (macOS 26) usa Liquid Glass — reduceTransparency puede causar artefactos visuales
# Descomentar solo si tení macOS <26 o desactivaste Liquid Glass
defaults write com.apple.universalaccess reduceTransparency -bool true
echo "[OK] Disable transparency (reduce motion on liquid glass)"

# ── Zoom de pantalla ───────────────────────────────────────────────
# ctrl + scroll hace zoom. 262144 es la mascara del modificador Control.
defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
defaults write com.apple.universalaccess closeViewScrollWheelModifiersInt -int 262144
echo "[OK] Zoom con ctrl + scroll"

defaults write com.apple.universalaccess closeViewHotkeysEnabled -bool false
echo "[OK] Sin atajos de teclado para el zoom"

# ── Control Center / barra de menu ─────────────────────────────────
# Barra de menu al minimo: reloj, Control Center y Sonido. El resto sigue
# accesible desde el BentoBox, no se desactiva nada.
defaults write com.apple.controlcenter "NSStatusItem Visible BentoBox" -bool true
defaults write com.apple.controlcenter "NSStatusItem Visible Clock" -bool true
defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool true
defaults write com.apple.controlcenter "NSStatusItem Visible NowPlaying" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible FocusModes" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible AudioVideoModule" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Timer" -bool false
echo "[OK] Barra de menu minima (reloj + Control Center)"

# ── Reiniciar servicios ────────────────────────────────────────────
killall Dock 2>/dev/null && echo "[OK] Dock restarted"
killall Finder 2>/dev/null && echo "[OK] Finder restarted"
killall SystemUIServer 2>/dev/null && echo "[OK] SystemUIServer restarted"
killall "Clock" "WorldClockWidget" 2>/dev/null || true
killall cfprefsd 2>/dev/null && echo "[OK] cfprefsd restarted"
killall NotificationCenter 2>/dev/null && echo "[OK] NotificationCenter restarted"

echo "=== Done ==="
