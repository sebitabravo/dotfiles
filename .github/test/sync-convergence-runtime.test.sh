#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/config/claude/scripts/sync-convergence-runtime.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/sync-convergence-runtime-test.XXXXXX")
RUNTIME="$TMP/.claude"
PARITY="$ROOT/.github/test/check-runtime-parity.sh"
trap 'find "$TMP" -type f -delete; find "$TMP" -depth -type d -empty -delete 2>/dev/null || true' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

mkdir -p "$RUNTIME/hooks" "$RUNTIME/scripts"
cat >"$RUNTIME/settings.json" <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/secret-detect.sh"}]},
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/codegraph.sh"}]},
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/project-integrations-check.sh"}]},
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/herdr.sh"}]},
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/user-prompt-dispatcher.sh", "timeout": 10}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/automatic-workflow-stop.sh"}]},
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/convergence-stop.sh"}]}
    ],
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "runtime-only-hook"}]}
    ]
  },
  "runtimeOnly": true
}
EOF
echo '# runtime-only hook' >"$RUNTIME/hooks/runtime-only.sh"
echo '# old convergence hook' >"$RUNTIME/hooks/convergence-stop.sh"
before_settings=$(shasum -a 256 "$RUNTIME/settings.json" | awk '{print $1}')

CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --dry-run >/dev/null
[ ! -f "$RUNTIME/hooks/activate-convergence-on-apply.sh" ] || fail 'dry-run no debe copiar archivos'
[ "$before_settings" = "$(shasum -a 256 "$RUNTIME/settings.json" | awk '{print $1}')" ] || fail 'dry-run no debe modificar settings'

CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --apply >/dev/null
[ -f "$RUNTIME/hooks/runtime-only.sh" ] || fail 'debe preservar archivos runtime-only'
[ -f "$RUNTIME/hooks/user-prompt-dispatcher.sh" ] || fail 'debe copiar el dispatcher al runtime'
jq -e '.runtimeOnly == true' "$RUNTIME/settings.json" >/dev/null || fail 'debe preservar settings runtime-only'
jq -e '[.hooks.SessionStart[]?.hooks[]? | select(.command == "runtime-only-hook")] | length == 1' "$RUNTIME/settings.json" >/dev/null || fail 'debe preservar hooks runtime-only de otros eventos'
jq -e --slurpfile source "$ROOT/config/claude/settings.json" '(.hooks.UserPromptSubmit == $source[0].hooks.UserPromptSubmit) and (.hooks.Stop == $source[0].hooks.Stop)' "$RUNTIME/settings.json" >/dev/null || fail 'debe reconciliar los eventos gestionados con la fuente'
jq -e '[.hooks.UserPromptSubmit[]?.hooks[]? | select(.command == "~/.claude/hooks/user-prompt-dispatcher.sh" and .timeout == 60)] | length == 1' "$RUNTIME/settings.json" >/dev/null || fail 'debe consolidar UserPromptSubmit en un dispatcher portable con timeout 60'
jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?.command | select(. == "~/.claude/hooks/secret-detect.sh" or . == "~/.claude/hooks/codegraph.sh" or . == "~/.claude/hooks/project-integrations-check.sh" or . == "~/.claude/hooks/herdr.sh")] | length == 0' "$RUNTIME/settings.json" >/dev/null || fail 'no debe conservar siblings viejos del dispatcher'
jq -e '[.hooks.Stop[]?.hooks[]? | select(.command == "~/.claude/hooks/automatic-workflow-stop.sh")] | length == 1' "$RUNTIME/settings.json" >/dev/null || fail 'debe consolidar automatic-workflow-stop en un alias canónico'
jq -e '[.hooks.Stop[]?.hooks[]? | select(.command == "~/.claude/hooks/convergence-stop.sh")] | length == 1' "$RUNTIME/settings.json" >/dev/null || fail 'debe consolidar convergence-stop en un alias canónico'
jq --arg home "$HOME/.claude/hooks/" \
  '[.hooks.UserPromptSubmit[]?.hooks[]?.command, .hooks.Stop[]?.hooks[]?.command | select(startswith($home))] | length == 0' \
  "$RUNTIME/settings.json" >/dev/null || fail 'no debe conservar aliases absolutos equivalentes'
find "$RUNTIME" -name 'convergence-stop.sh.backup.*' -type f | grep -q . || fail 'debe crear backup del hook reemplazado'
find "$RUNTIME" -name 'settings.json.backup.*' -type f | grep -q . || fail 'debe crear backup de settings'

before_second=$(find "$RUNTIME" -name '*.backup.*' -type f | sort | shasum -a 256 | awk '{print $1}')
CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --apply >/dev/null
after_second=$(find "$RUNTIME" -name '*.backup.*' -type f | sort | shasum -a 256 | awk '{print $1}')
[ "$before_second" = "$after_second" ] || fail 'una segunda ejecución sin drift no debe crear backups nuevos'

EMPTY_RUNTIME="$TMP/empty/.claude"
CLAUDE_RUNTIME_DIR="$EMPTY_RUNTIME" CLAUDE_PARITY_SCRIPT="$PARITY" "$SCRIPT" --apply >/dev/null || fail 'debe poder crear un runtime sin settings previo'

MINIMAL_RUNTIME="$TMP/minimal/.claude"
CLAUDE_RUNTIME_DIR="$MINIMAL_RUNTIME" CLAUDE_PARITY_SCRIPT="$TMP/missing-parity.sh" "$SCRIPT" --apply >/dev/null ||
  fail 'la verificación mínima debe aceptar un runtime reconciliado sin suite de parity'
jq -e --slurpfile source "$ROOT/config/claude/settings.json" '(.hooks.UserPromptSubmit == $source[0].hooks.UserPromptSubmit) and (.hooks.Stop == $source[0].hooks.Stop)' "$MINIMAL_RUNTIME/settings.json" >/dev/null ||
  fail 'verify_runtime_minimal debe validar la proyección completa de eventos gestionados'

SYMLINK_RUNTIME="$TMP/symlink/.claude"
mkdir -p "$SYMLINK_RUNTIME/hooks"
echo '# linked target' >"$TMP/linked-target.sh"
ln -s "$TMP/linked-target.sh" "$SYMLINK_RUNTIME/hooks/convergence-stop.sh"
if CLAUDE_RUNTIME_DIR="$SYMLINK_RUNTIME" "$SCRIPT" --apply >/dev/null 2>&1; then
  fail 'debe rechazar un target symlink sin modificarlo'
fi
[ ! -e "$SYMLINK_RUNTIME/hooks/activate-convergence-on-apply.sh" ] || fail 'un symlink debe abortar antes de copiar parcialmente'

parity_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$PARITY" --json --strict)
printf '%s' "$parity_json" | jq -e '.parity == true and .failures == 0' >/dev/null || fail 'el apply aislado debe terminar con parity completa'

echo 'PASS: sync reconcilia eventos gestionados, preserva runtime-only y termina con parity completa'
