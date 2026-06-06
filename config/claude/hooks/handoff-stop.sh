#!/bin/bash
# Stop hook — recuerda crear HANDOFF.md si no existe
HANDOFF="$PWD/HANDOFF.md"
if [ ! -f "$HANDOFF" ]; then
  echo "[Hook] 💡 ¿Sesion larga o dando vueltas? Corre /handoff antes de cerrar para crear un traspaso limpio." >&2
fi
