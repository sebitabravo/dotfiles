#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Set 1440p
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName System

# Monitor IDs (from `displayplacer list`)
MAIN="2E42F9AB-6187-497A-9D75-4646E97966C3" # 24" 1920x1080@120, main display at origin (0,0)
MSI="A7D2E202-010B-4530-9455-F164350EDA38"  # 27" right of MAIN, top-aligned via origin (1920,-180)

# Dual layout: MAIN 1920x1080@120 at (0,0) + MSI 2560x1440@72 at (1920,-180).
# Both screens go in one atomic displayplacer call so the untouched display
# never keeps a stale origin/hz.
/opt/homebrew/bin/displayplacer \
  "id:$MAIN res:1920x1080 hz:120 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0" \
  "id:$MSI res:2560x1440 hz:72 color_depth:8 enabled:true scaling:off origin:(1920,-180) degree:0"

# Reset Raycast window position (use -g to not focus Raycast)
sleep 2
open -g raycast://extensions/raycast/raycast/reset-raycast-window-position

echo "1440p applied"
