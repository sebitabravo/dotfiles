#!/bin/bash
# Stop hook — recuerda crear HANDOFF.md si no existe.
#
# Stop dispara UNA VEZ POR TURNO, no al cerrar la sesion. Sin marcador, este
# aviso salia en cada respuesta, y un recordatorio que aparece siempre se vuelve
# invisible (mismo motivo por el que qa-checklist.sh solo habla si encuentra
# algo). Ademas solo tiene sentido en sesiones ya largas, asi que se usa el
# tamano del transcript como proxy.
INPUT=$(cat 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null | tr -cd 'a-zA-Z0-9-')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")

[ -f "$PWD/HANDOFF.md" ] && exit 0

# Menos de ~200KB de transcript = sesion corta, no hay nada que traspasar.
MIN_TRANSCRIPT_BYTES=200000
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0
SIZE=$(wc -c <"$TRANSCRIPT" 2>/dev/null | tr -d ' ')
[ "${SIZE:-0}" -lt "$MIN_TRANSCRIPT_BYTES" ] && exit 0

MARKER="${TMPDIR:-/tmp}/claude-handoff-hint-${SESSION_ID:-nosession}"
[ -f "$MARKER" ] && exit 0
: >"$MARKER"

echo "[Hook] 💡 ¿Sesion larga o dando vueltas? Corre /handoff antes de cerrar para crear un traspaso limpio." >&2
exit 0
