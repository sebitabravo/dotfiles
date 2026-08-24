#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/config/claude/scripts/sync-convergence-runtime.sh"
PARITY="$ROOT/.github/test/check-runtime-parity.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/sync-convergence-runtime-test.XXXXXX")
RUNTIME="$TMP/.claude"
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
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/automatic-workflow.sh"}]},
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/activate-convergence-on-apply.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "runtime-only-hook"}]},
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/automatic-workflow-stop.sh"}]},
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/convergence-stop.sh"}]}
    ]
  },
  "runtimeOnly": true
}
EOF
jq --arg automatic "$HOME/.claude/hooks/automatic-workflow.sh" \
  --arg activation "$HOME/.claude/hooks/activate-convergence-on-apply.sh" \
  --arg automatic_stop "$HOME/.claude/hooks/automatic-workflow-stop.sh" \
  --arg stop "$HOME/.claude/hooks/convergence-stop.sh" \
  '.hooks.UserPromptSubmit += [
      {hooks: [{type: "command", command: $automatic}]},
      {hooks: [{type: "command", command: $activation}]}
    ]
   | .hooks.Stop += [
      {hooks: [{type: "command", command: $automatic_stop}]},
      {hooks: [{type: "command", command: $stop}]}
    ]' \
  "$RUNTIME/settings.json" >"$RUNTIME/settings.json.tmp"
mv -- "$RUNTIME/settings.json.tmp" "$RUNTIME/settings.json"
echo '# runtime-only hook' >"$RUNTIME/hooks/runtime-only.sh"
echo '# old convergence hook' >"$RUNTIME/hooks/convergence-stop.sh"
before_settings=$(shasum -a 256 "$RUNTIME/settings.json" | awk '{print $1}')

CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --dry-run >/dev/null
[ ! -f "$RUNTIME/hooks/activate-convergence-on-apply.sh" ] || fail 'dry-run no debe copiar archivos'
[ "$before_settings" = "$(shasum -a 256 "$RUNTIME/settings.json" | awk '{print $1}')" ] || fail 'dry-run no debe modificar settings'

CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --apply >/dev/null
CLAUDE_RUNTIME_DIR="$RUNTIME" "$PARITY" --strict >/dev/null
[ -f "$RUNTIME/hooks/runtime-only.sh" ] || fail 'debe preservar archivos runtime-only'
jq -e '.runtimeOnly == true' "$RUNTIME/settings.json" >/dev/null || fail 'debe preservar settings runtime-only'
jq -e '[.hooks.Stop[]?.hooks[]? | select(.command == "runtime-only-hook")] | length == 1' "$RUNTIME/settings.json" >/dev/null || fail 'debe preservar hooks runtime-only'
jq -e '[.hooks.UserPromptSubmit[]?.hooks[]? | select(.command == "~/.claude/hooks/automatic-workflow.sh")] | length == 1' "$RUNTIME/settings.json" >/dev/null || fail 'debe consolidar automatic-workflow en un alias canónico'
jq -e '[.hooks.UserPromptSubmit[]?.hooks[]? | select(.command == "~/.claude/hooks/activate-convergence-on-apply.sh")] | length == 1' "$RUNTIME/settings.json" >/dev/null || fail 'debe consolidar activate-convergence en un alias canónico'
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
CLAUDE_RUNTIME_DIR="$EMPTY_RUNTIME" "$SCRIPT" --apply >/dev/null
CLAUDE_RUNTIME_DIR="$EMPTY_RUNTIME" "$PARITY" --strict >/dev/null || fail 'debe poder crear un runtime sin settings previo'

SYMLINK_RUNTIME="$TMP/symlink/.claude"
mkdir -p "$SYMLINK_RUNTIME/hooks"
echo '# linked target' >"$TMP/linked-target.sh"
ln -s "$TMP/linked-target.sh" "$SYMLINK_RUNTIME/hooks/convergence-stop.sh"
if CLAUDE_RUNTIME_DIR="$SYMLINK_RUNTIME" "$SCRIPT" --apply >/dev/null 2>&1; then
  fail 'debe rechazar un target symlink sin modificarlo'
fi
[ ! -e "$SYMLINK_RUNTIME/hooks/activate-convergence-on-apply.sh" ] || fail 'un symlink debe abortar antes de copiar parcialmente'

echo 'PASS: sync de convergencia requiere --apply, respeta runtime-only y deja parity estricta'
