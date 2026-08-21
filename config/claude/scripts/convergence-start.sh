#!/usr/bin/env bash
# convergence-start.sh — activa el gate Stop para un change OpenSpec.
set -euo pipefail

usage() {
  printf 'Uso: %s <change-name>\n' "$(basename "$0")" >&2
  exit 64
}

[ "$#" -eq 1 ] || usage
CHANGE=$1
case "$CHANGE" in
  ''|*[!a-zA-Z0-9._-]*|.|..) usage ;;
esac

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo '[convergence-start] el directorio actual no es un repositorio Git.' >&2
  exit 1
}
cd "$ROOT"

command -v openspec >/dev/null 2>&1 || {
  echo '[convergence-start] OpenSpec CLI no está en PATH.' >&2
  exit 1
}

STATUS_JSON=$(openspec status --change "$CHANGE" --json 2>/dev/null) || {
  echo "[convergence-start] no se pudo leer el change '$CHANGE'." >&2
  exit 1
}
printf '%s' "$STATUS_JSON" | jq -e --arg change "$CHANGE" '.changeName == $change and .changeRoot and .artifacts' >/dev/null || {
  echo "[convergence-start] '$CHANGE' no es un change OpenSpec válido en este proyecto." >&2
  exit 1
}

mkdir -p "$ROOT/.claude/convergence"
printf '%s\n' "$CHANGE" >"$ROOT/.claude/convergence.active"

RECEIPT="$ROOT/.claude/convergence/$CHANGE.receipt"
if [ ! -e "$RECEIPT" ]; then
  cat >"$RECEIPT" <<EOF
CHANGE: $CHANGE
STATUS: PENDING
ACCEPTANCE: PENDING
VERIFY_EXIT: PENDING
EVIDENCE: pending — replace only after a fresh acceptance and verification run
EOF
fi

printf '[convergence-start] gate activo para %s\n' "$CHANGE"
printf '[convergence-start] completa el change, actualiza %s con PASS y deja que Stop revalide la suite.\n' "$RECEIPT"
