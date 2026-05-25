#!/usr/bin/env bash
# macOS Sequoia 15.x / Tahoe 26.x — defaults write optimizations
# Source: ChrisTitusTech/macutil (curated for developers)
# Apply: chmod +x defaults.sh && ./defaults.sh
set -euo pipefail

echo "=== Aplicando defaults de macOS ==="

# ── Animaciones de ventanas ────────────────────────────────────────
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
echo "[OK] Window resize instant"

defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
echo "[OK] Window open/close animations disabled"

# Desactiva animación del anillo de foco al navegar con Tab
defaults write NSGlobalDomain NSUseAnimatedFocusRing -bool false
echo "[OK] Focus ring animation disabled"

# Rubber-band scrolling (rebote elástico al llegar al final del scroll)
defaults write NSGlobalDomain NSScrollViewRubberbanding -bool false
echo "[OK] Rubber-band scrolling disabled"

# Animación del navegador de versiones de documentos
defaults write NSGlobalDomain NSDocumentRevisionsWindowTransformAnimation -bool false
echo "[OK] Document revisions animation disabled"

# Toolbar en full-screen: animación instantánea
defaults write NSGlobalDomain NSToolbarFullScreenAnimationDuration -float 0
echo "[OK] Full-screen toolbar animation instant"

# Animación de columnas en diálogos de archivos (vista columnas)
defaults write NSGlobalDomain NSBrowserColumnAnimationSpeedMultiplier -float 0
echo "[OK] Column view animation disabled"

# ── Scroll ─────────────────────────────────────────────────────────
defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false
echo "[OK] Smooth scrolling disabled"

defaults write NSGlobalDomain AppleScrollerPagingBehavior -bool true
echo "[OK] Click scroll bar = jump to position"

# ── Quick Look ─────────────────────────────────────────────────────
defaults write -g QLPanelAnimationDuration -float 0
echo "[OK] Quick Look animation = 0"

# Desactiva magnificación del cursor al agitarlo (reduce GPU usage)
defaults write -g CGDisableCursorLocationMagnification -bool true
echo "[OK] Cursor location magnification off"

# ── Mission Control ────────────────────────────────────────────────
defaults write com.apple.dock expose-animation-duration -float 0.1
echo "[OK] Mission Control speed"

defaults write com.apple.dock mru-spaces -bool false
echo "[OK] Spaces never rearrange"

# No hacer auto-switch al espacio de una app al hacer click en Dock
defaults write com.apple.dock workspaces-auto-swoosh -bool false
echo "[OK] Dock: no auto-switch space on app click"

# ── Launchpad (Sequoia 15.x only — removed in Tahoe 26.x) ──────────
defaults write com.apple.dock springboard-show-duration -float 0.1
echo "[OK] Launchpad show speed"

defaults write com.apple.dock springboard-hide-duration -float 0.1
echo "[OK] Launchpad hide speed"

defaults write com.apple.dock springboard-page-duration -float 0
echo "[OK] Launchpad page scroll instant"

# ── Dock ───────────────────────────────────────────────────────────
defaults write com.apple.dock autohide-time-modifier -float 0
echo "[OK] Dock hide/show instant"

defaults write com.apple.dock autohide-delay -float 0
echo "[OK] Dock show delay = 0"

defaults write com.apple.dock tilesize -int 48
echo "[OK] Dock tile size = 48px"

defaults write com.apple.dock mineffect -string "scale"
echo "[OK] Dock minimize effect = scale"

defaults write com.apple.dock minimize-to-application -bool true
echo "[OK] Minimize into app icon"

defaults write com.apple.dock show-recents -bool false
echo "[OK] No recent apps in Dock"

defaults write com.apple.dock launchanim -bool false
echo "[OK] App launch animation off"

# Scroll gesture on Dock icon = Exposé for that app
defaults write com.apple.dock scroll-to-open -bool true
echo "[OK] Dock scroll to Exposé"

# Spring-load on all Dock items (not just folders)
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
echo "[OK] Spring-load all Dock items"

# Mostrar apps ocultas con icono translúcido
defaults write com.apple.dock showhidden -bool true
echo "[OK] Dock show hidden app icons"

# Desactiva rebote de íconos cuando apps piden atención
defaults write com.apple.dock no-bouncing -bool true
echo "[OK] Dock no bouncing icons"

# Auto-hide Dock (más espacio vertical para contenido)
defaults write com.apple.dock autohide -bool true
echo "[OK] Dock auto-hide"

# Resaltar stacks al pasar el mouse (mejor feedback visual)
defaults write com.apple.dock mouse-over-hilite-stack -bool true
echo "[OK] Dock highlight stacks on hover"

# Desactiva transparencia del Dock (reduce GPU compositing)
defaults write com.apple.dock no-glass -bool YES
echo "[OK] Dock glass effect off"

# ── Trackpad ─────────────────────────────────────────────────────────
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 1.5
echo "[OK] Trackpad tracking speed"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
echo "[OK] Tap to click"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
echo "[OK] Two-finger right click"

# ── Keyboard ──────────────────────────────────────────────────────────
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain KeyRepeat -int 2
echo "[OK] Key repeat: delay 225ms, rate 30ms"

# ── Bluetooth ──────────────────────────────────────────────────────────
# Mejora calidad de audio en auriculares Bluetooth (default min ~40)
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Max (editable)" -int 80
defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool Min (editable)" -int 80
defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool (editable)" -int 80
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool" -int 80
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Max" -int 80
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Min" -int 48
echo "[OK] Bluetooth audio bitpool optimized (40-80, negotiated 48-80)"

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

# No warning when changing file extensions
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
echo "[OK] No extension change warning"

# Open folders in tabs instead of new windows
defaults write com.apple.finder FinderSpawnTab -bool true
echo "[OK] Finder open in tabs"

defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
echo "[OK] Finder search current folder"


defaults write com.apple.finder ShowStatusBar -bool true
echo "[OK] Finder status bar"

defaults write com.apple.finder ShowPathbar -bool true
echo "[OK] Finder path bar"

defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
echo "[OK] Finder full POSIX path in title"

defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true
echo "[OK] Sidebar devices section"

defaults write com.apple.finder SidebarPlacesSectionDisclosedState -bool true
echo "[OK] Sidebar places section"

defaults write com.apple.finder SidebarShowingiCloudDesktop -bool false
echo "[OK] Hide iCloud Desktop from sidebar"

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

# Extraer en directorio actual (no en subcarpeta)
defaults write com.apple.archiveutility "dearchive-into-subfolder" -bool false
echo "[OK] Archive Utility extract in current folder"

# Mover archivo a Papelera después de extraer
defaults write com.apple.archiveutility "move-archive-to-trash" -bool true
echo "[OK] Archive Utility auto-trash after extract"

# ── Global Finder ──────────────────────────────────────────────────
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
echo "[OK] Show all file extensions"

defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1
echo "[OK] Small sidebar icons"

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

# ── Diálogos Save/Print ──────────────────────────────────────────────
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
echo "[OK] Save dialog always expanded"

defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
echo "[OK] Save to disk by default (not iCloud)"

defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
echo "[OK] Print dialog always expanded"

# Cerrar automáticamente el diálogo de impresión al terminar
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
echo "[OK] Print dialog auto-close after job"

# ── Screensaver ─────────────────────────────────────────────────────
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
defaults write com.apple.screensaver idleTime -int 300
echo "[OK] Screensaver password immediate (5 min idle)"

# ── Screenshots ────────────────────────────────────────────────────
defaults write com.apple.screencapture disable-shadow -bool true
echo "[OK] Screenshot shadows off"

# ── Global Window Restoration ────────────────────────────────────────
# Cierra ventanas al salir de apps (inverso de System Settings → Desktop & Dock → "Close windows when quitting")
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
echo "[OK] No window restoration on app quit"

# ── Preview ─────────────────────────────────────────────────────────
# No restaurar PDFs/imágenes al reabrir (evita flood de ventanas viejas)
defaults write com.apple.Preview NSQuitAlwaysKeepsWindows -bool false
echo "[OK] Preview no window restoration"

# ── QuickTime Player ────────────────────────────────────────────────
defaults write com.apple.QuickTimePlayerX NSQuitAlwaysKeepsWindows -bool false
defaults write com.apple.QuickTimePlayerX MGPlayMovieOnOpen -bool true
echo "[OK] QuickTime no window restoration + auto-play on open"

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

defaults write com.apple.mail SpellCheckingBehavior -string "NoSpellCheckingEnabled"
echo "[OK] Mail spell checking off"

# ── Messages ────────────────────────────────────────────────────────
# Desactivar auto-emoji, smart quotes y spell check en iMessage
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticEmojiSubstitutionEnablediMessage" -bool false
echo "[OK] Messages: auto-emoji off"

defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false
echo "[OK] Messages: smart quotes off"

# ── Disk Utility ───────────────────────────────────────────────────
echo "[SKIP] DMG verification kept at system default (security)"

# Auto-abrir imágenes de disco montadas (ro y rw)
defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
echo "[OK] Auto-open DMG root after mount"

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
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
echo "[OK] Siri disabled + menu bar icon removed"

# Evita que macOS pregunte "Enable Siri?" después de updates
defaults write com.apple.Siri UserHasDeclinedEnable -bool true
echo "[OK] Siri declined permanently"

# Dictado por voz desactivado (evita envío de audio a servidores Apple)
defaults write com.apple.assistant.support "Dictation Enabled" -bool false
echo "[OK] Dictation disabled"
# Spotlight/Siri: no enviar búsquedas a Apple
defaults write com.apple.assistant.support "Search Queries Data Sharing Status" -int 2
echo "[OK] Search queries data sharing off"

# Siri: no compartir datos de uso con Apple (mejora de Siri)
defaults write com.apple.assistant.support "Siri Data Sharing Opt-In Status" -int 2
echo "[OK] Siri data sharing opt-out"

# Desactivar motor de sugerencias de Siri (indexación en segundo plano)
defaults write com.apple.suggestions SiriSuggestionsEnabled -bool false
echo "[OK] Siri suggestions engine off"

# Desactivar Siri Assistant core (ahorra CPU en segundo plano)
defaults write com.apple.assistant.support "Assistant Enabled" -bool false
echo "[OK] Siri Assistant core disabled"

# No recolectar archivos automáticamente al reportar feedback
defaults write com.apple.appleseed.FeedbackAssistant Autogather -bool false
echo "[OK] Feedback Assistant no auto-gather"

# Desactivar IDFA (Identifier for Advertisers) — previene tracking cross-app
defaults write com.apple.AdLib allowIdentifierForAdvertising -int 0
echo "[OK] Advertising identifier disabled"
# Desactivar publicidad personalizada de Apple (App Store, News, Stocks)
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false
echo "[OK] Apple personalized advertising off"

defaults write com.apple.AdLib forceLimitAdTracking -bool true
echo "[OK] Ad tracking force-limited"

# ── Telemetría y diagnóstico ──────────────────────────────────────
# Desactivar envío de datos a terceros
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

# ── Apps: anonymous usage opt-out ─────────────────────────────────
defaults write com.apple.Maps UserSelectedAnonymousUsageOptIn -bool false
echo "[OK] Maps anonymous usage off"

defaults write com.apple.Health UserSelectedAnonymousUsageOptIn -bool false
echo "[OK] Health anonymous usage off"

defaults write com.apple.imessage UserSelectedAnonymousUsageOptIn -bool false
echo "[OK] iMessage anonymous usage off"

defaults write com.apple.Photos UserSelectedAnonymousUsageOptIn -bool false
echo "[OK] Photos anonymous usage off"

# Handoff: desactivar logging de actividad (Handoff en sí sigue activo)
defaults write -g NSUserActivityLoggingEnabled -bool false
echo "[OK] Handoff activity logging off"

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

defaults write com.apple.Safari SearchSuggestionsEnabled -bool false
echo "[OK] Safari search suggestions disabled"

defaults write com.apple.Safari PreloadTopHit -bool false
echo "[OK] Safari preload top hit off"

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

# Desactivar AutoFill (privacidad)
defaults write com.apple.Safari AutoFillFromAddressBook -bool false
defaults write com.apple.Safari AutoFillPasswords -bool false
defaults write com.apple.Safari AutoFillCreditCardData -bool false
defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false
echo "[OK] Safari AutoFill disabled"

# Security: enviar header Do Not Track
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true
echo "[OK] Safari Do Not Track"

# Privacidad mejorada en navegación normal (no solo private browsing)
defaults write com.apple.Safari EnableEnhancedPrivacyInRegularBrowsing -bool true
echo "[OK] Safari enhanced privacy in regular browsing"

# Tab navega entre links (keyboard navigation, accesibilidad)
defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" -bool true
echo "[OK] Safari Tab to links"

# Backspace/Delete navega a página anterior
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" -bool true
echo "[OK] Safari backspace navigation"

# Página de inicio en blanco (no carga nada al abrir nueva ventana/pestaña)
defaults write com.apple.Safari HomePage -string "about:blank"
echo "[OK] Safari blank homepage"

# Ocultar barra de favoritos y sidebar en Top Sites
defaults write com.apple.Safari ShowFavoritesBar -bool false
defaults write com.apple.Safari ShowSidebarInTopSites -bool false
echo "[OK] Safari hide favorites bar + sidebar"

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

# ── Xcode & Simulator ─────────────────────────────────────────────────
# Debug menu interno (opciones avanzadas de debugging)
defaults write com.apple.dt.Xcode ShowDVTDebugMenu -bool YES
echo "[OK] Xcode DVT debug menu"

# Suprimir upsell de Xcode Cloud
defaults write com.apple.dt.Xcode XcodeCloudUpsellPromptEnabled -bool false
echo "[OK] Xcode Cloud upsell suppressed"

# Progreso numérico durante indexing (feedback visual útil)
defaults write com.apple.dt.Xcode IDEIndexerActivityShowNumericProgress -bool true
echo "[OK] Xcode indexing numeric progress"

# Mostrar extensiones de archivo en navegador de proyecto
defaults write com.apple.dt.Xcode IDEFileExtensionDisplayMode -int 1
echo "[OK] Xcode file extensions visible"

# Mostrar build version en icono del Dock (útil con múltiples Xcodes)
defaults write com.apple.dt.Xcode DVTEnableDockIconVersionNumber -bool YES
echo "[OK] Xcode build version in Dock icon"

# No restaurar tabs/ventanas al abrir proyecto (arranque más rápido)
defaults write com.apple.dt.Xcode IDEDisableStateRestoration -bool YES
echo "[OK] Xcode no state restoration on launch"

# No reabrir automáticamente el último proyecto
defaults write com.apple.dt.Xcode ApplePersistenceIgnoreState -bool YES
echo "[OK] Xcode no auto-reopen last project"

# Mostrar toques en Simulator (útil para demos/grabaciones)
defaults write com.apple.iphonesimulator ShowSingleTouches -int 1
echo "[OK] Simulator show touches"

# ── Terminal ────────────────────────────────────────────────────────

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
# Icono default en Dock (no grafico de CPU) — borrar key vieja si existe
defaults delete com.apple.ActivityMonitor IconType 2>/dev/null || true
echo "[OK] Activity Monitor default Dock icon"

# Refresco cada 2s en vez de 5s (default)
defaults write com.apple.ActivityMonitor UpdatePeriod -int 2
echo "[OK] Activity Monitor refresh = 2s"

# Ordenar por CPU descendente (procesos más intensivos arriba)
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0
echo "[OK] Activity Monitor sort by CPU usage"

# ── Console ──────────────────────────────────────────────────────────
# Debug menu (logging avanzado para developers)
defaults write com.apple.Console DebugMenuEnabled -bool true
# Mostrar logs privados (system/3rd-party) en vez de ocultarlos
defaults write com.apple.Console PrivateLogsEnabled -bool true
echo "[OK] Console debug menu + private logs"

# ── Help Viewer ───────────────────────────────────────────────────
defaults write com.apple.helpviewer DevMode -bool true
echo "[OK] Help Viewer doesn't float on top"

# ── Calendar ──────────────────────────────────────────────────────
defaults write com.apple.iCal IncludeDebugMenu -bool true
echo "[OK] Calendar debug menu"

# ── Software Update ───────────────────────────────────────────────
# ── Notification Center ──────────────────────────────────────────────
# Banners desaparecen en 3s (default ~5s)
defaults write com.apple.notificationcenterui bannerTime -int 3
echo "[OK] Notification banner time = 3s"

# ── Login Window ────────────────────────────────────────────────────
# No restaurar apps al reiniciar/login
defaults write com.apple.loginwindow TALLogoutSavesState -bool false
defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false
echo "[OK] Login: no app restoration on reboot"

# Mostrar nombre completo en pantalla de login (seguridad: quién está logueado)
defaults write com.apple.loginwindow SHOWFULLNAME -bool true
echo "[OK] Login window show full name"

# ── Menu Bar ────────────────────────────────────────────────────────
defaults write com.apple.menuextra.battery ShowPercent -string "YES"
echo "[OK] Battery percentage in menu bar"

# Reloj minimalista: solo hora HH:mm digital, sin fecha ni segundos
defaults write com.apple.menuextra.clock IsAnalog -bool false
defaults write com.apple.menuextra.clock ShowSeconds -bool false
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
defaults write com.apple.menuextra.clock ShowDate -int 0
# DateFormat para Sequoia+ (reemplaza keys individuales)
defaults write com.apple.menuextra.clock DateFormat -string "HH:mm"
echo "[OK] Clock: digital, minimal (HH:mm)"

# Reducir spacing entre iconos de menubar (util en MacBooks con notch)
defaults -currentHost write -globalDomain NSStatusItemSpacing -int 6
defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 12
echo "[OK] Menu bar icon spacing compact"

# ── App Store ───────────────────────────────────────────────────────
# Debug menu (útil para devs: refresh cache, reset download queue)
defaults write com.apple.appstore ShowDebugMenu -bool true
defaults write com.apple.appstore IncludeDebugMenu -bool true
defaults write com.apple.appstore WebKitDeveloperExtras -bool true
echo "[OK] App Store debug menu enabled"

# ── Spotlight ─────────────────────────────────────────────────────
# Disable Spotlight Suggestions — prevents sending searches to Apple
defaults write com.apple.Spotlight SuggestionsEnabled -bool false
echo "[OK] Spotlight suggestions disabled"

defaults write com.apple.Spotlight ServerSuggestionsEnabled -bool false
echo "[OK] Spotlight server suggestions disabled"

# Ocultar icono de Spotlight en menu bar (segui accesible via Cmd+Space)
defaults write com.apple.Spotlight MenuBarSpotlightIcon -bool false
echo "[OK] Spotlight menu bar icon hidden"

# ── Sound ──────────────────────────────────────────────────────────
# Sin beep/pop al ajustar volumen con teclas
defaults write -g com.apple.sound.beep.feedback -int 0
echo "[OK] Volume change feedback silent"

# ── Library visible ─────────────────────────────────────────────────
# ~/Library visible en Finder sin Cmd+Shift+G
chflags nohidden ~/Library
echo "[OK] ~/Library visible"

# ── Tahoe 26.x — Liquid Glass ───────────────────────────────────────
# Oculta íconos clutter en items de menú (nuevo en Liquid Glass design)
defaults write -g NSMenuEnableActionImages -bool false
echo "[OK] Menu item icons hidden (Liquid Glass)"


# ── Reiniciar servicios ────────────────────────────────────────────
killall Dock 2>/dev/null  && echo "[OK] Dock restarted"
killall Finder 2>/dev/null && echo "[OK] Finder restarted"
killall SystemUIServer 2>/dev/null && echo "[OK] SystemUIServer restarted"
killall Clock 2>/dev/null || true
killall cfprefsd 2>/dev/null   && echo "[OK] cfprefsd restarted"
killall NotificationCenter 2>/dev/null && echo "[OK] NotificationCenter restarted"

echo "=== Done ==="
