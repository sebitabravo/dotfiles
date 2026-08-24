#!/usr/bin/env bash
# smoke-claude-hook-engine.sh — prueba el motor real de hooks sin inferencia.
#
# Usa un HOME temporal y un runtime aislado. No toca ~/.claude, no lee ni
# modifica credenciales y --init-only no inicia una conversación. El probe
# registra el payload de SessionStart y ejecuta el compact-resume real copiado
# por el sincronizador.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
SYNC="$REPO_ROOT/config/claude/scripts/sync-convergence-runtime.sh"
PARITY="$SCRIPT_DIR/check-runtime-parity.sh"

command -v claude >/dev/null 2>&1 || {
  printf '[claude-smoke] claude no está en PATH.\n' >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || {
  printf '[claude-smoke] jq es requerido.\n' >&2
  exit 2
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/claude-hook-engine.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

HOME_DIR="$TMP/home"
RUNTIME="$HOME_DIR/.claude"
PROJECT="$TMP/project"
PROBE_LOG="$TMP/session-start.json"
mkdir -p "$HOME_DIR" "$PROJECT"
git -C "$PROJECT" init -q
PROJECT_REAL=$(cd -- "$PROJECT" && pwd -P)

HOME="$HOME_DIR" CLAUDE_RUNTIME_DIR="$RUNTIME" bash "$SYNC" --apply >"$TMP/sync.log"
HOME="$HOME_DIR" CLAUDE_RUNTIME_DIR="$RUNTIME" bash "$PARITY" --strict >"$TMP/parity.log"

cat >"$RUNTIME/hooks/session-start-probe.sh" <<'EOF'
#!/bin/sh
set -eu

INPUT=$(cat)
printf '%s\n' "$INPUT" >"$PROBE_LOG"
printf '%s' "$INPUT" | python3 "$RUNTIME/hooks/compact-resume.py" >/dev/null
EOF
chmod +x "$RUNTIME/hooks/session-start-probe.sh"

TMP_SETTINGS="$TMP/settings.json"
jq --arg command "$RUNTIME/hooks/session-start-probe.sh" \
  '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{matcher:"startup",hooks:[{type:"command",command:$command}]}])' \
  "$RUNTIME/settings.json" >"$TMP_SETTINGS"
cp -p -- "$TMP_SETTINGS" "$RUNTIME/settings.json"

set +e
(
  cd "$PROJECT"
  export HOME="$HOME_DIR" PROBE_LOG="$PROBE_LOG" RUNTIME
  claude --init-only --settings "$RUNTIME/settings.json" \
    --setting-sources user --debug hooks
) >"$TMP/claude.stdout" 2>"$TMP/claude.stderr"
CLAUDE_RC=$?
set -e

if [ "$CLAUDE_RC" -ne 0 ]; then
  printf '[claude-smoke] claude --init-only falló (rc=%s).\n' "$CLAUDE_RC" >&2
  sed -n '1,120p' "$TMP/claude.stderr" >&2 || true
  exit 1
fi

[ -s "$PROBE_LOG" ] || {
  printf '[claude-smoke] SessionStart no ejecutó el probe.\n' >&2
  sed -n '1,120p' "$TMP/claude.stderr" >&2 || true
  exit 1
}

jq -e --arg cwd "$PROJECT_REAL" \
  '.hook_event_name == "SessionStart" and .source == "startup" and .cwd == $cwd' \
  "$PROBE_LOG" >/dev/null || {
  printf '[claude-smoke] payload SessionStart inesperado:\n' >&2
  jq . "$PROBE_LOG" >&2
  exit 1
}

printf '[claude-smoke] PASS: Claude Code cargó el runtime aislado y ejecutó SessionStart/compact-resume.\n'
