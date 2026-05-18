#!/usr/bin/env bash
# macOS Sequoia 15.x — defaults write optimizations
# Source: ChrisTitusTech/macutil (curated for developers)
# Apply: chmod +x defaults.sh && ./defaults.sh
set -euo pipefail

echo "=== Aplicando defaults de macOS ==="

# ═══════════════════════════════════════════════════════════════════
# NOTA PARA DESARROLLADORES
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

# ── Finder ─────────────────────────────────────────────────────────
defaults write com.apple.finder DisableAllAnimations -bool true
echo "[OK] Finder animations disabled"

defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
echo "[OK] Finder default list view"

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

# ── Screenshots ────────────────────────────────────────────────────
defaults write com.apple.screencapture disable-shadow -bool true
echo "[OK] Screenshot shadows off"

defaults write com.apple.screencapture type -string "png"
echo "[OK] Screenshot format = PNG"

defaults write com.apple.screencapture location -string "${HOME}/Desktop"
echo "[OK] Screenshots to Desktop"

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

# ── Apple Intelligence ─────────────────────────────────────────────
# Feature ID 545129924 = Apple Intelligence (Sequoia 15.x).
# Puede cambiar en Tahoe 16.x — si falla, buscar ID actual con:
#   defaults read com.apple.CloudSubscriptionFeatures
os_version=$(sw_vers -productVersion 2>/dev/null || echo "0")
if [[ "$os_version" == 15.* ]]; then
  defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool false
  echo "[OK] Apple Intelligence opt-out"
else
  echo "[SKIP] Apple Intelligence — macOS $os_version (ID puede haber cambiado)"
fi

# ── Reiniciar servicios ────────────────────────────────────────────
killall Dock 2>/dev/null  && echo "[OK] Dock restarted"
killall Finder 2>/dev/null && echo "[OK] Finder restarted"
killall SystemUIServer 2>/dev/null && echo "[OK] SystemUIServer restarted"
killall cfprefsd 2>/dev/null   && echo "[OK] cfprefsd restarted"

echo "=== Done ==="
