#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Set 1080p
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName System

# Monitor IDs (from `displayplacer list`)
MAIN="2E42F9AB-6187-497A-9D75-4646E97966C3" # 24" 1920x1080@60, main display at origin (0,0)
MSI="A7D2E202-010B-4530-9455-F164350EDA38"  # 27" right of MAIN, same height so top-aligned at (1920,0)

# Dual layout: MAIN 1920x1080@60 at (0,0) + MSI 1920x1080@60 at (1920,0).
# Both screens go in one atomic displayplacer call so the untouched display
# never keeps a stale origin/hz. No negative y-offset needed: both panels are
# 1080 tall, so y=0 already aligns tops.
/opt/homebrew/bin/displayplacer \
  "id:$MAIN res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0" \
  "id:$MSI res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(1920,0) degree:0"

# WallpaperAgent caches per-resolution wallpaper geometry, so shrinking the MSI
# to 1080p leaves a stretched/stale frame until it respawns. `|| true` keeps
# the script green when the agent isn't running (already dead, headless).
killall WallpaperAgent || true

# Reset Raycast window position (use -g to not focus Raycast)
sleep 2
open -g raycast://extensions/raycast/raycast/reset-raycast-window-position

echo "1080p applied"
