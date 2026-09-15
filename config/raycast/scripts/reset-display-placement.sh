#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Reset Display Placement
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🖥️

sleep 1 # Give displays time to settle after resolution change

# Monitor IDs (from `displayplacer list`)
MAIN="2E42F9AB-6187-497A-9D75-4646E97966C3" # 24" main display at origin (0,0)
MSI="A7D2E202-010B-4530-9455-F164350EDA38"  # 27" secondary, right of MAIN

# Expected dual layouts
EXPECTED_1440P_ORIGIN="(1920,-180)"
EXPECTED_1440P_HZ="72" # MSI hz in 1440p mode
EXPECTED_1080P_ORIGIN="(1920,0)"
EXPECTED_1080P_HZ="60"       # MSI hz in 1080p mode
EXPECTED_1440P_MAIN_HZ="120" # MAIN hz in 1440p mode
EXPECTED_1080P_MAIN_HZ="60"  # MAIN hz in 1080p mode

apply_dual_1440p() {
  /opt/homebrew/bin/displayplacer \
    "id:$MAIN res:1920x1080 hz:120 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0" \
    "id:$MSI res:2560x1440 hz:72 color_depth:8 enabled:true scaling:off origin:(1920,-180) degree:0"
}

apply_dual_1080p() {
  /opt/homebrew/bin/displayplacer \
    "id:$MAIN res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0" \
    "id:$MSI res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(1920,0) degree:0"
}

# Get currently connected displays
CONNECTED=$(/opt/homebrew/bin/displayplacer list 2>/dev/null)

# Bail out cleanly if either screen is missing (e.g. undocked): applying a
# partial layout would throw windows off-screen, so warn and exit 0.
if ! echo "$CONNECTED" | grep -q "Persistent screen id: $MAIN"; then
  echo "MAIN display not connected, leaving placement untouched"
  exit 0
fi
if ! echo "$CONNECTED" | grep -q "Persistent screen id: $MSI"; then
  echo "MSI display not connected, leaving placement untouched"
  exit 0
fi

# Current state per screen. Origin lines look like "Origin: (1920,-180)" or
# "Origin: (0,0) - main display", so extract just the parenthesised part.
MSI_BLOCK=$(echo "$CONNECTED" | grep -A9 "Persistent screen id: $MSI")
MAIN_BLOCK=$(echo "$CONNECTED" | grep -A9 "Persistent screen id: $MAIN")
MSI_RES=$(echo "$MSI_BLOCK" | grep "Resolution:" | awk '{print $2}')
MSI_HZ=$(echo "$MSI_BLOCK" | grep "Hertz:" | awk '{print $2}')
MSI_ORIGIN=$(echo "$MSI_BLOCK" | grep "Origin:" | grep -o '([^)]*)')
MAIN_1440_OK=$(echo "$MAIN_BLOCK" | grep -q "Resolution: 1920x1080" && echo "$MAIN_BLOCK" | grep -q "Hertz: $EXPECTED_1440P_MAIN_HZ" && echo "$MAIN_BLOCK" | grep -q "Origin: (0,0)" && echo yes || echo no)
MAIN_1080_OK=$(echo "$MAIN_BLOCK" | grep -q "Resolution: 1920x1080" && echo "$MAIN_BLOCK" | grep -q "Hertz: $EXPECTED_1080P_MAIN_HZ" && echo "$MAIN_BLOCK" | grep -q "Origin: (0,0)" && echo yes || echo no)

REPAIRED=0

if [ "$MSI_RES" = "2560x1440" ]; then
  if [ "$MSI_HZ" = "$EXPECTED_1440P_HZ" ] && [ "$MSI_ORIGIN" = "$EXPECTED_1440P_ORIGIN" ] && [ "$MAIN_1440_OK" = "yes" ]; then
    echo "1440p arrangement already correct"
  else
    apply_dual_1440p
    REPAIRED=1
    echo "1440p arrangement repaired (was MSI res=$MSI_RES hz=$MSI_HZ origin=$MSI_ORIGIN)"
  fi
elif [ "$MSI_RES" = "1920x1080" ]; then
  if [ "$MSI_HZ" = "$EXPECTED_1080P_HZ" ] && [ "$MSI_ORIGIN" = "$EXPECTED_1080P_ORIGIN" ] && [ "$MAIN_1080_OK" = "yes" ]; then
    echo "1080p arrangement already correct"
  else
    apply_dual_1080p
    REPAIRED=1
    echo "1080p arrangement repaired (was MSI res=$MSI_RES hz=$MSI_HZ origin=$MSI_ORIGIN)"
  fi
else
  apply_dual_1440p
  REPAIRED=1
  echo "Unknown MSI resolution ($MSI_RES), defaulted to dual 1440p@72"
fi

# A repaired layout changes resolution/geometry, which leaves WallpaperAgent
# painting a stale frame — respawn it only when we actually moved things.
# (`|| true` keeps the script green when the agent isn't running.)
if [ "$REPAIRED" = "1" ]; then
  killall WallpaperAgent || true
fi

# Reset Raycast window position (use -g to not focus Raycast)
sleep 2
open -g raycast://extensions/raycast/raycast/reset-raycast-window-position
