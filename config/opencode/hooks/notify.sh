#!/usr/bin/env bash

set -euo pipefail

# --- DETECCIÓN DE FOCO (Evita notificaciones invasivas) ---
# Si estás en macOS, verificamos qué aplicación está en primer plano.
if [[ "$(uname -s)" == "Darwin" ]]; then
  FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || echo "")
  
  # Si la app activa es una terminal, cortamos la ejecución acá (modo silencioso)
  if [[ "$FRONT_APP" == "Warp" || "$FRONT_APP" == "iTerm2" || "$FRONT_APP" == "Terminal" || "$FRONT_APP" == "Ghostty" || "$FRONT_APP" == "WezTerm" || "$FRONT_APP" == "Alacritty" ]]; then
    exit 0
  fi
fi
# ----------------------------------------------------------

EVENT="${OPENCODE_NOTIFY_EVENT:-opencode}"
TITLE="${OPENCODE_NOTIFY_TITLE:-OpenCode}"
BODY="${OPENCODE_NOTIFY_BODY:-Actividad en OpenCode}"
PROJECT="${OPENCODE_NOTIFY_PROJECT:-}"

BODY="$(printf '%s' "$BODY" | tr '\n' ' ' | tr -s ' ')"
BODY="${BODY:0:180}"
TITLE="${TITLE:0:80}"

if [[ -n "$PROJECT" ]]; then
  SUBTITLE="${PROJECT} · ${EVENT}"
else
  SUBTITLE="$EVENT"
fi

SUBTITLE="${SUBTITLE:0:80}"

SOUND_NAME="Glass"
if [[ "$EVENT" == "session-error" ]]; then
  SOUND_NAME="Basso"
elif [[ "$EVENT" == "permission-request" ]]; then
  SOUND_NAME="Pop"
fi

case "$(uname -s)" in
  Darwin)
    /usr/bin/osascript - "$TITLE" "$BODY" "$SUBTITLE" "$SOUND_NAME" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set theTitle to item 1 of argv
  set theBody to item 2 of argv
  set theSubtitle to item 3 of argv
  set theSound to item 4 of argv
  display notification theBody with title theTitle subtitle theSubtitle sound name theSound
end run
APPLESCRIPT
    ;;
  *)
    exit 0
    ;;
esac
