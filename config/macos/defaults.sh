#!/usr/bin/env bash
# macOS Sequoia 15.x — defaults write optimizations
# Source: ChrisTitusTech/macutil (curated for developers)
# Apply: chmod +x defaults.sh && ./defaults.sh
set -euo pipefail

echo "=== Aplicando defaults de macOS ==="

# ═══════════════════════════════════════════════════════════════════
# NOTAS PARA DESARROLLADORES
# ═══════════════════════════════════════════════════════════════════
# reduceMotion NO se aplica — activa prefers-reduced-motion en
# navegadores y bloquea animaciones CSS/JS/web. El resto de los
# defaults son seguros: afectan UI nativa de macOS, no WebKit/Blink.

# ── Accesibilidad ──────────────────────────────────────────────────
# reduceMotion OMITIDO intencionalmente (ver nota arriba)

# ── Animaciones de ventanas ────────────────────────────────────────
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
echo "[OK] Window resize instant"

defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
echo "[OK] Window open/close animations disabled"

# Desactiva animación del anillo de foco al navegar con Tab
defaults write NSGlobalDomain NSUseAnimatedFocusRing -bool false
echo "[OK] Focus ring animation disabled"

# ── Teclado ──────────────────────────────────────────────────────────
# CRÍTICO: sin esto, mantener tecla = menú acentos en vez de repetir
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
echo "[OK] Key repeat enabled (no accent popup on hold)"

# InitialKeyRepeat: delay antes de repetir (default 15 = 225ms, mínimo real que macOS respeta)
defaults write NSGlobalDomain InitialKeyRepeat -int 15
echo "[OK] Key repeat delay = 225ms"

# KeyRepeat: velocidad de repetición (default 2 = 30ms, 1 = 15ms)
defaults write NSGlobalDomain KeyRepeat -int 2
echo "[OK] Key repeat rate = 30ms"

# ── Scroll ─────────────────────────────────────────────────────────
defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false
echo "[OK] Smooth scrolling disabled"

defaults write NSGlobalDomain AppleScrollerPagingBehavior -bool true
echo "[OK] Click scroll bar = jump to position"

# ── Quick Look ─────────────────────────────────────────────────────
defaults write -g QLPanelAnimationDuration -float 0
echo "[OK] Quick Look animation = 0"

# ── Mission Control ────────────────────────────────────────────────
defaults write com.apple.dock expose-animation-duration -float 0.1
echo "[OK] Mission Control speed"

defaults write com.apple.dock expose-group-apps -bool true
echo "[OK] Mission Control group by app"

defaults write com.apple.dock mru-spaces -bool false
echo "[OK] Spaces never rearrange"

# ── Launchpad ──────────────────────────────────────────────────────
defaults write com.apple.dock springboard-show-duration -float 0.1
echo "[OK] Launchpad show speed"

defaults write com.apple.dock springboard-hide-duration -float 0.1
echo "[OK] Launchpad hide speed"

# ── Dock ───────────────────────────────────────────────────────────
defaults write com.apple.dock autohide-time-modifier -float 0
echo "[OK] Dock hide/show instant"

defaults write com.apple.dock autohide-delay -float 0
echo "[OK] Dock show delay = 0"

defaults write com.apple.dock mineffect -string "scale"
echo "[OK] Dock minimize effect = scale"

defaults write com.apple.dock minimize-to-application -bool true
echo "[OK] Minimize into app icon"

defaults write com.apple.dock show-recents -bool false
echo "[OK] No recent apps in Dock"

defaults write com.apple.dock static-only -bool true
echo "[OK] Only running apps in Dock"

defaults write com.apple.dock launchanim -bool false
echo "[OK] App launch animation off"

# Scroll gesture on Dock icon = Exposé for that app
defaults write com.apple.dock scroll-to-open -bool true
echo "[OK] Dock scroll to Exposé"

# Spring-load on all Dock items (not just folders)
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
echo "[OK] Spring-load all Dock items"

# Indicadores luminosos bajo apps abiertas
defaults write com.apple.dock show-process-indicators -bool true
echo "[OK] Dock process indicators"

# Mostrar apps ocultas con icono translúcido
defaults write com.apple.dock showhidden -bool true
echo "[OK] Dock show hidden app icons"

# Desactiva rebote de íconos cuando apps piden atención
defaults write com.apple.dock no-bouncing -bool true
echo "[OK] Dock no bouncing icons"

# ── Trackpad ─────────────────────────────────────────────────────────
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 1.5
echo "[OK] Trackpad tracking speed"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
echo "[OK] Tap to click"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
echo "[OK] Two-finger right click"

# ── Bluetooth ──────────────────────────────────────────────────────────
# Mejora calidad de audio en auriculares Bluetooth (default 0x80 = low)
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
echo "[OK] Bluetooth audio bitpool = 40"

# ── WindowManager (Sequoia 15.x) ──────────────────────────────────────
# Tiling edge-to-edge sin margen entre ventanas
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
echo "[OK] WindowManager tiling no margins"

# ── Finder ─────────────────────────────────────────────────────────
defaults write com.apple.finder DisableAllAnimations -bool true
echo "[OK] Finder animations disabled"

defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
echo "[OK] Finder default list view"

defaults write com.apple.finder AppleShowAllFiles -bool true
echo "[OK] Finder show hidden files"

# Quit menu item (Cmd+Q closes Finder)
defaults write com.apple.finder QuitMenuItem -bool true
echo "[OK] Finder Quit menu item"

# No warning when changing file extensions
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
echo "[OK] No extension change warning"

# No warning when emptying Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false
echo "[OK] No empty Trash warning"

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true
echo "[OK] Folders on top"

# Open folders in tabs instead of new windows
defaults write com.apple.finder FinderSpawnTab -bool true
echo "[OK] Finder open in tabs"

defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
echo "[OK] Finder full POSIX path in title bar"

defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
echo "[OK] Finder search current folder"

defaults write com.apple.finder FXRemoveOldTrashItems -bool true
echo "[OK] Auto-delete trash >30 days"

defaults write com.apple.finder ShowStatusBar -bool true
echo "[OK] Finder status bar"

defaults write com.apple.finder ShowPathbar -bool true
echo "[OK] Finder path bar"

defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true
echo "[OK] Sidebar devices section"

defaults write com.apple.finder SidebarPlacesSectionDisclosedState -bool true
echo "[OK] Sidebar places section"

defaults write com.apple.finder SidebarShowingiCloudDesktop -bool false
echo "[OK] Hide iCloud Desktop from sidebar"

# Mostrar discos externos, servidores y medios removibles en escritorio
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
echo "[OK] Finder show external/removable drives on desktop"

# Nueva ventana de Finder abre Home (no Recents)
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
echo "[OK] Finder new window = Home"

defaults write com.apple.finder FK_StandardViewSettings -dict-add ListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
defaults write com.apple.finder FK_StandardViewSettings -dict-add ExtendedListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
echo "[OK] Finder list view columns: name, date, size"

defaults delete com.apple.finder FXInfoPanesExpanded 2>/dev/null || true
echo "[OK] Finder info panes reset"

defaults delete com.apple.finder FXDesktopVolumePositions 2>/dev/null || true
echo "[OK] Desktop icon positions reset"

# Permitir seleccionar texto en Quick Look (copiar sin abrir archivo)
defaults write com.apple.finder QLEnableTextSelection -bool true
echo "[OK] Quick Look text selection"

# ── Network Browser ─────────────────────────────────────────────────
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true
echo "[OK] Network browser show all interfaces"

# ── .DS_Store ──────────────────────────────────────────────────────
# Evita crear .DS_Store en volúmenes de red y USB (requiere logout)
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
echo "[OK] No .DS_Store on network volumes"

defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
echo "[OK] No .DS_Store on USB drives"

# ── Archive Utility ─────────────────────────────────────────────────
# No crear carpetas __MACOSX al extraer ZIPs
defaults write com.apple.archiveutility "com.apple.archiveutility.disable-resourceforks" -bool true
echo "[OK] Archive Utility no __MACOSX folders"

# ── Global Finder ──────────────────────────────────────────────────
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
echo "[OK] Show all file extensions"

defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1
echo "[OK] Small sidebar icons"

defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"
echo "[OK] Scroll bars visible on scroll"

defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true
echo "[OK] Show invisible characters"

defaults write NSGlobalDomain com.apple.springing.enabled -bool true
echo "[OK] Spring-loaded folders"

defaults write NSGlobalDomain com.apple.springing.delay -float 0.5
echo "[OK] Spring-load delay = 0.5s"

defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
echo "[OK] Auto-capitalization off"

defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
echo "[OK] Smart dashes off"

defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
echo "[OK] Auto-period off"

defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
echo "[OK] Smart quotes off"

defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false
echo "[OK] Web spelling correction off"

# Full keyboard navigation — Tab between ALL controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
echo "[OK] Full keyboard navigation"

# Disable automatic text completion (inline suggestions)
defaults write NSGlobalDomain NSAutomaticTextCompletionEnabled -bool false
echo "[OK] Auto text completion off"

# Sequoia: desactiva predicciones inline grises (Apple Intelligence typing)
defaults write NSGlobalDomain NSAutomaticInlinePredictionEnabled -bool false
echo "[OK] Inline predictions off"

# Instant toolbar title rollover (proxy icon in title bar)
defaults write NSGlobalDomain NSToolbarTitleViewRolloverDelay -float 0
echo "[OK] Toolbar title rollover instant"

# Ctrl+Cmd+click arrastra ventanas desde cualquier parte (no solo title bar)
defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool true
echo "[OK] Drag windows from anywhere (Ctrl+Cmd+click)"

# Desactiva App Nap globalmente (evita throttling de build watchers/dev servers)
defaults write NSGlobalDomain NSAppSleepDisabled -bool true
echo "[OK] App Nap disabled globally"

# Documentos nuevos en tabs, no ventanas separadas
defaults write NSGlobalDomain AppleWindowTabbingMode -string "always"
echo "[OK] New documents open in tabs"

# Evita que macOS cierre apps idle automáticamente (Preview, QuickTime)
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
echo "[OK] No automatic app termination"

# ── Diálogos Save/Print ──────────────────────────────────────────────
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
echo "[OK] Save dialog always expanded"

defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
echo "[OK] Save to disk by default (not iCloud)"

defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
echo "[OK] Print dialog always expanded"

# ── Screensaver ─────────────────────────────────────────────────────
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
echo "[OK] Screensaver password immediate"

# ── Screenshots ────────────────────────────────────────────────────
defaults write com.apple.screencapture disable-shadow -bool true
echo "[OK] Screenshot shadows off"

defaults write com.apple.screencapture type -string "png"
echo "[OK] Screenshot format = PNG"

defaults write com.apple.screencapture location -string "${HOME}/Desktop"
echo "[OK] Screenshots to Desktop"

# Disable floating thumbnail preview (save directly to disk)
defaults write com.apple.screencapture show-thumbnail -bool false
echo "[OK] Screenshot thumbnail off"

# Nombre de archivo sin timestamp (Screenshot.png en vez de Screenshot 2026-05-23 at 14.30.45.png)
defaults write com.apple.screencapture include-date -bool false
echo "[OK] Screenshot filenames no timestamp"

# ── Global Window Restoration ────────────────────────────────────────
# Cierra ventanas al salir de apps (inverso de System Settings → Desktop & Dock → "Close windows when quitting")
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
echo "[OK] No window restoration on app quit"

# ── Preview ─────────────────────────────────────────────────────────
# No restaurar PDFs/imágenes al reabrir (evita flood de ventanas viejas)
defaults write com.apple.Preview NSQuitAlwaysKeepsWindows -bool false
echo "[OK] Preview no window restoration"

# ── Mail ───────────────────────────────────────────────────────────
defaults write com.apple.mail DisableReplyAnimations -bool true
echo "[OK] Mail reply animations off"

defaults write com.apple.mail DisableSendAnimations -bool true
echo "[OK] Mail send animations off"

defaults write com.apple.mail DisableInlineAttachmentViewing -bool true
echo "[OK] Mail inline attachments off"

# Forzar composición en texto plano (sin HTML)
defaults write com.apple.mail PreferPlainText -bool true
echo "[OK] Mail plain text compose"

# Copiar dirección de email sin nombre del contacto
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false
echo "[OK] Mail copy email address only"

# ── Disk Utility ───────────────────────────────────────────────────
defaults write com.apple.frameworks.diskimages skip-verify -bool true
defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true
echo "[OK] Skip DMG verification"

# Disk Utility: menú Debug + opciones avanzadas de imagen
defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
defaults write com.apple.DiskUtility advanced-image-options -bool true
echo "[OK] Disk Utility debug menu + advanced image options"

# ── Time Machine ───────────────────────────────────────────────────
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
echo "[OK] No Time Machine prompts"

# ── Privacidad ───────────────────────────────────────────────────────
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false
echo "[OK] Don't send diagnostics to Apple"

defaults write com.apple.CrashReporter DialogType -string "none"
echo "[OK] Crash reporter dialogs disabled"

defaults write com.apple.Siri SiriPrefStashedStatusMenuVisible -bool false
defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
echo "[OK] Siri disabled"

# Evita que macOS pregunte "Enable Siri?" después de updates
defaults write com.apple.Siri UserHasDeclinedEnable -bool true
echo "[OK] Siri declined permanently"

# ── Image Capture ───────────────────────────────────────────────────
# Evita que Photos.app se abra al conectar cámara/SD
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
echo "[OK] Image Capture no auto-launch"

# ── Safari / WebKit ────────────────────────────────────────────────
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true
echo "[OK] WebKit developer extras"

defaults write com.apple.Safari IncludeDevelopMenu -bool true
echo "[OK] Safari Develop menu"

defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
echo "[OK] Safari WebKit dev extras"

defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
echo "[OK] Safari full URL in address bar"

defaults write com.apple.Safari UniversalSearchEnabled -bool false
echo "[OK] Safari universal search off"

defaults write com.apple.Safari SuppressSearchSuggestions -bool true
echo "[OK] Safari search suggestions off"

# Enable debug menu
defaults write com.apple.Safari IncludeDebugMenu -bool true
echo "[OK] Safari Debug menu"

# Enable WebKit2 developer extras (modern rendering engine)
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
echo "[OK] Safari WebKit2 dev extras"

# Disable Safari spelling correction
defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false
echo "[OK] Safari spelling correction off"

# Security: no abrir archivos "seguros" automáticamente
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
echo "[OK] Safari never auto-open downloads"

# Security: activar advertencia de sitios fraudulentos
defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true
echo "[OK] Safari fraudulent site warnings ON"

# Auto-instalar extensiones de Safari
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true
echo "[OK] Safari auto-update extensions"

# Desactivar AutoFill (privacidad)
defaults write com.apple.Safari AutoFillFromAddressBook -bool false
defaults write com.apple.Safari AutoFillPasswords -bool false
defaults write com.apple.Safari AutoFillCreditCardData -bool false
defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false
echo "[OK] Safari AutoFill disabled"

# Find on page: buscar "contiene" en vez de "empieza con"
defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false
echo "[OK] Safari find contains (not starts-with)"

# Internal Debug menu (más profundo que Develop + Debug)
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
echo "[OK] Safari Internal Debug menu"

# ── Apple Intelligence ─────────────────────────────────────────────
# Sequoia 15.x: Feature ID 545129924
defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool false
echo "[OK] Apple Intelligence opt-out"

# ── Terminal ────────────────────────────────────────────────────────
# Default encoding UTF-8
defaults write com.apple.terminal StringEncodings -array 4
echo "[OK] Terminal UTF-8 encoding"

# Secure keyboard entry (prevents other apps from reading keystrokes)
defaults write com.apple.Terminal SecureKeyboardEntry -bool true
echo "[OK] Terminal secure keyboard entry"

# Ocultar marcas de scroll en la ventana
defaults write com.apple.Terminal ShowLineMarks -int 0
echo "[OK] Terminal hide line marks"

# ── TextEdit ────────────────────────────────────────────────────────
# Default to plain text mode (not rich text)
defaults write com.apple.TextEdit RichText -int 0
echo "[OK] TextEdit plain text default"

# UTF-8 encoding for read/write
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
echo "[OK] TextEdit UTF-8 encoding"

# ── Activity Monitor ──────────────────────────────────────────────
defaults write com.apple.ActivityMonitor ShowCategory -int 0
echo "[OK] Activity Monitor show all processes"

# Dock icon muestra uso de CPU como gráfico
defaults write com.apple.ActivityMonitor IconType -int 5
echo "[OK] Activity Monitor CPU history icon"

# Refresco cada 2s en vez de 5s (default)
defaults write com.apple.ActivityMonitor UpdatePeriod -int 2
echo "[OK] Activity Monitor refresh = 2s"

# ── Help Viewer ───────────────────────────────────────────────────
defaults write com.apple.helpviewer DevMode -bool true
echo "[OK] Help Viewer doesn't float on top"

# ── Software Update ───────────────────────────────────────────────
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
echo "[OK] Automatic update checks ON"

defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false
echo "[OK] No automatic update downloads"

# Auto-instalar parches de seguridad y datos de configuración (XProtect, MRT, etc.)
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1
echo "[OK] Auto-install critical security updates"

defaults write com.apple.SoftwareUpdate ConfigDataInstall -int 1
echo "[OK] Auto-install XProtect/MRT data"

# ── Notification Center ──────────────────────────────────────────────
# Banners desaparecen en 3s (default ~5s)
defaults write com.apple.notificationcenterui bannerTime -int 3
echo "[OK] Notification banner time = 3s"

# ── Login Window ────────────────────────────────────────────────────
# No restaurar apps al reiniciar/login
defaults write com.apple.loginwindow TALLogoutSavesState -bool false
defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false
echo "[OK] Login: no app restoration on reboot"

# ── Menu Bar ────────────────────────────────────────────────────────
defaults write com.apple.menuextra.battery ShowPercent -string "YES"
echo "[OK] Battery percentage in menu bar"

# ── App Store ───────────────────────────────────────────────────────
defaults write com.apple.commerce AutoUpdate -bool true
echo "[OK] App Store auto-update apps"

defaults write com.apple.commerce AutoUpdateRestartRequired -bool true
echo "[OK] App Store auto-restart apps"

# ── Spotlight ─────────────────────────────────────────────────────
# Disable Spotlight Suggestions — prevents sending searches to Apple
defaults write com.apple.Spotlight SuggestionsEnabled -bool false
echo "[OK] Spotlight suggestions disabled"

# ── Sound ──────────────────────────────────────────────────────────
# Sin beep/pop al ajustar volumen con teclas
defaults write -g com.apple.sound.beep.feedback -int 0
echo "[OK] Volume change feedback silent"

# ── Library visible ─────────────────────────────────────────────────
# ~/Library visible en Finder sin Cmd+Shift+G
chflags nohidden ~/Library
echo "[OK] ~/Library visible"

# ── Reiniciar servicios ────────────────────────────────────────────
killall Dock 2>/dev/null  && echo "[OK] Dock restarted"
killall Finder 2>/dev/null && echo "[OK] Finder restarted"
killall SystemUIServer 2>/dev/null && echo "[OK] SystemUIServer restarted"
killall cfprefsd 2>/dev/null   && echo "[OK] cfprefsd restarted"
killall NotificationCenter 2>/dev/null && echo "[OK] NotificationCenter restarted"

echo "=== Done ==="
