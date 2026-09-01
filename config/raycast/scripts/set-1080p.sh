#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Set 1080p
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName System

# Monitor IDs
MSI="A7D2E202-010B-4530-9455-F164350EDA38"

# Set 1080p with correct arrangement
/opt/homebrew/bin/displayplacer \
  "id:$MSI res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(1710,0) degree:0"

killall WallpaperAgent

# Reset Raycast window position (use -g to not focus Raycast)
sleep 2
open -g raycast://extensions/raycast/raycast/reset-raycast-window-position

echo "1080p applied"
