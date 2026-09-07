#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Restart Elgato
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🎙️
# @raycast.packageName System

# Apps to detect/relaunch
ELGATO_APPS=(
  "Elgato Stream Deck"
  "Elgato Wave Link"
)

# Detect running apps before killing
RUNNING_APPS=()
for app in "${ELGATO_APPS[@]}"; do
  pgrep -fi "$app" >/dev/null 2>&1 && RUNNING_APPS+=("$app")
done

# Kill logic lives in a temp helper so the privileged shell can exclude our
# own PID. Without this, `pkill -fi elgato` matches the script's path and
# SIGKILLs the script before it can relaunch anything.
SELF_PID=$$
KILL_SCRIPT=$(mktemp -t restart-elgato.XXXXXX)
trap 'rm -f "$KILL_SCRIPT"' EXIT

cat >"$KILL_SCRIPT" <<'KILLEOF'
#!/bin/bash
EXCLUDE_PID="$1"
for pattern in elgato "stream deck" streamdeck "wave link" wavelink; do
  pids=$(pgrep -fi "$pattern" 2>/dev/null | grep -v "^${EXCLUDE_PID}$")
  [ -n "$pids" ] && echo "$pids" | xargs kill -9 2>/dev/null
done
true
KILLEOF
chmod +x "$KILL_SCRIPT"

# osascript opens the native admin prompt (caches password ~5min)
osascript -e "do shell script \"'$KILL_SCRIPT' $SELF_PID\" with administrator privileges" >/dev/null 2>&1

sleep 2

# Relaunch apps that were running
for app in "${RUNNING_APPS[@]}"; do
  open -a "$app" 2>/dev/null
done

echo "Elgato stack restarted (${#RUNNING_APPS[@]} apps relaunched)"
