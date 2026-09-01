#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Reset Display Placement
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🖥️

sleep 1 # Give displays time to settle after resolution change

# Monitor IDs
MSI="A7D2E202-010B-4530-9455-F164350EDA38"

# Get currently connected displays
CONNECTED=$(/opt/homebrew/bin/displayplacer list 2>/dev/null)

# Get current resolution of MSI monitor
CURRENT_RES=$(echo "$CONNECTED" | grep -A5 "Persistent screen id: $MSI" | grep "Resolution:" | awk '{print $2}')

# Determine which config to use based on MSI resolution
if [ -z "$CURRENT_RES" ]; then
    echo "1440p monitor not connected"
elif [ "$CURRENT_RES" = "2560x1440" ]; then
    echo "1440p arrangement already correct"
elif [ "$CURRENT_RES" = "1920x1080" ]; then
    echo "1080p arrangement already correct"
else
    /opt/homebrew/bin/displayplacer \
        "id:$MSI res:2560x1440 hz:72 color_depth:8 enabled:true scaling:off origin:(1710,0) degree:0"
    echo "1440p arrangement reset (was $CURRENT_RES)"
fi

# Reset Raycast window position
sleep 2
open raycast://extensions/raycast/raycast/reset-window-position
