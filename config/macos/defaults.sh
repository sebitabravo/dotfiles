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

# ── Trackpad ─────────────────────────────────────────────────────────
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 1.5
echo "[OK] Trackpad tracking speed"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
echo "[OK] Tap to click"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
echo "[OK] Two-finger right click"

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

defaults write com.apple.finder FK_StandardViewSettings -dict-add ListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
defaults write com.apple.finder FK_StandardViewSettings -dict-add ExtendedListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
echo "[OK] Finder list view columns: name, date, size"

defaults delete com.apple.finder FXInfoPanesExpanded 2>/dev/null || true
echo "[OK] Finder info panes reset"

defaults delete com.apple.finder FXDesktopVolumePositions 2>/dev/null || true
echo "[OK] Desktop icon positions reset"

# ── .DS_Store ──────────────────────────────────────────────────────
# Evita crear .DS_Store en volúmenes de red y USB (requiere logout)
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
echo "[OK] No .DS_Store on network volumes"

defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
echo "[OK] No .DS_Store on USB drives"

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

# ── Mail ───────────────────────────────────────────────────────────
defaults write com.apple.mail DisableReplyAnimations -bool true
echo "[OK] Mail reply animations off"

defaults write com.apple.mail DisableSendAnimations -bool true
echo "[OK] Mail send animations off"

defaults write com.apple.mail DisableInlineAttachmentViewing -bool true
echo "[OK] Mail inline attachments off"

# ── Disk Utility ───────────────────────────────────────────────────
defaults write com.apple.frameworks.diskimages skip-verify -bool true
defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true
echo "[OK] Skip DMG verification"

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

# ── Apple Intelligence ─────────────────────────────────────────────
# Sequoia 15.x: Feature ID 545129924
defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool false
echo "[OK] Apple Intelligence opt-out"

# ── TextEdit ────────────────────────────────────────────────────────
# Default to plain text mode (not rich text)
defaults write com.apple.TextEdit RichText -int 0
echo "[OK] TextEdit plain text default"

# ── Activity Monitor ──────────────────────────────────────────────
defaults write com.apple.ActivityMonitor ShowCategory -int 0
echo "[OK] Activity Monitor show all processes"

# ── Help Viewer ───────────────────────────────────────────────────
defaults write com.apple.helpviewer DevMode -bool true
echo "[OK] Help Viewer doesn't float on top"

# ── Software Update ───────────────────────────────────────────────
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false
echo "[OK] No automatic update downloads"

# ── Spotlight ─────────────────────────────────────────────────────
# Disable Spotlight Suggestions — prevents sending searches to Apple
defaults write com.apple.Spotlight SuggestionsEnabled -bool false
echo "[OK] Spotlight suggestions disabled"

# ── Reiniciar servicios ────────────────────────────────────────────
killall Dock 2>/dev/null  && echo "[OK] Dock restarted"
killall Finder 2>/dev/null && echo "[OK] Finder restarted"
killall SystemUIServer 2>/dev/null && echo "[OK] SystemUIServer restarted"
killall cfprefsd 2>/dev/null   && echo "[OK] cfprefsd restarted"

echo "=== Done ==="
